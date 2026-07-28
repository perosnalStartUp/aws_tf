variable "s3_gateway_endpoint_bucket_arns" {
  type        = set(string)
  description = "Temporary cross-PR input for approved S3 bucket ARNs; data-kms-s3 must replace it with direct aws_s3_bucket resource references."
  nullable    = false

  validation {
    condition = (
      length(var.s3_gateway_endpoint_bucket_arns) > 0 &&
      alltrue([
        for arn in var.s3_gateway_endpoint_bucket_arns :
        can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
      ])
    )
    error_message = "s3_gateway_endpoint_bucket_arns must contain at least one valid S3 bucket ARN."
  }
}
