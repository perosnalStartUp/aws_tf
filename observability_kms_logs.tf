resource "aws_kms_key" "observability" {
  description             = "CloudWatch Logs encryption for ${local.name_prefix}"
  deletion_window_in_days = var.observability_settings.kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountIAMPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRegionalCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/personal-lora/${var.environment}/*"
          }
        }
      },
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "observability" {
  name          = "alias/${local.name_prefix}-observability"
  target_key_id = aws_kms_key.observability.key_id
}

resource "aws_cloudwatch_log_group" "runtime" {
  for_each = toset(["backend", "working", "training"])

  name              = "/personal-lora/${var.environment}/${each.key}"
  retention_in_days = var.observability_settings.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn

  tags = {
    Component = each.key
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/personal-lora/${var.environment}/vpc-flow"
  retention_in_days = var.observability_settings.log_retention_days
  kms_key_id        = aws_kms_key.observability.arn
}
