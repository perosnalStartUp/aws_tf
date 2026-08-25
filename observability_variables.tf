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
