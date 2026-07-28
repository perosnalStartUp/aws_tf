variable "private_zone_name" {
  type        = string
  description = "Private Route53 zone associated with the environment VPC."
  nullable    = false

  validation {
    condition = (
      length(var.private_zone_name) <= 253 &&
      can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$", var.private_zone_name))
    )
    error_message = "private_zone_name must be a valid lowercase multi-label DNS name without a trailing dot."
  }
}
