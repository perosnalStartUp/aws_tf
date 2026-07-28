variable "database_name" {
  type        = string
  description = "Initial PostgreSQL database name used by Backend."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must start with a letter and contain at most 63 alphanumeric/underscore characters."
  }
}

variable "database_master_username" {
  type        = string
  description = "Non-secret PostgreSQL master username; AWS manages the password in Secrets Manager."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.database_master_username))
    error_message = "database_master_username must be a valid PostgreSQL identifier."
  }
}

variable "database_engine_version" {
  type        = string
  description = "Approved PostgreSQL engine version."
  nullable    = false
}

variable "database_parameter_group_family" {
  type        = string
  description = "Parameter group family matching database_engine_version."
  nullable    = false
}

variable "database_instance_class" {
  type        = string
  description = "Approved RDS instance class."
  nullable    = false
}

variable "database_allocated_storage_gib" {
  type        = number
  description = "Initial RDS storage allocation in GiB."
  nullable    = false
}

variable "database_max_allocated_storage_gib" {
  type        = number
  description = "Maximum RDS autoscaled storage allocation in GiB."
  nullable    = false

  validation {
    condition     = var.database_max_allocated_storage_gib >= var.database_allocated_storage_gib
    error_message = "database_max_allocated_storage_gib must be at least database_allocated_storage_gib."
  }
}

variable "database_storage_type" {
  type        = string
  description = "Approved RDS storage type."
  nullable    = false

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.database_storage_type)
    error_message = "database_storage_type must be gp2, gp3, io1, or io2."
  }
}

variable "database_multi_az" {
  type        = bool
  description = "Whether the RDS instance is deployed Multi-AZ."
  nullable    = false
}

variable "database_backup_retention_days" {
  type        = number
  description = "Automated backup retention in days."
  nullable    = false

  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "database_backup_retention_days must be from 1 through 35."
  }
}

variable "database_backup_window" {
  type        = string
  description = "UTC RDS backup window."
  nullable    = false
}

variable "database_maintenance_window" {
  type        = string
  description = "UTC RDS maintenance window."
  nullable    = false
}

variable "database_deletion_protection" {
  type        = bool
  description = "Whether RDS deletion protection is enabled."
  nullable    = false
}

variable "database_skip_final_snapshot" {
  type        = bool
  description = "Whether deletion may skip a final snapshot."
  nullable    = false
}

variable "database_final_snapshot_identifier" {
  type        = string
  description = "Final snapshot identifier required when final snapshots are enabled."
  default     = null
  nullable    = true
}

variable "database_enabled_log_exports" {
  type        = set(string)
  description = "Approved PostgreSQL log exports."
  nullable    = false

  validation {
    condition = alltrue([
      for log_type in var.database_enabled_log_exports :
      contains(["postgresql", "upgrade"], log_type)
    ])
    error_message = "database_enabled_log_exports may contain only postgresql and upgrade."
  }
}

variable "database_monitoring_interval_seconds" {
  type        = number
  description = "Enhanced Monitoring interval; use zero to disable."
  nullable    = false

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.database_monitoring_interval_seconds)
    error_message = "database_monitoring_interval_seconds must be one of 0, 1, 5, 10, 15, 30, or 60."
  }
}

variable "database_performance_insights_enabled" {
  type        = bool
  description = "Whether Performance Insights is enabled."
  nullable    = false
}

variable "database_performance_insights_retention_days" {
  type        = number
  description = "Performance Insights retention; used only when enabled."
  nullable    = false

  validation {
    condition = (
      var.database_performance_insights_retention_days == 7 ||
      (
        var.database_performance_insights_retention_days >= 31 &&
        var.database_performance_insights_retention_days <= 731 &&
        var.database_performance_insights_retention_days % 31 == 0
      )
    )
    error_message = "Performance Insights retention must be 7 or a multiple of 31 from 31 through 731."
  }
}

variable "database_parameters" {
  type        = map(string)
  description = "Reviewed PostgreSQL parameter overrides; an empty map uses family defaults."
  default     = {}
  nullable    = false
}

variable "database_kms_deletion_window_days" {
  type        = number
  description = "Recovery window before scheduled deletion of the database KMS key."
  nullable    = false

  validation {
    condition     = var.database_kms_deletion_window_days >= 7 && var.database_kms_deletion_window_days <= 30
    error_message = "database_kms_deletion_window_days must be from 7 through 30."
  }
}

check "database_final_snapshot_contract" {
  assert {
    condition = (
      var.database_skip_final_snapshot ||
      (
        var.database_final_snapshot_identifier != null &&
        length(var.database_final_snapshot_identifier) >= 1
      )
    )
    error_message = "database_final_snapshot_identifier is required when database_skip_final_snapshot is false."
  }
}
