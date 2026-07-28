output "workflow_role_arns" {
  description = "OIDC workflow role ARNs keyed by deployment/build/release boundary."
  value       = { for name, role in aws_iam_role.workflow : name => role.arn }
}

output "runtime_role_arns" {
  description = "Runtime IAM role ARNs keyed by component."
  value       = { for name, role in aws_iam_role.runtime : name => role.arn }
}

output "runtime_instance_profile_names" {
  description = "Runtime instance profile names keyed by component."
  value       = { for name, profile in aws_iam_instance_profile.runtime : name => profile.name }
}
