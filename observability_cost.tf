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
