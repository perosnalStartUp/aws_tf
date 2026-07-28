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
