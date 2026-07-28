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
