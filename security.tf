# =============================================================================
# Security-group inputs
# =============================================================================
variable "backend_application_port" {
  type        = number
  description = "Backend application port accepted only from the ALB security group."
  nullable    = false

  validation {
    condition     = var.backend_application_port >= 1024 && var.backend_application_port <= 65535
    error_message = "backend_application_port must be an unprivileged TCP port from 1024 through 65535."
  }
}

variable "working_service_port" {
  type        = number
  description = "Working inference service port accepted only from the Backend security group."
  nullable    = false

  validation {
    condition     = var.working_service_port >= 1024 && var.working_service_port <= 65535
    error_message = "working_service_port must be an unprivileged TCP port from 1024 through 65535."
  }
}

variable "database_port" {
  type        = number
  description = "PostgreSQL port accepted only from the Backend security group."
  nullable    = false

  validation {
    condition     = var.database_port >= 1024 && var.database_port <= 65535
    error_message = "database_port must be an unprivileged TCP port from 1024 through 65535."
  }
}

# =============================================================================
# Security groups
# =============================================================================
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Internet-facing ALB ingress and Backend-only egress"
  vpc_id      = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = "${local.name_prefix}-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "backend" {
  name_prefix = "${local.name_prefix}-backend-"
  description = "Backend ingress from ALB and scoped service egress"
  vpc_id      = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = local.component_names.backend
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "working" {
  name_prefix = "${local.name_prefix}-working-"
  description = "Working ingress from Backend only"
  vpc_id      = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = local.component_names.working
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "training" {
  name_prefix = "${local.name_prefix}-training-"
  description = "Training has no application ingress and HTTPS-only egress"
  vpc_id      = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = local.component_names.training
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-database-"
  description = "PostgreSQL ingress from Backend only"
  vpc_id      = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = "${local.name_prefix}-database"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "interface_endpoints" {
  name_prefix = "${local.name_prefix}-endpoints-"
  description = "Reserved HTTPS ingress for future VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = "${local.name_prefix}-interface-endpoints"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Ingress rules
# =============================================================================
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

# =============================================================================
# Egress rules
# =============================================================================
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

# =============================================================================
# Security outputs
# =============================================================================
output "security_group_ids" {
  description = "Security group IDs keyed by component boundary."
  value = {
    alb                 = aws_security_group.alb.id
    backend             = aws_security_group.backend.id
    working             = aws_security_group.working.id
    training            = aws_security_group.training.id
    database            = aws_security_group.database.id
    interface_endpoints = aws_security_group.interface_endpoints.id
  }
}
