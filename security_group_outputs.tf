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
