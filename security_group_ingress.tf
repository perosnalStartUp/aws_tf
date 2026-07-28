resource "aws_vpc_security_group_ingress_rule" "alb_http_redirect" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP is accepted only for redirect to HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTPS application entry"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Backend application traffic from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.backend_application_port
  to_port                      = var.backend_application_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "working_from_backend" {
  security_group_id            = aws_security_group.working.id
  description                  = "Private Working inference traffic from Backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = var.working_service_port
  to_port                      = var.working_service_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "database_from_backend" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL traffic from Backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"
}

locals {
  interface_endpoint_source_security_groups = {
    backend  = aws_security_group.backend.id
    working  = aws_security_group.working.id
    training = aws_security_group.training.id
  }
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoint_https" {
  for_each = local.interface_endpoint_source_security_groups

  security_group_id            = aws_security_group.interface_endpoints.id
  description                  = "HTTPS from ${each.key} to future interface endpoints"
  referenced_security_group_id = each.value
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
