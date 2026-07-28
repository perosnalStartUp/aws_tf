variable "project_name" {
  type        = string
  description = "Lowercase project identifier used in names and tags."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-25 lowercase alphanumeric/hyphen characters, start with a letter, and end with a letter or digit."
  }
}

variable "environment" {
  type        = string
  description = "Lowercase deployment environment identifier."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,14}[a-z0-9]$", var.environment))
    error_message = "environment must be 2-16 lowercase alphanumeric/hyphen characters, start with a letter, and end with a letter or digit."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for this root module."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier such as us-east-1."
  }
}

variable "aws_account_id" {
  type        = string
  description = "Expected 12-digit AWS account ID. Test IDs are allowed only in Terraform tests."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "owner" {
  type        = string
  description = "Owner tag value for operational accountability."
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

  validation {
    condition = alltrue([
      for key, value in var.extra_tags :
      length(trimspace(key)) > 0 && length(key) <= 128 && length(value) <= 256
    ])
    error_message = "extra_tags keys must be 1-128 characters and values at most 256 characters."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR allocated to the environment VPC."
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Exactly two distinct Availability Zones in aws_region, ordered AZ-A then AZ-B."
  nullable    = false

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      length(distinct(var.availability_zones)) == 2 &&
      alltrue([
        for az in var.availability_zones :
        startswith(az, var.aws_region) && can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+[a-z]$", az))
      ])
    )
    error_message = "availability_zones must contain exactly two distinct AZs belonging to aws_region."
  }
}

variable "subnet_cidrs" {
  type = object({
    public_a      = string
    public_b      = string
    private_app_a = string
    private_app_b = string
    private_db_a  = string
    private_db_b  = string
  })
  description = "Six IPv4 subnet CIDRs for the two-AZ public, private application, and private database layers."
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in values(var.subnet_cidrs) : can(cidrnetmask(cidr))
    ])
    error_message = "Every subnet_cidrs value must be a valid IPv4 CIDR."
  }
}

variable "enable_ipv6" {
  type        = bool
  description = "Whether the environment enables IPv6. This remains an explicit owner decision."
  nullable    = false
}

variable "backend_capacity" {
  type = object({
    min     = number
    desired = number
    max     = number
  })
  description = "Backend ASG capacity bounds. Initial desired capacity must remain one."
  nullable    = false
}

variable "training_capacity" {
  type = object({
    min     = number
    desired = number
    max     = number
  })
  description = "Training ASG capacity bounds for the On-Demand, scale-from-zero design."
  nullable    = false
}

variable "backend_ami_id" {
  type        = string
  description = "Exact approved Backend AMI ID."
  nullable    = false

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8}([0-9a-f]{9})?$", var.backend_ami_id))
    error_message = "backend_ami_id must be an exact short or long AMI ID."
  }
}

variable "working_ami_id" {
  type        = string
  description = "Exact approved Working V0 AMI ID."
  nullable    = false

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8}([0-9a-f]{9})?$", var.working_ami_id))
    error_message = "working_ami_id must be an exact short or long AMI ID."
  }
}

variable "training_ami_id" {
  type        = string
  description = "Exact approved Training AMI ID."
  nullable    = false

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8}([0-9a-f]{9})?$", var.training_ami_id))
    error_message = "training_ami_id must be an exact short or long AMI ID."
  }
}

variable "application_public_ip_assignment" {
  type = object({
    backend  = bool
    working  = bool
    training = bool
  })
  description = "Safety input that must keep public-IP assignment disabled for all application instances."
  default = {
    backend  = false
    working  = false
    training = false
  }
  nullable = false

  validation {
    condition = alltrue([
      !var.application_public_ip_assignment.backend,
      !var.application_public_ip_assignment.working,
      !var.application_public_ip_assignment.training,
    ])
    error_message = "Backend, Working, and Training instances must not receive public IP addresses."
  }
}
