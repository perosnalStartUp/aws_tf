resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB health and application traffic to Backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = var.backend_application_port
  to_port                      = var.backend_application_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_to_working" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Backend to private Working inference service"
  referenced_security_group_id = aws_security_group.working.id
  from_port                    = var.working_service_port
  to_port                      = var.working_service_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_to_database" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Backend to private PostgreSQL"
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"
}

# Accepted P1 boundary: AWS/public HTTPS APIs use NAT until approved interface endpoints exist.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "backend_https" {
  security_group_id = aws_security_group.backend.id
  description       = "HTTPS to AWS/public services through endpoint or NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Accepted P1 boundary: SSM/logs/secrets use NAT while S3 routing is moved by the Gateway Endpoint.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "working_https" {
  security_group_id = aws_security_group.working.id
  description       = "HTTPS to S3/AWS services through endpoint or NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Accepted P1 boundary: SQS and the public Backend callback require HTTPS through the single NAT.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "training_https" {
  security_group_id = aws_security_group.training.id
  description       = "HTTPS to S3/SQS and public Backend callback through NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
