output "database_address" {
  description = "Private RDS hostname for Backend."
  value       = aws_db_instance.postgres.address
}

output "database_name" {
  description = "PostgreSQL database name."
  value       = aws_db_instance.postgres.db_name
}

output "database_port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.postgres.port
}

output "database_master_secret_arn" {
  description = "ARN of the AWS-managed RDS master credential secret; no secret value is output."
  value       = one(aws_db_instance.postgres.master_user_secret).secret_arn
}
