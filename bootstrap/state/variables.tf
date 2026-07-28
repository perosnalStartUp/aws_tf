variable "project_name" {
  type        = string
  description = "Lowercase project identifier used in State resource names and tags."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-25 lowercase alphanumeric/hyphen characters."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region that owns the Terraform State bucket."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier such as us-east-1."
  }
}

variable "aws_account_id" {
  type        = string
  description = "Expected 12-digit AWS account ID for the State bootstrap root."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform State."
  nullable    = false

  validation {
    condition = (
      length(var.state_bucket_name) >= 3 &&
      length(var.state_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.state_bucket_name)) &&
      !can(regex("\\.\\.", var.state_bucket_name))
    )
    error_message = "state_bucket_name must be a valid 3-63 character lowercase S3 bucket name."
  }
}

variable "state_kms_key_deletion_window_days" {
  type        = number
  description = "Recovery window before a scheduled Terraform State KMS key deletion."
  nullable    = false

  validation {
    condition = (
      var.state_kms_key_deletion_window_days >= 7 &&
      var.state_kms_key_deletion_window_days <= 30 &&
      floor(var.state_kms_key_deletion_window_days) == var.state_kms_key_deletion_window_days
    )
    error_message = "state_kms_key_deletion_window_days must be a whole number from 7 through 30."
  }
}

variable "state_access_principal_arns" {
  type        = set(string)
  description = "IAM principal ARNs allowed to list and read/write State and lock objects."
  nullable    = false

  validation {
    condition = (
      length(var.state_access_principal_arns) > 0 &&
      alltrue([
        for arn in var.state_access_principal_arns :
        can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/[A-Za-z0-9+=,.@_/-]+$", arn))
      ])
    )
    error_message = "state_access_principal_arns must contain at least one valid IAM role or user ARN."
  }
}

variable "owner" {
  type        = string
  description = "Operational owner responsible for State recovery and break-glass access."
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) >= 2 && length(trimspace(var.owner)) <= 64
    error_message = "owner must contain 2-64 non-whitespace characters."
  }
}

variable "cost_center" {
  type        = string
  description = "Cost allocation tag value; use N/A only when no cost center exists."
  nullable    = false

  validation {
    condition     = length(trimspace(var.cost_center)) >= 2 && length(trimspace(var.cost_center)) <= 64
    error_message = "cost_center must contain 2-64 non-whitespace characters."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional non-secret tags. Required governance tags take precedence."
  default     = {}
  nullable    = false
}
