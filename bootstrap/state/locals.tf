locals {
  required_tags = {
    Project     = var.project_name
    Environment = "shared"
    Component   = "terraform-state"
    Owner       = trimspace(var.owner)
    CostCenter  = trimspace(var.cost_center)
    ManagedBy   = "Terraform"
  }

  common_tags = merge(var.extra_tags, local.required_tags)

  state_object_arns = [
    "${aws_s3_bucket.state.arn}/*",
  ]
}
