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
