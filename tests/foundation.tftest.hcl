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

  assert {
    condition     = local.backend_runtime_role.name != local.backend_release_role.name
    error_message = "Backend runtime and release authorities must remain separate roles."
  }

}

run "rejects_oidc_subject_from_another_organization" {
  command = plan

  variables {
    github_oidc_subjects = {
      terraform        = ["repo:other-org/terraform:environment:test"]
      backend_packer   = ["repo:example-org/small_backend:ref:refs/heads/main"]
      backend_release  = ["repo:example-org/small_backend:environment:test"]
      training_packer  = ["repo:example-org/gpu_ec2:ref:refs/heads/main"]
      training_release = ["repo:example-org/gpu_ec2:environment:test"]
    }
  }

  expect_failures = [
    var.github_oidc_subjects,
  ]
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
