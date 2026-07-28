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
