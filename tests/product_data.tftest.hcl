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

run "plans_encrypted_private_product_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket.product.bucket == "personal-lora-test-data"
    error_message = "The product bucket must use the explicit input name."
  }

  assert {
    condition     = aws_s3_bucket_versioning.product.versioning_configuration[0].status == "Enabled"
    error_message = "Product bucket versioning must remain enabled."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.product.restrict_public_buckets
    error_message = "Product bucket public access must remain fully blocked."
  }

  assert {
    condition     = aws_kms_key.product.enable_key_rotation
    error_message = "The Terraform-managed product KMS key must keep rotation enabled."
  }

  assert {
    condition     = length(local.product_s3_component_policy_json) == 3
    error_message = "Backend, Working, and Training must each receive a scoped policy document."
  }
}

run "rejects_missing_component_access" {
  command = plan

  variables {
    product_s3_component_access = {
      backend = {
        read_prefixes  = ["datasets"]
        write_prefixes = ["jobs"]
      }
      training = {
        read_prefixes  = ["datasets"]
        write_prefixes = ["checkpoints"]
      }
    }
  }

  expect_failures = [
    var.product_s3_component_access,
  ]
}

run "rejects_wildcard_prefix" {
  command = plan

  variables {
    product_s3_component_access = {
      backend = {
        read_prefixes  = ["datasets/*"]
        write_prefixes = ["jobs"]
      }
      working = {
        read_prefixes  = ["adapters"]
        write_prefixes = []
      }
      training = {
        read_prefixes  = ["datasets"]
        write_prefixes = ["checkpoints"]
      }
    }
  }

  expect_failures = [
    var.product_s3_component_access,
  ]
}
