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

  assert {
    condition     = aws_route53_zone.private.name == "test.internal"
    error_message = "The private zone must use the explicit environment input."
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

run "rejects_invalid_private_zone_name" {
  command = plan

  variables {
    private_zone_name = "INVALID_ZONE"
  }

  expect_failures = [
    var.private_zone_name,
  ]
}
