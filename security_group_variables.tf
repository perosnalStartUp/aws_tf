variable "backend_application_port" {
  type        = number
  description = "Backend application port accepted only from the ALB security group."
  nullable    = false

  validation {
    condition     = var.backend_application_port >= 1024 && var.backend_application_port <= 65535
    error_message = "backend_application_port must be an unprivileged TCP port from 1024 through 65535."
  }
}

variable "working_service_port" {
  type        = number
  description = "Working inference service port accepted only from the Backend security group."
  nullable    = false

  validation {
    condition     = var.working_service_port >= 1024 && var.working_service_port <= 65535
    error_message = "working_service_port must be an unprivileged TCP port from 1024 through 65535."
  }
}

variable "database_port" {
  type        = number
  description = "PostgreSQL port accepted only from the Backend security group."
  nullable    = false

  validation {
    condition     = var.database_port >= 1024 && var.database_port <= 65535
    error_message = "database_port must be an unprivileged TCP port from 1024 through 65535."
  }
}
