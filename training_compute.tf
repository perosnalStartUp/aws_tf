# =============================================================================
# Training compute and scaling inputs
# =============================================================================
variable "training_instance_type" {
  type        = string
  description = "Approved On-Demand Training GPU instance type."
  nullable    = false
}

variable "training_systemd_service_name" {
  type        = string
  description = "Systemd unit installed by the approved Training AMI."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.@-]+\\.service$", var.training_systemd_service_name))
    error_message = "training_systemd_service_name must be a systemd .service unit name."
  }
}

variable "training_compute_settings" {
  type = object({
    root_device_name            = string
    root_volume_size_gib        = number
    root_volume_type            = string
    workspace_device_name       = string
    workspace_volume_size_gib   = number
    workspace_volume_type       = string
    detailed_monitoring_enabled = bool
    default_instance_warmup     = number
  })
  description = "Reviewed Training Launch Template and ASG structural settings."
  nullable    = false

  validation {
    condition = (
      startswith(var.training_compute_settings.root_device_name, "/dev/") &&
      startswith(var.training_compute_settings.workspace_device_name, "/dev/") &&
      var.training_compute_settings.root_device_name != var.training_compute_settings.workspace_device_name &&
      var.training_compute_settings.root_volume_size_gib >= 8 &&
      var.training_compute_settings.workspace_volume_size_gib >= 1 &&
      contains(["gp2", "gp3", "io1", "io2"], var.training_compute_settings.root_volume_type) &&
      contains(["gp2", "gp3", "io1", "io2"], var.training_compute_settings.workspace_volume_type) &&
      var.training_compute_settings.default_instance_warmup >= 0
    )
    error_message = "Training compute settings require distinct /dev devices, encrypted supported EBS types, root >= 8 GiB, workspace >= 1 GiB, and non-negative warmup."
  }
}

variable "training_lifecycle_settings" {
  type = object({
    hook_name                 = string
    heartbeat_timeout_seconds = number
    default_result            = string
  })
  description = "Termination lifecycle-hook contract shared with the Training worker."
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z0-9_-]{1,255}$", var.training_lifecycle_settings.hook_name)) &&
      var.training_lifecycle_settings.heartbeat_timeout_seconds >= 30 &&
      var.training_lifecycle_settings.heartbeat_timeout_seconds <= 7200 &&
      contains(["ABANDON", "CONTINUE"], var.training_lifecycle_settings.default_result)
    )
    error_message = "Training lifecycle settings require a valid hook name, heartbeat timeout of 30-7200 seconds, and ABANDON or CONTINUE."
  }
}

variable "training_runtime_settings" {
  type = object({
    callback_secret_json_field        = string
    working_max_lora_rank             = number
    evaluation_max_loss               = number
    artifact_version                  = string
    code_commit                       = string
    image_training_code_commit        = string
    container_image_digest            = string
    workspace_root                    = string
    model_cache_root                  = string
    visibility_retry_interval_seconds = number
    visibility_max_failures           = number
    max_raw_dataset_bytes             = number
    max_processed_dataset_bytes       = number
    max_checkpoint_bytes              = number
    callback_max_attempts             = number
  })
  description = "Required non-secret Training worker settings from the frozen GPU contract."
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.training_runtime_settings.callback_secret_json_field)) &&
      var.training_runtime_settings.working_max_lora_rank > 0 &&
      var.training_runtime_settings.evaluation_max_loss >= 0 &&
      can(regex("^[A-Za-z0-9._-]{1,128}$", var.training_runtime_settings.artifact_version)) &&
      can(regex("^[0-9a-f]{40}$", var.training_runtime_settings.code_commit)) &&
      can(regex("^[0-9a-f]{40}$", var.training_runtime_settings.image_training_code_commit)) &&
      can(regex("^sha256:[0-9a-f]{64}$", var.training_runtime_settings.container_image_digest)) &&
      startswith(var.training_runtime_settings.workspace_root, "/") &&
      startswith(var.training_runtime_settings.model_cache_root, "/") &&
      var.training_runtime_settings.visibility_retry_interval_seconds > 0 &&
      var.training_runtime_settings.visibility_max_failures > 0 &&
      var.training_runtime_settings.max_raw_dataset_bytes > 0 &&
      var.training_runtime_settings.max_processed_dataset_bytes > 0 &&
      var.training_runtime_settings.max_checkpoint_bytes > 0 &&
      var.training_runtime_settings.callback_max_attempts > 0
    )
    error_message = "Training runtime settings require immutable commit/digest identities, absolute roots, and positive reviewed limits/retry values."
  }
}

