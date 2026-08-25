# =============================================================================
# Observability and cost inputs
# =============================================================================
variable "observability_settings" {
  type = object({
    log_retention_days                = number
    kms_deletion_window_days          = number
    flow_log_traffic_type             = string
    alarm_action_arns                 = set(string)
    queue_visible_messages_threshold  = number
    queue_oldest_message_age_seconds  = number
    dlq_visible_messages_threshold    = number
    backend_unhealthy_hosts_threshold = number
    backend_5xx_threshold             = number
    backend_latency_seconds_threshold = number
    rds_cpu_percentage_threshold      = number
    rds_free_storage_bytes_threshold  = number
    working_status_failures_threshold = number
    nat_error_port_threshold          = number
    nat_packet_drop_threshold         = number
    alarm_period_seconds              = number
    alarm_evaluation_periods          = number
    budget_limit_usd                  = number
    budget_alert_percentage           = number
    cost_anomaly_threshold_usd        = number
    cost_notification_emails          = set(string)
  })
  description = "Owner-approved log retention, alarm thresholds/actions, and monthly cost controls."
  nullable    = false

  validation {
    condition = (
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.observability_settings.log_retention_days) &&
      var.observability_settings.kms_deletion_window_days >= 7 &&
      var.observability_settings.kms_deletion_window_days <= 30 &&
      contains(["ACCEPT", "REJECT", "ALL"], var.observability_settings.flow_log_traffic_type) &&
      length(var.observability_settings.alarm_action_arns) > 0 &&
      alltrue([
        for arn in var.observability_settings.alarm_action_arns :
        can(regex("^arn:aws:(sns|autoscaling):[a-z0-9-]+:[0-9]{12}:.+$", arn))
      ]) &&
      var.observability_settings.queue_visible_messages_threshold >= 1 &&
      var.observability_settings.queue_oldest_message_age_seconds >= 1 &&
      var.observability_settings.dlq_visible_messages_threshold >= 1 &&
      var.observability_settings.backend_unhealthy_hosts_threshold >= 1 &&
      var.observability_settings.backend_5xx_threshold >= 1 &&
      var.observability_settings.backend_latency_seconds_threshold > 0 &&
      var.observability_settings.rds_cpu_percentage_threshold > 0 &&
      var.observability_settings.rds_cpu_percentage_threshold <= 100 &&
      var.observability_settings.rds_free_storage_bytes_threshold > 0 &&
      var.observability_settings.working_status_failures_threshold >= 1 &&
      var.observability_settings.nat_error_port_threshold >= 1 &&
      var.observability_settings.nat_packet_drop_threshold >= 1 &&
      contains([10, 20, 30, 60, 120, 300, 600, 900, 1800, 3600], var.observability_settings.alarm_period_seconds) &&
      var.observability_settings.alarm_evaluation_periods >= 1 &&
      var.observability_settings.budget_limit_usd > 0 &&
      var.observability_settings.budget_alert_percentage > 0 &&
      var.observability_settings.cost_anomaly_threshold_usd > 0 &&
      length(var.observability_settings.cost_notification_emails) > 0 &&
      alltrue([
        for email in var.observability_settings.cost_notification_emails :
        can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", email))
      ])
    )
    error_message = "observability_settings must use supported retention/period values, explicit action ARNs, positive reviewed thresholds, and valid cost notification emails."
  }
}

# =============================================================================
# Log KMS key and log groups
# =============================================================================
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

# =============================================================================
# VPC Flow Logs
# =============================================================================
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "write-vpc-flow-logs"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow.arn}:*"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow.arn
  traffic_type    = var.observability_settings.flow_log_traffic_type
  vpc_id          = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-vpc-flow"
  }
}

# =============================================================================
# Training queue alarms
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "training_queue_depth" {
  alarm_name          = "${local.name_prefix}-training-queue-depth"
  alarm_description   = "Visible Training jobs exceed the reviewed queue-depth threshold."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.training.name }
  statistic           = "Maximum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.queue_visible_messages_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = sort(tolist(var.observability_settings.alarm_action_arns))
}

resource "aws_cloudwatch_metric_alarm" "training_queue_age" {
  alarm_name          = "${local.name_prefix}-training-queue-age"
  alarm_description   = "Oldest visible Training job exceeds the reviewed latency threshold."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = aws_sqs_queue.training.name }
  statistic           = "Maximum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.queue_oldest_message_age_seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = sort(tolist(var.observability_settings.alarm_action_arns))
}

resource "aws_cloudwatch_metric_alarm" "training_dlq_depth" {
  alarm_name          = "${local.name_prefix}-training-dlq-depth"
  alarm_description   = "Training messages reached the dead-letter queue."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.training_dlq.name }
  statistic           = "Maximum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.dlq_visible_messages_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = sort(tolist(var.observability_settings.alarm_action_arns))
}

