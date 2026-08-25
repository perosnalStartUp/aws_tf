output "runtime_log_group_arns" {
  description = "KMS-encrypted runtime Log Group ARNs keyed by component."
  value       = { for component, log_group in aws_cloudwatch_log_group.runtime : component => log_group.arn }
}

output "operations_dashboard_name" {
  description = "Shared CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.environment.dashboard_name
}
