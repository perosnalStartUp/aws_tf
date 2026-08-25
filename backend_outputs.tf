output "backend_launch_template_id" {
  description = "Terraform-owned Backend Launch Template ID."
  value       = aws_launch_template.backend.id
}

output "backend_asg_name" {
  description = "Backend Auto Scaling Group name."
  value       = aws_autoscaling_group.backend.name
}

output "backend_public_url" {
  description = "Public HTTPS base URL used by Frontend and Training callbacks."
  value       = "https://${aws_route53_record.backend_public.fqdn}"
}

output "backend_alb_arn" {
  description = "Backend internet-facing ALB ARN."
  value       = aws_lb.backend.arn
}

output "backend_release_preferences" {
  description = "Reviewed preferences for the future Backend release workflow; no refresh is started by Terraform."
  value       = var.backend_release_preferences
}
