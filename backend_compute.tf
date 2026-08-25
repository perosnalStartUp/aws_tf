# =============================================================================
# Backend compute inputs
# =============================================================================
variable "backend_instance_type" {
  type        = string
  description = "Approved Backend EC2 instance type."
  nullable    = false
}

variable "backend_systemd_service_name" {
  type        = string
  description = "Systemd unit installed by the approved Backend AMI."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.@-]+\\.service$", var.backend_systemd_service_name))
    error_message = "backend_systemd_service_name must be a systemd .service unit name."
  }
}

variable "backend_compute_settings" {
  type = object({
    root_device_name            = string
    root_volume_size_gib        = number
    root_volume_type            = string
    detailed_monitoring_enabled = bool
    health_check_grace_seconds  = number
    default_instance_warmup     = number
  })
  description = "Reviewed Backend Launch Template and ASG structural settings."
  nullable    = false

  validation {
    condition = (
      startswith(var.backend_compute_settings.root_device_name, "/dev/") &&
      var.backend_compute_settings.root_volume_size_gib >= 8 &&
      contains(["gp2", "gp3", "io1", "io2"], var.backend_compute_settings.root_volume_type) &&
      var.backend_compute_settings.health_check_grace_seconds >= 0 &&
      var.backend_compute_settings.default_instance_warmup >= 0
    )
    error_message = "Backend compute settings must use a /dev device, an encrypted volume of at least 8 GiB, and non-negative health/warmup values."
  }
}

variable "backend_target_health" {
  type = object({
    path                         = string
    matcher                      = string
    interval_seconds             = number
    timeout_seconds              = number
    healthy_threshold            = number
    unhealthy_threshold          = number
    deregistration_delay_seconds = number
  })
  description = "Backend target-group health and draining settings."
  nullable    = false

  validation {
    condition = (
      startswith(var.backend_target_health.path, "/") &&
      can(regex("^[0-9]{3}(-[0-9]{3})?(,[0-9]{3}(-[0-9]{3})?)*$", var.backend_target_health.matcher)) &&
      var.backend_target_health.interval_seconds >= 5 &&
      var.backend_target_health.timeout_seconds >= 2 &&
      var.backend_target_health.timeout_seconds < var.backend_target_health.interval_seconds &&
      var.backend_target_health.healthy_threshold >= 2 &&
      var.backend_target_health.unhealthy_threshold >= 2 &&
      var.backend_target_health.deregistration_delay_seconds >= 0
    )
    error_message = "Backend health settings require an absolute path, valid HTTP matcher, timeout below interval, thresholds of at least two, and non-negative draining."
  }
}

variable "backend_edge" {
  type = object({
    public_domain_name    = string
    public_hosted_zone_id = string
    certificate_arn       = string
    ssl_policy            = string
    deletion_protection   = bool
    idle_timeout_seconds  = number
  })
  description = "Approved public Backend DNS, certificate, TLS, and ALB safety settings."
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$", var.backend_edge.public_domain_name)) &&
      can(regex("^Z[A-Z0-9]+$", var.backend_edge.public_hosted_zone_id)) &&
      startswith(var.backend_edge.certificate_arn, "arn:aws:acm:${var.aws_region}:${var.aws_account_id}:certificate/") &&
      startswith(var.backend_edge.ssl_policy, "ELBSecurityPolicy-") &&
      var.backend_edge.idle_timeout_seconds >= 1 &&
      var.backend_edge.idle_timeout_seconds <= 4000
    )
    error_message = "backend_edge must provide a valid domain, Route53 zone ID, ACM certificate ARN, ELB TLS policy, and 1-4000 second idle timeout."
  }
}

check "backend_resource_name_limits" {
  assert {
    condition     = length("${local.name_prefix}-backend") <= 32
    error_message = "project_name and environment must produce a Backend ALB/target-group name no longer than 32 characters."
  }
}

variable "backend_release_preferences" {
  type = object({
    min_healthy_percentage = number
    max_healthy_percentage = number
    instance_warmup        = number
    auto_rollback          = bool
    skip_matching          = bool
  })
  description = "Reviewed preferences consumed by the future Backend release workflow; Terraform does not start a refresh."
  nullable    = false

  validation {
    condition = (
      var.backend_release_preferences.min_healthy_percentage >= 0 &&
      var.backend_release_preferences.min_healthy_percentage <= 100 &&
      var.backend_release_preferences.max_healthy_percentage >= 100 &&
      var.backend_release_preferences.max_healthy_percentage <= 200 &&
      var.backend_release_preferences.max_healthy_percentage > var.backend_release_preferences.min_healthy_percentage &&
      var.backend_release_preferences.instance_warmup >= 0
    )
    error_message = "Backend release percentages must preserve surge room and instance_warmup must be non-negative."
  }
}

