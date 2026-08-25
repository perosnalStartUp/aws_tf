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
