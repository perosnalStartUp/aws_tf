output "product_bucket_arn" {
  description = "ARN of the Terraform-managed product S3 bucket."
  value       = aws_s3_bucket.product.arn
}

output "product_bucket_name" {
  description = "Name of the Terraform-managed product S3 bucket."
  value       = aws_s3_bucket.product.bucket
}

output "product_kms_key_arn" {
  description = "ARN of the Terraform-managed product KMS key."
  value       = aws_kms_key.product.arn
}

output "product_s3_component_policy_json" {
  description = "IAM policy JSON keyed by backend, working, and training for later role attachment."
  value       = local.product_s3_component_policy_json
}