# =============================================================================
# Backend Launch Template
# =============================================================================
locals {
  backend_runtime_environment = {
    APP_ENVIRONMENT     = var.environment
    AWS_REGION          = var.aws_region
    DATABASE_HOST       = aws_db_instance.postgres.address
    DATABASE_NAME       = aws_db_instance.postgres.db_name
    DATABASE_PORT       = tostring(aws_db_instance.postgres.port)
    DATABASE_SECRET_ARN = one(aws_db_instance.postgres.master_user_secret).secret_arn
    PRODUCT_KMS_KEY_ARN = aws_kms_key.product.arn
    PRODUCT_S3_BUCKET   = aws_s3_bucket.product.bucket
    TRAINING_DLQ_URL    = aws_sqs_queue.training_dlq.url
    TRAINING_QUEUE_URL  = aws_sqs_queue.training.url
    WORKING_BASE_URL    = "${var.working_service_scheme}://${aws_route53_record.working_private.fqdn}:${var.working_service_port}"
    WORKING_SECRET_ARN  = var.working_auth_secret_arn
  }

  backend_runtime_environment_file = join("\n", [
    for key in sort(keys(local.backend_runtime_environment)) :
    "${key}=${jsonencode(local.backend_runtime_environment[key])}"
  ])
}

resource "aws_launch_template" "backend" {
  name_prefix            = "${local.name_prefix}-backend-"
  description            = "Terraform-owned Backend structure; release workflow owns AMI-only versions"
  image_id               = var.backend_ami_id
  instance_type          = var.backend_instance_type
  update_default_version = false

  iam_instance_profile {
    name = aws_iam_instance_profile.runtime["backend"].name
  }

  vpc_security_group_ids = [aws_security_group.backend.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.backend_compute_settings.detailed_monitoring_enabled
  }

  block_device_mappings {
    device_name = var.backend_compute_settings.root_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.backend_compute_settings.root_volume_size_gib
      volume_type           = var.backend_compute_settings.root_volume_type
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/backend_runtime_environment.sh.tftpl", {
    runtime_environment  = local.backend_runtime_environment_file
    systemd_service_name = var.backend_systemd_service_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = local.component_names.backend
      Component = "backend"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = "${local.component_names.backend}-root"
      Component = "backend"
    }
  }

  tags = {
    Name      = "${local.name_prefix}-backend-launch-template"
    Component = "backend"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [image_id]
  }
}

# =============================================================================
# Backend target group and ALB
# =============================================================================
resource "aws_lb_target_group" "backend" {
  name                 = "${local.name_prefix}-backend"
  port                 = var.backend_application_port
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = var.backend_target_health.deregistration_delay_seconds

  health_check {
    enabled             = true
    path                = var.backend_target_health.path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = var.backend_target_health.matcher
    interval            = var.backend_target_health.interval_seconds
    timeout             = var.backend_target_health.timeout_seconds
    healthy_threshold   = var.backend_target_health.healthy_threshold
    unhealthy_threshold = var.backend_target_health.unhealthy_threshold
  }

}

# Confirmed product boundary: this is the sole public application entry and forwards only to the
# private Backend target group; Working, Training, RDS, and application EC2 remain private.
#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "backend" {
  name                       = "${local.name_prefix}-backend"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.backend_edge.deletion_protection
  idle_timeout               = var.backend_edge.idle_timeout_seconds

  tags = {
    Name      = "${local.name_prefix}-backend"
    Component = "backend"
  }
}

# =============================================================================
# Backend Auto Scaling Group
# =============================================================================
resource "aws_autoscaling_group" "backend" {
  name                      = "${local.name_prefix}-backend"
  min_size                  = var.backend_capacity.min
  desired_capacity          = var.backend_capacity.desired
  max_size                  = var.backend_capacity.max
  vpc_zone_identifier       = [for subnet in aws_subnet.private_application : subnet.id]
  target_group_arns         = [aws_lb_target_group.backend.arn]
  health_check_type         = "ELB"
  health_check_grace_period = var.backend_compute_settings.health_check_grace_seconds
  default_instance_warmup   = var.backend_compute_settings.default_instance_warmup
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
  ]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Default"
  }

  instance_maintenance_policy {
    min_healthy_percentage = var.backend_release_preferences.min_healthy_percentage
    max_healthy_percentage = var.backend_release_preferences.max_healthy_percentage
  }

  tag {
    key                 = "Name"
    value               = local.component_names.backend
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = "backend"
    propagate_at_launch = true
  }
}

# =============================================================================
# Backend HTTPS listeners and public DNS
# =============================================================================
resource "aws_lb_listener" "backend_http_redirect" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "backend_https" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.backend_edge.certificate_arn
  ssl_policy        = var.backend_edge.ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_route53_record" "backend_public" {
  zone_id = var.backend_edge.public_hosted_zone_id
  name    = var.backend_edge.public_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.backend.dns_name
    zone_id                = aws_lb.backend.zone_id
    evaluate_target_health = true
  }
}

# =============================================================================
# Backend outputs
# =============================================================================
output "backend_launch_template_id" {
  description = "Terraform-owned Backend Launch Template ID."
  value       = aws_launch_template.backend.id
}

output "backend_asg_name" {
  description = "Backend Auto Scaling Group name."
  value       = aws_autoscaling_group.backend.name
}

output "backend_public_url" {
  description = "Public HTTPS base URL used by Frontend and Training callbacks."
  value       = "https://${aws_route53_record.backend_public.fqdn}"
}

output "backend_alb_arn" {
  description = "Backend internet-facing ALB ARN."
  value       = aws_lb.backend.arn
}

output "backend_release_preferences" {
  description = "Reviewed preferences for the future Backend release workflow; no refresh is started by Terraform."
  value       = var.backend_release_preferences
}
