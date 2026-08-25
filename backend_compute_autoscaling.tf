resource "aws_autoscaling_group" "backend" {
  name                      = "${local.name_prefix}-backend"
  min_size                  = var.backend_capacity.min
  desired_capacity          = var.backend_capacity.desired
  max_size                  = var.backend_capacity.max
  vpc_zone_identifier       = [for subnet in aws_subnet.private_application : subnet.id]
  target_group_arns         = [aws_lb_target_group.backend.arn]
  health_check_type         = "ELB"
  health_check_grace_period = var.backend_compute_settings.health_check_grace_seconds
  default_instance_warmup   = var.backend_compute_settings.default_instance_warmup
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
  ]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Default"
  }

  instance_maintenance_policy {
    min_healthy_percentage = var.backend_release_preferences.min_healthy_percentage
    max_healthy_percentage = var.backend_release_preferences.max_healthy_percentage
  }

  tag {
    key                 = "Name"
    value               = local.component_names.backend
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = "backend"
    propagate_at_launch = true
  }
}
