output "state_bucket_arn" {
  description = "ARN of the Terraform State bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_name" {
  description = "Name of the Terraform State bucket."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_region" {
  description = "Region used by the State bootstrap root."
  value       = var.aws_region
}

output "state_kms_key_arn" {
  description = "ARN of the Terraform-managed customer KMS key for State encryption."
  value       = aws_kms_key.state.arn
}