# =============================================================================
# Service and infrastructure alarms
# =============================================================================
locals {
  alarm_actions = sort(tolist(var.observability_settings.alarm_action_arns))
}

resource "aws_cloudwatch_metric_alarm" "backend_unhealthy_hosts" {
  alarm_name  = "${local.name_prefix}-backend-unhealthy-hosts"
  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  dimensions = {
    LoadBalancer = aws_lb.backend.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
  statistic           = "Maximum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.backend_unhealthy_hosts_threshold
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "backend_in_service_capacity" {
  alarm_name          = "${local.name_prefix}-backend-in-service-capacity"
  alarm_description   = "Backend has fewer than its required initial one InService instance."
  namespace           = "AWS/AutoScaling"
  metric_name         = "GroupInServiceInstances"
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.backend.name }
  statistic           = "Minimum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "backend_5xx" {
  alarm_name  = "${local.name_prefix}-backend-target-5xx"
  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"
  dimensions = {
    LoadBalancer = aws_lb.backend.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
  statistic           = "Sum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.backend_5xx_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "backend_latency" {
  alarm_name  = "${local.name_prefix}-backend-latency"
  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"
  dimensions = {
    LoadBalancer = aws_lb.backend.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
  statistic           = "Average"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.backend_latency_seconds_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "working_status" {
  alarm_name          = "${local.name_prefix}-working-status"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = aws_instance.working.id }
  statistic           = "Maximum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.working_status_failures_threshold
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.postgres.identifier }
  statistic           = "Average"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.rds_cpu_percentage_threshold
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name_prefix}-rds-free-storage"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.postgres.identifier }
  statistic           = "Minimum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.observability_settings.rds_free_storage_bytes_threshold
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "nat_error_ports" {
  alarm_name          = "${local.name_prefix}-nat-error-ports"
  namespace           = "AWS/NATGateway"
  metric_name         = "ErrorPortAllocation"
  dimensions          = { NatGatewayId = aws_nat_gateway.a.id }
  statistic           = "Sum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.nat_error_port_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "nat_packet_drop" {
  alarm_name          = "${local.name_prefix}-nat-packet-drop"
  namespace           = "AWS/NATGateway"
  metric_name         = "PacketsDropCount"
  dimensions          = { NatGatewayId = aws_nat_gateway.a.id }
  statistic           = "Sum"
  period              = var.observability_settings.alarm_period_seconds
  evaluation_periods  = var.observability_settings.alarm_evaluation_periods
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.observability_settings.nat_packet_drop_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

# =============================================================================
# Shared CloudWatch dashboard
# =============================================================================
resource "aws_cloudwatch_dashboard" "environment" {
  dashboard_name = "${local.name_prefix}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Backend ALB"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.backend.arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "TargetResponseTime", ".", "."],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.backend.name],
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Training Queue and Capacity"
          region = var.aws_region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.training.name],
            [".", "ApproximateAgeOfOldestMessage", ".", "."],
            [".", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.training_dlq.name],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.training.name],
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "RDS and Working"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.postgres.identifier],
            [".", "FreeStorageSpace", ".", "."],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.working.id],
          ]
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "Single NAT Gateway"
          region = var.aws_region
          metrics = [
            ["AWS/NATGateway", "BytesOutToDestination", "NatGatewayId", aws_nat_gateway.a.id],
            [".", "ErrorPortAllocation", ".", "."],
            [".", "PacketsDropCount", ".", "."],
          ]
        }
      },
    ]
  })
}

# =============================================================================
# Budget and cost anomaly detection
# =============================================================================
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.observability_settings.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Deployment$%s", local.name_prefix)]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.observability_settings.budget_alert_percentage
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = sort(tolist(var.observability_settings.cost_notification_emails))
  }
}

resource "aws_ce_anomaly_monitor" "services" {
  name              = "${local.name_prefix}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "services" {
  name      = "${local.name_prefix}-services"
  frequency = "DAILY"

  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.observability_settings.cost_anomaly_threshold_usd)]
    }
  }

  dynamic "subscriber" {
    for_each = var.observability_settings.cost_notification_emails

    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }
}

# =============================================================================
# Observability outputs
# =============================================================================
output "runtime_log_group_arns" {
  description = "KMS-encrypted runtime Log Group ARNs keyed by component."
  value       = { for component, log_group in aws_cloudwatch_log_group.runtime : component => log_group.arn }
}

output "operations_dashboard_name" {
  description = "Shared CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.environment.dashboard_name
}
