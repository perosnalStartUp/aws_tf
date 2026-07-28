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

  s3_gateway_endpoint_bucket_arns = [
    "arn:aws:s3:::personal-lora-test-data",
  ]
}

run "plans_two_az_network_and_single_nat" {
  command = plan

  assert {
    condition     = aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "The VPC must enable DNS support and DNS hostnames."
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "The network must contain two public subnets."
  }

  assert {
    condition     = length(aws_subnet.private_application) == 2
    error_message = "The network must contain two private application subnets."
  }

  assert {
    condition     = length(aws_subnet.private_database) == 2
    error_message = "The network must contain two private database subnets."
  }

  assert {
    condition = alltrue([
      for subnet in values(aws_subnet.public) : !subnet.map_public_ip_on_launch
    ])
    error_message = "Public-tier subnets must not automatically assign public IP addresses."
  }

  assert {
    condition     = length(aws_route.private_application_ipv4_default) == 2
    error_message = "Both private application route tables must use the single NAT Gateway."
  }

  assert {
    condition     = aws_subnet.public["public_a"].availability_zone == var.availability_zones[0]
    error_message = "The public_a subnet used by the single NAT Gateway must remain in AZ-A."
  }

  assert {
    condition     = aws_nat_gateway.a.tags.Name == "personal-lora-test-nat-a"
    error_message = "The design must contain exactly the named AZ-A NAT Gateway resource."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "S3 must use a free Gateway Endpoint."
  }
}

run "rejects_ipv6_without_complete_design" {
  command = plan

  variables {
    enable_ipv6 = true
  }

  expect_failures = [
    check.ipv6_requires_completed_subnet_design,
  ]
}

run "rejects_empty_s3_endpoint_scope" {
  command = plan

  variables {
    s3_gateway_endpoint_bucket_arns = []
  }

  expect_failures = [
    var.s3_gateway_endpoint_bucket_arns,
  ]
}
