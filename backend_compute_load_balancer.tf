resource "aws_lb_target_group" "backend" {
  name                 = "${local.name_prefix}-backend"
  port                 = var.backend_application_port
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = var.backend_target_health.deregistration_delay_seconds

  health_check {
    enabled             = true
    path                = var.backend_target_health.path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = var.backend_target_health.matcher
    interval            = var.backend_target_health.interval_seconds
    timeout             = var.backend_target_health.timeout_seconds
    healthy_threshold   = var.backend_target_health.healthy_threshold
    unhealthy_threshold = var.backend_target_health.unhealthy_threshold
  }

}

# Confirmed product boundary: this is the sole public application entry and forwards only to the
# private Backend target group; Working, Training, RDS, and application EC2 remain private.
#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "backend" {
  name                       = "${local.name_prefix}-backend"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.backend_edge.deletion_protection
  idle_timeout               = var.backend_edge.idle_timeout_seconds

  tags = {
    Name      = "${local.name_prefix}-backend"
    Component = "backend"
  }
}
