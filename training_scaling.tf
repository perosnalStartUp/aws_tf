resource "aws_autoscaling_policy" "training_scale_out" {
  name                   = "${local.name_prefix}-training-scale-out"
  autoscaling_group_name = aws_autoscaling_group.training.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.training_scaling_settings.scale_out_adjustment
  cooldown               = var.training_scaling_settings.scale_out_cooldown_seconds
}

resource "aws_autoscaling_policy" "training_scale_in" {
  name                   = "${local.name_prefix}-training-scale-in"
  autoscaling_group_name = aws_autoscaling_group.training.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.training_scaling_settings.scale_in_adjustment
  cooldown               = var.training_scaling_settings.scale_in_cooldown_seconds
}

resource "aws_cloudwatch_metric_alarm" "training_scale_out" {
  alarm_name          = "${local.name_prefix}-training-backlog-scale-out"
  alarm_description   = "Scale out when visible jobs per InService worker exceed the reviewed threshold; backlog is used directly at zero workers."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.training_scaling_settings.scale_out_backlog_per_instance
  evaluation_periods  = var.training_scaling_settings.evaluation_periods
  datapoints_to_alarm = var.training_scaling_settings.datapoints_to_alarm
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_autoscaling_policy.training_scale_out.arn]

  metric_query {
    id          = "backlog_per_worker"
    expression  = "IF(in_service > 0, visible / in_service, visible)"
    label       = "Visible jobs per InService Training worker"
    return_data = true
  }

  metric_query {
    id          = "visible"
    return_data = false

    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        QueueName = aws_sqs_queue.training.name
      }
    }
  }

  metric_query {
    id          = "in_service"
    return_data = false

    metric {
      namespace   = "AWS/AutoScaling"
      metric_name = "GroupInServiceInstances"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.training.name
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "training_scale_in" {
  alarm_name          = "${local.name_prefix}-training-backlog-scale-in"
  alarm_description   = "Scale in only when reviewed backlog-per-worker conditions remain low; worker scale-in protection remains authoritative."
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = var.training_scaling_settings.scale_in_backlog_per_instance
  evaluation_periods  = var.training_scaling_settings.evaluation_periods
  datapoints_to_alarm = var.training_scaling_settings.datapoints_to_alarm
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_autoscaling_policy.training_scale_in.arn]

  metric_query {
    id          = "backlog_per_worker"
    expression  = "IF(in_service > 0, visible / in_service, visible)"
    label       = "Visible jobs per InService Training worker"
    return_data = true
  }

  metric_query {
    id          = "visible"
    return_data = false

    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        QueueName = aws_sqs_queue.training.name
      }
    }
  }

  metric_query {
    id          = "in_service"
    return_data = false

    metric {
      namespace   = "AWS/AutoScaling"
      metric_name = "GroupInServiceInstances"
      period      = var.training_scaling_settings.metric_period_seconds
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.training.name
      }
    }
  }
}
