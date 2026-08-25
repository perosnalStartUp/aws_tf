output "working_instance_id" {
  description = "Single Working V0 EC2 instance ID."
  value       = aws_instance.working.id
}

output "working_private_dns_name" {
  description = "Stable private Working V0 DNS name consumed by Backend."
  value       = aws_route53_record.working_private.fqdn
}

output "working_private_url" {
  description = "Private Working V0 base URL; no credential value is included."
  value       = "${var.working_service_scheme}://${aws_route53_record.working_private.fqdn}:${var.working_service_port}"
}
