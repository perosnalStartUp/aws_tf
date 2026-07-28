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