variable "training_scaling_settings" {
  type = object({
    metric_period_seconds          = number
    evaluation_periods             = number
    datapoints_to_alarm            = number
    scale_out_backlog_per_instance = number
    scale_in_backlog_per_instance  = number
    scale_out_adjustment           = number
    scale_in_adjustment            = number
    scale_out_cooldown_seconds     = number
    scale_in_cooldown_seconds      = number
  })
  description = "Evidence-derived SQS backlog-per-InService-instance scaling settings."
  nullable    = false

  validation {
    condition = (
      contains([10, 20, 30, 60, 120, 300], var.training_scaling_settings.metric_period_seconds) &&
      var.training_scaling_settings.evaluation_periods >= 1 &&
      var.training_scaling_settings.datapoints_to_alarm >= 1 &&
      var.training_scaling_settings.datapoints_to_alarm <= var.training_scaling_settings.evaluation_periods &&
      var.training_scaling_settings.scale_out_backlog_per_instance > var.training_scaling_settings.scale_in_backlog_per_instance &&
      var.training_scaling_settings.scale_in_backlog_per_instance >= 0 &&
      var.training_scaling_settings.scale_out_adjustment >= 1 &&
      var.training_scaling_settings.scale_in_adjustment <= -1 &&
      var.training_scaling_settings.scale_out_cooldown_seconds >= 0 &&
      var.training_scaling_settings.scale_in_cooldown_seconds >= 0
    )
    error_message = "Training scaling settings require valid periods, alarm counts, separated backlog thresholds, positive scale-out, negative scale-in, and non-negative cooldowns."
  }
}

check "training_compute_contract" {
  assert {
    condition = (
      var.training_capacity.max >= 1 &&
      var.training_runtime_settings.visibility_retry_interval_seconds < var.training_visibility_renew_interval_seconds
    )
    error_message = "Training requires scale-out capacity and must retry visibility before the normal renewal interval."
  }
}

# =============================================================================
# Training Launch Template
# =============================================================================
locals {
  training_asg_name = "${local.name_prefix}-training"

  training_runtime_environment = {
    IMAGE_TRAINING_CODE_COMMIT                 = var.training_runtime_settings.image_training_code_commit
    TRAINING_AMI_ID                            = var.training_ami_id
    TRAINING_ARTIFACT_VERSION                  = var.training_runtime_settings.artifact_version
    TRAINING_ASG_NAME                          = local.training_asg_name
    TRAINING_AWS_REGION                        = var.aws_region
    TRAINING_BACKEND_BASE_URL                  = "https://${aws_route53_record.backend_public.fqdn}"
    TRAINING_BUCKET                            = aws_s3_bucket.product.bucket
    TRAINING_CALLBACK_MAX_ATTEMPTS             = tostring(var.training_runtime_settings.callback_max_attempts)
    TRAINING_CALLBACK_SECRET_ARN               = var.training_callback_secret_arn
    TRAINING_CALLBACK_SECRET_JSON_FIELD        = var.training_runtime_settings.callback_secret_json_field
    TRAINING_CODE_COMMIT                       = var.training_runtime_settings.code_commit
    TRAINING_CONTAINER_IMAGE_DIGEST            = var.training_runtime_settings.container_image_digest
    TRAINING_EVALUATION_MAX_LOSS               = tostring(var.training_runtime_settings.evaluation_max_loss)
    TRAINING_KMS_KEY_ARN                       = aws_kms_key.product.arn
    TRAINING_MAX_CHECKPOINT_BYTES              = tostring(var.training_runtime_settings.max_checkpoint_bytes)
    TRAINING_MAX_PROCESSED_DATASET_BYTES       = tostring(var.training_runtime_settings.max_processed_dataset_bytes)
    TRAINING_MAX_RAW_DATASET_BYTES             = tostring(var.training_runtime_settings.max_raw_dataset_bytes)
    TRAINING_MODEL_CACHE_ROOT                  = var.training_runtime_settings.model_cache_root
    TRAINING_QUEUE_URL                         = aws_sqs_queue.training.url
    TRAINING_VISIBILITY_MAX_FAILURES           = tostring(var.training_runtime_settings.visibility_max_failures)
    TRAINING_VISIBILITY_RENEW_INTERVAL_SECONDS = tostring(var.training_visibility_renew_interval_seconds)
    TRAINING_VISIBILITY_RETRY_INTERVAL_SECONDS = tostring(var.training_runtime_settings.visibility_retry_interval_seconds)
    TRAINING_VISIBILITY_TIMEOUT_SECONDS        = tostring(var.training_queue_visibility_timeout_seconds)
    TRAINING_WORKING_MAX_LORA_RANK             = tostring(var.training_runtime_settings.working_max_lora_rank)
    TRAINING_WORKSPACE_ROOT                    = var.training_runtime_settings.workspace_root
  }

  training_runtime_environment_file = join("\n", [
    for key in sort(keys(local.training_runtime_environment)) :
    "${key}=${jsonencode(local.training_runtime_environment[key])}"
  ])
}

resource "aws_launch_template" "training" {
  name_prefix            = "${local.name_prefix}-training-"
  description            = "Terraform-owned Training structure; release workflow owns AMI-only versions"
  image_id               = var.training_ami_id
  instance_type          = var.training_instance_type
  update_default_version = false

  iam_instance_profile {
    name = aws_iam_instance_profile.runtime["training"].name
  }

  vpc_security_group_ids = [aws_security_group.training.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.training_compute_settings.detailed_monitoring_enabled
  }

  block_device_mappings {
    device_name = var.training_compute_settings.root_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.training_compute_settings.root_volume_size_gib
      volume_type           = var.training_compute_settings.root_volume_type
    }
  }

  block_device_mappings {
    device_name = var.training_compute_settings.workspace_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.training_compute_settings.workspace_volume_size_gib
      volume_type           = var.training_compute_settings.workspace_volume_type
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/training_runtime_environment.sh.tftpl", {
    runtime_environment  = local.training_runtime_environment_file
    systemd_service_name = var.training_systemd_service_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = local.component_names.training
      Component = "training"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = "${local.component_names.training}-volume"
      Component = "training"
    }
  }

  tags = {
    Name      = "${local.name_prefix}-training-launch-template"
    Component = "training"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [image_id]
  }
}

