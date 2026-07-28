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
