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
