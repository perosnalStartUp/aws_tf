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
