mock_provider "aws" {}

variables {
  project_name   = "personal-lora"
  environment    = "test"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"
  owner          = "local-test"
  cost_center    = "N/A"

  vpc_cidr           = "10.42.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  subnet_cidrs = {
    public_a      = "10.42.0.0/24"
    public_b      = "10.42.1.0/24"
    private_app_a = "10.42.10.0/24"
    private_app_b = "10.42.11.0/24"
    private_db_a  = "10.42.20.0/24"
    private_db_b  = "10.42.21.0/24"
  }
  enable_ipv6 = false

  backend_capacity = {
    min     = 1
    desired = 1
    max     = 2
  }
  training_capacity = {
    min     = 0
    desired = 0
    max     = 1
  }

  backend_ami_id  = "ami-0123456789abcdef0"
  working_ami_id  = "ami-0123456789abcdef1"
  training_ami_id = "ami-0123456789abcdef2"

  private_zone_name        = "test.internal"
  backend_application_port = 8080
  working_service_port     = 8188
  database_port            = 5432

  product_bucket_name                  = "personal-lora-test-data"
  product_kms_key_deletion_window_days = 30
  product_s3_component_access = {
    backend = {
      read_prefixes  = ["datasets", "adapters"]
      write_prefixes = ["jobs"]
    }
    working = {
      read_prefixes  = ["adapters"]
      write_prefixes = []
    }
    training = {
      read_prefixes  = ["datasets"]
      write_prefixes = ["adapters", "checkpoints", "logs"]
    }
  }
}

run "plans_reference_based_security_group_graph" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http_redirect.from_port == 80
    error_message = "ALB port 80 must remain available only for the later redirect listener."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_https.from_port == 443
    error_message = "ALB HTTPS ingress must remain on port 443."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.backend_from_alb.from_port == 8080
    error_message = "Backend ingress must use the explicit application port."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.working_from_backend.from_port == 8188
    error_message = "Working ingress must use the explicit service port."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.database_from_backend.from_port == 5432
    error_message = "Database ingress must use the explicit PostgreSQL port."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.interface_endpoint_https) == 3
    error_message = "Future interface endpoint HTTPS ingress must be scoped to the three application groups."
  }
}

run "rejects_privileged_working_port" {
  command = plan

  variables {
    working_service_port = 443
  }

  expect_failures = [
    var.working_service_port,
  ]
}
