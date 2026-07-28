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

  training_queue_visibility_timeout_seconds  = 600
  training_visibility_renew_interval_seconds = 120
  training_queue_message_retention_seconds   = 345600
  training_dlq_message_retention_seconds     = 1209600
  training_queue_receive_wait_time_seconds   = 20
  training_queue_max_receive_count           = 5
  training_queue_kms_deletion_window_days    = 30

  github_organization = "example-org"
  github_repositories = {
    terraform = "terraform"
    backend   = "small_backend"
    gpu       = "gpu_ec2"
  }
  github_oidc_subjects = {
    terraform        = ["repo:example-org/terraform:environment:test"]
    backend_packer   = ["repo:example-org/small_backend:ref:refs/heads/main"]
    backend_release  = ["repo:example-org/small_backend:environment:test"]
    training_packer  = ["repo:example-org/gpu_ec2:ref:refs/heads/main"]
    training_release = ["repo:example-org/gpu_ec2:environment:test"]
  }
  working_auth_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:working-auth-AbCdEf"
  training_callback_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:training-callback-AbCdEf"
  runtime_log_group_arns = {
    backend  = ["arn:aws:logs:us-east-1:123456789012:log-group:/personal-lora/test/backend:*"]
    working  = ["arn:aws:logs:us-east-1:123456789012:log-group:/personal-lora/test/working:*"]
    training = ["arn:aws:logs:us-east-1:123456789012:log-group:/personal-lora/test/training:*"]
  }
  backend_launch_template_name  = "personal-lora-test-backend"
  backend_asg_name              = "personal-lora-test-backend"
  training_launch_template_name = "personal-lora-test-training"
  training_asg_name             = "personal-lora-test-training"

  database_name                                = "personal_lora"
  database_master_username                     = "loraadmin"
  database_engine_version                      = "16.3"
  database_parameter_group_family              = "postgres16"
  database_instance_class                      = "db.t4g.micro"
  database_allocated_storage_gib               = 20
  database_max_allocated_storage_gib           = 100
  database_storage_type                        = "gp3"
  database_multi_az                            = false
  database_backup_retention_days               = 7
  database_backup_window                       = "03:00-04:00"
  database_maintenance_window                  = "sun:04:00-sun:05:00"
  database_deletion_protection                 = true
  database_skip_final_snapshot                 = false
  database_final_snapshot_identifier           = "personal-lora-test-final"
  database_enabled_log_exports                 = ["postgresql"]
  database_monitoring_interval_seconds         = 0
  database_performance_insights_enabled        = false
  database_performance_insights_retention_days = 7
  database_kms_deletion_window_days            = 30
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

  assert {
    condition     = aws_sqs_queue.training.visibility_timeout_seconds == 600
    error_message = "Training queue visibility must use the reviewed runtime timing."
  }

  assert {
    condition     = !aws_db_instance.postgres.publicly_accessible
    error_message = "PostgreSQL must remain private."
  }

  assert {
    condition     = aws_db_instance.postgres.manage_master_user_password
    error_message = "RDS must keep the master password in its AWS-managed secret."
  }
}

run "rejects_unsafe_training_visibility_margin" {
  command = plan

  variables {
    training_queue_visibility_timeout_seconds  = 200
    training_visibility_renew_interval_seconds = 120
  }

  expect_failures = [
    check.training_visibility_renewal_margin,
  ]
}

run "rejects_missing_required_final_snapshot_identifier" {
  command = plan

  variables {
    database_skip_final_snapshot       = false
    database_final_snapshot_identifier = null
  }

  expect_failures = [
    check.database_final_snapshot_contract,
  ]
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
