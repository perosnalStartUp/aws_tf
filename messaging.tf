# =============================================================================
# Training messaging inputs
# =============================================================================
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

# =============================================================================
# Training queue KMS key
# =============================================================================
resource "aws_kms_key" "training_queue" {
  description             = "Training SQS encryption for ${local.name_prefix}"
  deletion_window_in_days = var.training_queue_kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountIAMPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSQSServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      },
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "training_queue" {
  name          = "alias/${local.name_prefix}-training-queue"
  target_key_id = aws_kms_key.training_queue.key_id
}

# =============================================================================
# Training queue and DLQ
# =============================================================================
resource "aws_sqs_queue" "training_dlq" {
  name                      = "${local.name_prefix}-training-dlq"
  message_retention_seconds = var.training_dlq_message_retention_seconds
  kms_master_key_id         = aws_kms_key.training_queue.arn
}

resource "aws_sqs_queue" "training" {
  name                       = "${local.name_prefix}-training"
  visibility_timeout_seconds = var.training_queue_visibility_timeout_seconds
  message_retention_seconds  = var.training_queue_message_retention_seconds
  receive_wait_time_seconds  = var.training_queue_receive_wait_time_seconds
  kms_master_key_id          = aws_kms_key.training_queue.arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.training_dlq.arn
    maxReceiveCount     = var.training_queue_max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "training_dlq" {
  queue_url = aws_sqs_queue.training_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.training.arn]
  })
}

# =============================================================================
# Training queue resource policy
# =============================================================================
resource "aws_sqs_queue_policy" "training" {
  queue_url = aws_sqs_queue.training.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "BackendSend"
        Effect    = "Allow"
        Principal = { AWS = local.backend_runtime_role.arn }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.training.arn
      },
      {
        Sid       = "TrainingConsume"
        Effect    = "Allow"
        Principal = { AWS = local.training_runtime_role.arn }
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.training.arn
      },
    ]
  })
}

# =============================================================================
# Messaging outputs
# =============================================================================
output "training_queue_arn" {
  description = "ARN of the Training work queue."
  value       = aws_sqs_queue.training.arn
}

output "training_queue_url" {
  description = "URL of the Training work queue."
  value       = aws_sqs_queue.training.url
}

output "training_dlq_arn" {
  description = "ARN of the Training dead-letter queue."
  value       = aws_sqs_queue.training_dlq.arn
}

output "training_dlq_url" {
  description = "URL of the Training dead-letter queue."
  value       = aws_sqs_queue.training_dlq.url
}

output "training_queue_kms_key_arn" {
  description = "ARN of the Terraform-managed Training queue KMS key."
  value       = aws_kms_key.training_queue.arn
}
