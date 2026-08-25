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
