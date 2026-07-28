mock_provider "aws" {}

variables {
  project_name   = "personal-lora"
  environment    = "test"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"
  owner          = "local-test"
  cost_center    = "N/A"
  extra_tags = {
    Purpose = "terraform-test"
  }

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

run "accepts_valid_foundation_inputs" {
  command = plan

  assert {
    condition     = local.name_prefix == "personal-lora-test"
    error_message = "The deterministic name prefix is incorrect."
  }

  assert {
    condition     = local.component_names.working == "personal-lora-test-working"
    error_message = "The Working component name is incorrect."
  }

  assert {
    condition     = local.common_tags.ManagedBy == "Terraform"
    error_message = "Required governance tags must override extra tags."
  }
}

run "rejects_invalid_account_id" {
  command = plan

  variables {
    aws_account_id = "test-account"
  }

  expect_failures = [
    var.aws_account_id,
  ]
}

run "rejects_duplicate_availability_zones" {
  command = plan

  variables {
    availability_zones = ["us-east-1a", "us-east-1a"]
  }

  expect_failures = [
    var.availability_zones,
  ]
}

run "rejects_subnet_outside_vpc" {
  command = plan

  variables {
    subnet_cidrs = {
      public_a      = "10.42.0.0/24"
      public_b      = "10.42.1.0/24"
      private_app_a = "10.42.10.0/24"
      private_app_b = "10.42.11.0/24"
      private_db_a  = "10.42.20.0/24"
      private_db_b  = "10.43.21.0/24"
    }
  }

  expect_failures = [
    check.subnet_cidrs_within_vpc,
  ]
}

run "rejects_overlapping_subnets" {
  command = plan

  variables {
    subnet_cidrs = {
      public_a      = "10.42.0.0/24"
      public_b      = "10.42.0.128/25"
      private_app_a = "10.42.10.0/24"
      private_app_b = "10.42.11.0/24"
      private_db_a  = "10.42.20.0/24"
      private_db_b  = "10.42.21.0/24"
    }
  }

  expect_failures = [
    check.subnet_cidrs_do_not_overlap,
  ]
}

run "rejects_backend_desired_capacity_other_than_one" {
  command = plan

  variables {
    backend_capacity = {
      min     = 0
      desired = 2
      max     = 2
    }
  }

  expect_failures = [
    check.backend_capacity_bounds,
  ]
}

run "rejects_training_nonzero_initial_capacity" {
  command = plan

  variables {
    training_capacity = {
      min     = 0
      desired = 1
      max     = 1
    }
  }

  expect_failures = [
    check.training_capacity_bounds,
  ]
}

run "rejects_invalid_ami_id" {
  command = plan

  variables {
    working_ami_id = "latest-working"
  }

  expect_failures = [
    var.working_ami_id,
  ]
}

run "rejects_public_application_ips" {
  command = plan

  variables {
    application_public_ip_assignment = {
      backend  = true
      working  = false
      training = false
    }
  }

  expect_failures = [
    var.application_public_ip_assignment,
  ]
}
