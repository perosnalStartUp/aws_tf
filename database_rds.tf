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
