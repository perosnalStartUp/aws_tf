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
