resource "aws_autoscaling_group" "training" {
  name                    = local.training_asg_name
  min_size                = var.training_capacity.min
  desired_capacity        = var.training_capacity.desired
  max_size                = var.training_capacity.max
  vpc_zone_identifier     = [for subnet in aws_subnet.private_application : subnet.id]
  health_check_type       = "EC2"
  default_instance_warmup = var.training_compute_settings.default_instance_warmup
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
  ]

  launch_template {
    id      = aws_launch_template.training.id
    version = "$Default"
  }

  tag {
    key                 = "Name"
    value               = local.component_names.training
    propagate_at_launch = true
  }

  tag {
    key                 = "Component"
    value               = "training"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_lifecycle_hook" "training_termination" {
  name                   = var.training_lifecycle_settings.hook_name
  autoscaling_group_name = aws_autoscaling_group.training.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = var.training_lifecycle_settings.heartbeat_timeout_seconds
  default_result         = var.training_lifecycle_settings.default_result
}
