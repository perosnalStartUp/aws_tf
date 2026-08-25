# =============================================================================
# Product-storage inputs
# =============================================================================
variable "product_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for product datasets and artifacts."
  nullable    = false

  validation {
    condition = (
      length(var.product_bucket_name) >= 3 &&
      length(var.product_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.product_bucket_name)) &&
      !can(regex("\\.\\.", var.product_bucket_name))
    )
    error_message = "product_bucket_name must be a valid 3-63 character lowercase S3 bucket name."
  }
}

variable "product_kms_key_deletion_window_days" {
  type        = number
  description = "Recovery window before a scheduled product KMS key deletion."
  nullable    = false

  validation {
    condition = (
      var.product_kms_key_deletion_window_days >= 7 &&
      var.product_kms_key_deletion_window_days <= 30 &&
      floor(var.product_kms_key_deletion_window_days) == var.product_kms_key_deletion_window_days
    )
    error_message = "product_kms_key_deletion_window_days must be a whole number from 7 through 30."
  }
}

variable "product_s3_component_access" {
  type = map(object({
    read_prefixes  = set(string)
    write_prefixes = set(string)
  }))
  description = "Explicit read/write S3 prefixes for backend, working, and training policy documents."
  nullable    = false

  validation {
    condition = (
      length(var.product_s3_component_access) == 3 &&
      alltrue([
        for component in ["backend", "working", "training"] :
        contains(keys(var.product_s3_component_access), component)
      ])
    )
    error_message = "product_s3_component_access must define exactly backend, working, and training."
  }

  validation {
    condition = alltrue(flatten([
      for access in values(var.product_s3_component_access) : [
        for prefix in setunion(access.read_prefixes, access.write_prefixes) :
        length(prefix) > 0 &&
        !startswith(prefix, "/") &&
        !endswith(prefix, "/") &&
        !strcontains(prefix, "*") &&
        !strcontains(prefix, "..")
      ]
    ]))
    error_message = "S3 prefixes must be non-empty relative prefixes without leading/trailing slash, wildcard, or parent traversal."
  }
}

# =============================================================================
# Product KMS key
# =============================================================================
resource "aws_kms_key" "product" {
  description             = "Product data encryption for ${local.name_prefix}"
  deletion_window_in_days = var.product_kms_key_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountIAMPermissions"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.aws_account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "product" {
  name          = "alias/${local.name_prefix}-product"
  target_key_id = aws_kms_key.product.key_id
}

# =============================================================================
# Product S3 bucket
# =============================================================================
resource "aws_s3_bucket" "product" {
  bucket = var.product_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "product" {
  bucket = aws_s3_bucket.product.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "product" {
  bucket = aws_s3_bucket.product.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "product" {
  bucket = aws_s3_bucket.product.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "product" {
  bucket = aws_s3_bucket.product.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.product.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# =============================================================================
# Product S3 resource policy
# =============================================================================
resource "aws_s3_bucket_policy" "product" {
  bucket = aws_s3_bucket.product.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.product.arn,
        "${aws_s3_bucket.product.arn}/*",
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.product]
}

# =============================================================================
# Component product-data IAM policies
# =============================================================================
locals {
  product_s3_component_policy_json = {
    for component, access in var.product_s3_component_access : component => jsonencode({
      Version = "2012-10-17"
      Statement = concat(
        [{
          Sid      = "ListApprovedPrefixes"
          Effect   = "Allow"
          Action   = ["s3:ListBucket"]
          Resource = aws_s3_bucket.product.arn
          Condition = {
            StringLike = {
              "s3:prefix" = flatten([
                for prefix in sort(tolist(setunion(access.read_prefixes, access.write_prefixes))) :
                [prefix, "${prefix}/*"]
              ])
            }
          }
        }],
        length(setunion(access.read_prefixes, access.write_prefixes)) > 0 ? [{
          Sid    = "ReadApprovedPrefixes"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
          ]
          Resource = [
            for prefix in sort(tolist(setunion(access.read_prefixes, access.write_prefixes))) :
            "${aws_s3_bucket.product.arn}/${prefix}/*"
          ]
        }] : [],
        length(access.write_prefixes) > 0 ? [{
          Sid    = "WriteApprovedPrefixes"
          Effect = "Allow"
          Action = [
            "s3:AbortMultipartUpload",
            "s3:DeleteObject",
            "s3:PutObject",
          ]
          Resource = [
            for prefix in sort(tolist(access.write_prefixes)) :
            "${aws_s3_bucket.product.arn}/${prefix}/*"
          ]
        }] : [],
        [{
          Sid    = "UseProductKMSKey"
          Effect = "Allow"
          Action = concat(
            ["kms:Decrypt", "kms:DescribeKey"],
            length(access.write_prefixes) > 0 ? [
              "kms:Encrypt",
              "kms:GenerateDataKey",
              "kms:ReEncryptFrom",
              "kms:ReEncryptTo",
            ] : [],
          )
          Resource = aws_kms_key.product.arn
        }],
      )
    })
  }
}

# =============================================================================
# Product-storage outputs
# =============================================================================
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
