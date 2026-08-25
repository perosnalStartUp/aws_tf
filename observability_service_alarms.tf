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
