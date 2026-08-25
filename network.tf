# =============================================================================
# Private DNS inputs
# =============================================================================
variable "private_zone_name" {
  type        = string
  description = "Private Route53 zone associated with the environment VPC."
  nullable    = false

  validation {
    condition = (
      length(var.private_zone_name) <= 253 &&
      can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$", var.private_zone_name))
    )
    error_message = "private_zone_name must be a valid lowercase multi-label DNS name without a trailing dot."
  }
}

# =============================================================================
# Subnet and routing locals
# =============================================================================
locals {
  network_subnets = {
    public_a = {
      availability_zone = var.availability_zones[0]
      cidr_block        = var.subnet_cidrs.public_a
      tier              = "public"
    }
    public_b = {
      availability_zone = var.availability_zones[1]
      cidr_block        = var.subnet_cidrs.public_b
      tier              = "public"
    }
    private_app_a = {
      availability_zone = var.availability_zones[0]
      cidr_block        = var.subnet_cidrs.private_app_a
      tier              = "private-application"
    }
    private_app_b = {
      availability_zone = var.availability_zones[1]
      cidr_block        = var.subnet_cidrs.private_app_b
      tier              = "private-application"
    }
    private_db_a = {
      availability_zone = var.availability_zones[0]
      cidr_block        = var.subnet_cidrs.private_db_a
      tier              = "private-database"
    }
    private_db_b = {
      availability_zone = var.availability_zones[1]
      cidr_block        = var.subnet_cidrs.private_db_b
      tier              = "private-database"
    }
  }

  public_subnets = {
    for subnet_name, subnet in local.network_subnets :
    subnet_name => subnet if subnet.tier == "public"
  }

  private_application_subnets = {
    for subnet_name, subnet in local.network_subnets :
    subnet_name => subnet if subnet.tier == "private-application"
  }

  private_database_subnets = {
    for subnet_name, subnet in local.network_subnets :
    subnet_name => subnet if subnet.tier == "private-database"
  }
}

# =============================================================================
# VPC and subnets
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
    Tier = each.value.tier
  }
}

resource "aws_subnet" "private_application" {
  for_each = local.private_application_subnets

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
    Tier = each.value.tier
  }
}

resource "aws_subnet" "private_database" {
  for_each = local.private_database_subnets

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
    Tier = each.value.tier
  }
}

check "ipv6_requires_completed_subnet_design" {
  assert {
    condition     = !var.enable_ipv6
    error_message = "IPv6 must remain disabled until IPv6 subnet allocation, routing, and security controls are explicitly designed."
  }
}

# =============================================================================
# Internet gateway and public routing
# =============================================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-public"
    Tier = "public"
  }
}

resource "aws_route" "public_ipv4_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# NAT gateway and private application routing
# =============================================================================
resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-a"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public["public_a"].id

  tags = {
    Name = "${local.name_prefix}-nat-a"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private_application" {
  for_each = local.private_application_subnets

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
    Tier = "private-application"
  }
}

resource "aws_route" "private_application_ipv4_default" {
  for_each = aws_route_table.private_application

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.a.id
}

resource "aws_route_table_association" "private_application" {
  for_each = aws_subnet.private_application

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_application[each.key].id
}

# =============================================================================
# Private database routing
# =============================================================================
resource "aws_route_table" "private_database" {
  for_each = local.private_database_subnets

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-${replace(each.key, "_", "-")}"
    Tier = "private-database"
  }
}

resource "aws_route_table_association" "private_database" {
  for_each = aws_subnet.private_database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_database[each.key].id
}

# =============================================================================
# S3 Gateway Endpoint
# =============================================================================
locals {
  s3_gateway_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ApprovedProductBucketsOnly"
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "s3:DeleteObject",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject",
      ]
      Resource = [
        aws_s3_bucket.product.arn,
        "${aws_s3_bucket.product.arn}/*",
      ]
    }]
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private_application : route_table.id]
  policy            = local.s3_gateway_endpoint_policy

  tags = {
    Name = "${local.name_prefix}-s3"
  }
}

# =============================================================================
# Route 53 private hosted zone
# =============================================================================
resource "aws_route53_zone" "private" {
  name = var.private_zone_name

  vpc {
    vpc_id     = aws_vpc.main.id
    vpc_region = var.aws_region
  }

  tags = {
    Name = "${local.name_prefix}-private-zone"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Network outputs
# =============================================================================
output "vpc_id" {
  description = "ID of the environment VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by semantic subnet name."
  value       = { for name, subnet in aws_subnet.public : name => subnet.id }
}

output "private_application_subnet_ids" {
  description = "Private application subnet IDs keyed by semantic subnet name."
  value       = { for name, subnet in aws_subnet.private_application : name => subnet.id }
}

output "private_database_subnet_ids" {
  description = "Private database subnet IDs keyed by semantic subnet name."
  value       = { for name, subnet in aws_subnet.private_database : name => subnet.id }
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_application_route_table_ids" {
  description = "Private application route table IDs keyed by semantic subnet name."
  value       = { for name, route_table in aws_route_table.private_application : name => route_table.id }
}

output "private_database_route_table_ids" {
  description = "Private database route table IDs keyed by semantic subnet name."
  value       = { for name, route_table in aws_route_table.private_database : name => route_table.id }
}

output "nat_gateway_eip" {
  description = "Public EIP used by the single AZ-A NAT Gateway."
  value       = aws_eip.nat_a.public_ip
}

output "private_zone_id" {
  description = "ID of the VPC-associated private Route53 zone."
  value       = aws_route53_zone.private.zone_id
}