# =============================================================================
# Training Auto Scaling Group and lifecycle hook
# =============================================================================
resource "aws_autoscaling_group" "training" {
  name                    = local.training_asg_name
  min_size                = var.training_capacity.min
  desired_capacity        = var.training_capacity.desired
  max_size                = var.training_capacity.max
  vpc_zone_identifier     = [for subnet in aws_subnet.private_application : subnet.id]
  health_check_type       = "EC2"
  default_instance_warmup = var.training_compute_settings.default_instance_warmup
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
  ]

  launch_template {
    id      = aws_launch_template.training.id
    version = "$Default"
  }

  tag {
    key                 = "Name"
    value               = local.component_names.training
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = "training"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_lifecycle_hook" "training_termination" {
  name                   = var.training_lifecycle_settings.hook_name
  autoscaling_group_name = aws_autoscaling_group.training.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = var.training_lifecycle_settings.heartbeat_timeout_seconds
  default_result         = var.training_lifecycle_settings.default_result
}

# =============================================================================
# SQS-driven Training scaling
# =============================================================================
resource "aws_autoscaling_policy" "training_scale_out" {
  name                   = "${local.name_prefix}-training-scale-out"
  autoscaling_group_name = aws_autoscaling_group.training.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.training_scaling_settings.scale_out_adjustment
  cooldown               = var.training_scaling_settings.scale_out_cooldown_seconds
}

resource "aws_autoscaling_policy" "training_scale_in" {
  name                   = "${local.name_prefix}-training-scale-in"
  autoscaling_group_name = aws_autoscaling_group.training.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.training_scaling_settings.scale_in_adjustment
  cooldown               = var.training_scaling_settings.scale_in_cooldown_seconds
}

resource "aws_cloudwatch_metric_alarm" "training_scale_out" {
  alarm_name          = "${local.name_prefix}-training-backlog-scale-out"
  alarm_description   = "Scale out when visible jobs per InService worker exceed the reviewed threshold; backlog is used directly at zero workers."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.training_scaling_settings.scale_out_backlog_per_instance
  evaluation_periods  = var.training_scaling_settings.evaluation_periods
  datapoints_to_alarm = var.training_scaling_settings.datapoints_to_alarm
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_autoscaling_policy.training_scale_out.arn]

  metric_query {
    id          = "backlog_per_worker"
    expression  = "IF(in_service > 0, visible / in_service, visible)"
    label       = "Visible jobs per InService Training worker"
    return_data = true
  }

  metric_query {
    id          = "visible"
    return_data = false

    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        QueueName = aws_sqs_queue.training.name
      }
    }
  }

  metric_query {
    id          = "in_service"
    return_data = false

    metric {
      namespace   = "AWS/AutoScaling"
      metric_name = "GroupInServiceInstances"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.training.name
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "training_scale_in" {
  alarm_name          = "${local.name_prefix}-training-backlog-scale-in"
  alarm_description   = "Scale in only when reviewed backlog-per-worker conditions remain low; worker scale-in protection remains authoritative."
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.training_scaling_settings.scale_in_backlog_per_instance
  evaluation_periods  = var.training_scaling_settings.evaluation_periods
  datapoints_to_alarm = var.training_scaling_settings.datapoints_to_alarm
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_autoscaling_policy.training_scale_in.arn]

  metric_query {
    id          = "backlog_per_worker"
    expression  = "IF(in_service > 0, visible / in_service, visible)"
    label       = "Visible jobs per InService Training worker"
    return_data = true
  }

  metric_query {
    id          = "visible"
    return_data = false

    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        QueueName = aws_sqs_queue.training.name
      }
    }
  }

  metric_query {
    id          = "in_service"
    return_data = false

    metric {
      namespace   = "AWS/AutoScaling"
      metric_name = "GroupInServiceInstances"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.training.name
      }
    }
  }
}

# =============================================================================
# Training outputs
# =============================================================================
output "training_launch_template_id" {
  description = "Terraform-owned Training Launch Template ID."
  value       = aws_launch_template.training.id
}

output "training_asg_name" {
  description = "Training Auto Scaling Group name."
  value       = aws_autoscaling_group.training.name
}

output "training_lifecycle_hook_name" {
  description = "Termination lifecycle hook name consumed by the Training runtime."
  value       = aws_autoscaling_lifecycle_hook.training_termination.name
}

output "training_callback_base_url" {
  description = "Public Backend HTTPS base URL reached by private Training workers through NAT."
  value       = "https://${aws_route53_record.backend_public.fqdn}"
}
