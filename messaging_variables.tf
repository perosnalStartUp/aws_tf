variable "training_queue_visibility_timeout_seconds" {
  type        = number
  description = "Training queue visibility timeout derived from maximum job and renewal behavior."
  nullable    = false

  validation {
    condition = (
      var.training_queue_visibility_timeout_seconds >= 0 &&
      var.training_queue_visibility_timeout_seconds <= 43200 &&
      floor(var.training_queue_visibility_timeout_seconds) == var.training_queue_visibility_timeout_seconds
    )
    error_message = "training_queue_visibility_timeout_seconds must be a whole number from 0 through 43200."
  }
}

variable "training_visibility_renew_interval_seconds" {
  type        = number
  description = "Worker visibility-renew interval used to validate queue timing."
  nullable    = false

  validation {
    condition = (
      var.training_visibility_renew_interval_seconds >= 1 &&
      floor(var.training_visibility_renew_interval_seconds) == var.training_visibility_renew_interval_seconds
    )
    error_message = "training_visibility_renew_interval_seconds must be a positive whole number."
  }
}

variable "training_queue_message_retention_seconds" {
  type        = number
  description = "Retention period for unprocessed Training messages."
  nullable    = false

  validation {
    condition = (
      var.training_queue_message_retention_seconds >= 60 &&
      var.training_queue_message_retention_seconds <= 1209600
    )
    error_message = "training_queue_message_retention_seconds must be from 60 through 1209600."
  }
}

variable "training_dlq_message_retention_seconds" {
  type        = number
  description = "Retention period for failed Training messages in the DLQ."
  nullable    = false

  validation {
    condition = (
      var.training_dlq_message_retention_seconds >= var.training_queue_message_retention_seconds &&
      var.training_dlq_message_retention_seconds <= 1209600
    )
    error_message = "DLQ retention must be at least the source-queue retention and at most 1209600."
  }
}

variable "training_queue_receive_wait_time_seconds" {
  type        = number
  description = "SQS long-poll duration for Training workers."
  nullable    = false

  validation {
    condition = (
      var.training_queue_receive_wait_time_seconds >= 0 &&
      var.training_queue_receive_wait_time_seconds <= 20
    )
    error_message = "training_queue_receive_wait_time_seconds must be from 0 through 20."
  }
}

variable "training_queue_max_receive_count" {
  type        = number
  description = "Number of receives before a Training message moves to the DLQ."
  nullable    = false

  validation {
    condition = (
      var.training_queue_max_receive_count >= 1 &&
      var.training_queue_max_receive_count <= 1000 &&
      floor(var.training_queue_max_receive_count) == var.training_queue_max_receive_count
    )
    error_message = "training_queue_max_receive_count must be a whole number from 1 through 1000."
  }
}

variable "training_queue_kms_deletion_window_days" {
  type        = number
  description = "Recovery window before scheduled deletion of the Training queue KMS key."
  nullable    = false

  validation {
    condition = (
      var.training_queue_kms_deletion_window_days >= 7 &&
      var.training_queue_kms_deletion_window_days <= 30
    )
    error_message = "training_queue_kms_deletion_window_days must be from 7 through 30."
  }
}

check "training_visibility_renewal_margin" {
  assert {
    condition = (
      var.training_queue_visibility_timeout_seconds >=
      2 * var.training_visibility_renew_interval_seconds
    )
    error_message = "Training queue visibility timeout must be at least twice the worker renewal interval."
  }
}
