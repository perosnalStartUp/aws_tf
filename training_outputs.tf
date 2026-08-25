output "training_launch_template_id" {
  description = "Terraform-owned Training Launch Template ID."
  value       = aws_launch_template.training.id
}

output "training_asg_name" {
  description = "Training Auto Scaling Group name."
  value       = aws_autoscaling_group.training.name
}

output "training_lifecycle_hook_name" {
  description = "Termination lifecycle hook name consumed by the Training runtime."
  value       = aws_autoscaling_lifecycle_hook.training_termination.name
}

output "training_callback_base_url" {
  description = "Public Backend HTTPS base URL reached by private Training workers through NAT."
  value       = "https://${aws_route53_record.backend_public.fqdn}"
}
