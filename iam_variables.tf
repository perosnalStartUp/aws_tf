variable "github_organization" {
  type        = string
  description = "GitHub organization that owns the approved workflow repositories."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_organization))
    error_message = "github_organization must be a valid GitHub organization name."
  }
}

variable "github_repositories" {
  type = object({
    terraform = string
    backend   = string
    gpu       = string
  })
  description = "Repository names for Terraform, Backend, and GPU workflow ownership."
  nullable    = false

  validation {
    condition = alltrue([
      for repository in values(var.github_repositories) :
      can(regex("^[A-Za-z0-9._-]{1,100}$", repository))
    ])
    error_message = "Each github_repositories value must be a non-empty GitHub repository name."
  }
}

variable "github_oidc_subjects" {
  type = object({
    terraform        = set(string)
    backend_packer   = set(string)
    backend_release  = set(string)
    training_packer  = set(string)
    training_release = set(string)
  })
  description = "Exact approved GitHub OIDC subject claims for each workflow role."
  nullable    = false

  validation {
    condition = (
      length(var.github_oidc_subjects.terraform) > 0 &&
      length(var.github_oidc_subjects.backend_packer) > 0 &&
      length(var.github_oidc_subjects.backend_release) > 0 &&
      length(var.github_oidc_subjects.training_packer) > 0 &&
      length(var.github_oidc_subjects.training_release) > 0 &&
      alltrue([
        for subject in var.github_oidc_subjects.terraform :
        startswith(subject, "repo:${var.github_organization}/${var.github_repositories.terraform}:") &&
        !strcontains(subject, "*")
      ]) &&
      alltrue([
        for subject in setunion(
          var.github_oidc_subjects.backend_packer,
          var.github_oidc_subjects.backend_release,
        ) :
        startswith(subject, "repo:${var.github_organization}/${var.github_repositories.backend}:") &&
        !strcontains(subject, "*")
      ]) &&
      alltrue([
        for subject in setunion(
          var.github_oidc_subjects.training_packer,
          var.github_oidc_subjects.training_release,
        ) :
        startswith(subject, "repo:${var.github_organization}/${var.github_repositories.gpu}:") &&
        !strcontains(subject, "*")
      ])
    )
    error_message = "Every workflow role must use non-wildcard subjects under its exact approved repository."
  }
}

variable "working_auth_secret_arn" {
  type        = string
  description = "Approved external Secrets Manager ARN for Working authentication."
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", var.working_auth_secret_arn))
    error_message = "working_auth_secret_arn must be a Secrets Manager secret ARN."
  }
}

variable "training_callback_secret_arn" {
  type        = string
  description = "Single approved Secrets Manager ARN for Training callback authentication."
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", var.training_callback_secret_arn))
    error_message = "training_callback_secret_arn must be a Secrets Manager secret ARN."
  }
}

variable "runtime_log_group_arns" {
  type = object({
    backend  = set(string)
    working  = set(string)
    training = set(string)
  })
  description = "Cross-PR CloudWatch Log Group ARNs until observability resources exist."
  nullable    = false

  validation {
    condition = alltrue(flatten([
      for arns in values(var.runtime_log_group_arns) : [
        for arn in arns :
        can(regex("^arn:aws:logs:[a-z0-9-]+:[0-9]{12}:log-group:[A-Za-z0-9_./#-]+:\\*$", arn))
      ]
    ]))
    error_message = "runtime_log_group_arns values must be CloudWatch Log Group ARNs ending in :*."
  }
}

variable "backend_launch_template_name" {
  type        = string
  description = "Future Terraform-owned Backend Launch Template name used to scope release IAM."
  nullable    = false
}

variable "backend_asg_name" {
  type        = string
  description = "Future Terraform-owned Backend ASG name used to scope release IAM."
  nullable    = false
}

variable "training_launch_template_name" {
  type        = string
  description = "Future Terraform-owned Training Launch Template name used to scope release IAM."
  nullable    = false
}

variable "training_asg_name" {
  type        = string
  description = "Future Terraform-owned Training ASG name used to scope runtime/release IAM."
  nullable    = false
}
