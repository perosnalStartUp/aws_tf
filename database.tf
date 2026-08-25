# =============================================================================
# Database inputs
# =============================================================================
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

# =============================================================================
# Database KMS key
# =============================================================================
resource "aws_kms_key" "database" {
  description             = "RDS and managed master-secret encryption for ${local.name_prefix}"
  deletion_window_in_days = var.database_kms_deletion_window_days
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

resource "aws_kms_alias" "database" {
  name          = "alias/${local.name_prefix}-database"
  target_key_id = aws_kms_key.database.key_id
}

# =============================================================================
# Private PostgreSQL RDS
# =============================================================================
resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name_prefix}-postgres"
  subnet_ids = [for subnet in aws_subnet.private_database : subnet.id]

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name_prefix}-postgres"
  family = var.database_parameter_group_family

  dynamic "parameter" {
    for_each = var.database_parameters

    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.database_monitoring_interval_seconds > 0 ? 1 : 0

  name = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.database_monitoring_interval_seconds > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.database_engine_version
  instance_class = var.database_instance_class
  port           = var.database_port

  db_name  = var.database_name
  username = var.database_master_username

  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.database.arn

  allocated_storage     = var.database_allocated_storage_gib
  max_allocated_storage = var.database_max_allocated_storage_gib
  storage_type          = var.database_storage_type
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.database.arn

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = var.database_multi_az

  parameter_group_name            = aws_db_parameter_group.postgres.name
  enabled_cloudwatch_logs_exports = sort(tolist(var.database_enabled_log_exports))

  backup_retention_period = var.database_backup_retention_days
  backup_window           = var.database_backup_window
  maintenance_window      = var.database_maintenance_window

  monitoring_interval = var.database_monitoring_interval_seconds
  monitoring_role_arn = (
    var.database_monitoring_interval_seconds > 0 ?
    aws_iam_role.rds_monitoring[0].arn :
    null
  )

  performance_insights_enabled          = var.database_performance_insights_enabled
  performance_insights_kms_key_id       = var.database_performance_insights_enabled ? aws_kms_key.database.arn : null
  performance_insights_retention_period = var.database_performance_insights_enabled ? var.database_performance_insights_retention_days : null

  deletion_protection       = var.database_deletion_protection
  skip_final_snapshot       = var.database_skip_final_snapshot
  final_snapshot_identifier = var.database_skip_final_snapshot ? null : var.database_final_snapshot_identifier
  copy_tags_to_snapshot     = true

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}

# =============================================================================
# Database outputs
# =============================================================================
output "database_address" {
  description = "Private RDS hostname for Backend."
  value       = aws_db_instance.postgres.address
}

output "database_name" {
  description = "PostgreSQL database name."
  value       = aws_db_instance.postgres.db_name
}

output "database_port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.postgres.port
}

output "database_master_secret_arn" {
  description = "ARN of the AWS-managed RDS master credential secret; no secret value is output."
  value       = one(aws_db_instance.postgres.master_user_secret).secret_arn
}
