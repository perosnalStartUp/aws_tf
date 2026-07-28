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
