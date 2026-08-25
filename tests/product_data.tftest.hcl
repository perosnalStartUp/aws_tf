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
  observability_settings = {
    log_retention_days                = 30
    kms_deletion_window_days          = 30
    flow_log_traffic_type             = "ALL"
    alarm_action_arns                 = ["arn:aws:sns:us-east-1:123456789012:test-alerts"]
    queue_visible_messages_threshold  = 10
    queue_oldest_message_age_seconds  = 900
    dlq_visible_messages_threshold    = 1
    backend_unhealthy_hosts_threshold = 1
    backend_5xx_threshold             = 5
    backend_latency_seconds_threshold = 2
    rds_cpu_percentage_threshold      = 80
    rds_free_storage_bytes_threshold  = 1073741824
    working_status_failures_threshold = 1
    nat_error_port_threshold          = 1
    nat_packet_drop_threshold         = 100
    alarm_period_seconds              = 60
    alarm_evaluation_periods          = 2
    budget_limit_usd                  = 100
    budget_alert_percentage           = 80
    cost_anomaly_threshold_usd        = 20
    cost_notification_emails          = ["owner@example.com"]
  }
  backend_instance_type        = "t3.small"
  backend_systemd_service_name = "personal-lora-backend.service"
  backend_compute_settings = {
    root_device_name            = "/dev/sda1"
    root_volume_size_gib        = 20
    root_volume_type            = "gp3"
    detailed_monitoring_enabled = false
    health_check_grace_seconds  = 300
    default_instance_warmup     = 300
  }
  backend_target_health = {
    path                         = "/health"
    matcher                      = "200"
    interval_seconds             = 30
    timeout_seconds              = 5
    healthy_threshold            = 2
    unhealthy_threshold          = 2
    deregistration_delay_seconds = 30
  }
  backend_edge = {
    public_domain_name    = "api.test.example.com"
    public_hosted_zone_id = "ZTEST123"
    certificate_arn       = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
    ssl_policy            = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    deletion_protection   = true
    idle_timeout_seconds  = 60
  }
  backend_release_preferences = {
    min_healthy_percentage = 90
    max_healthy_percentage = 110
    instance_warmup        = 300
    auto_rollback          = true
    skip_matching          = true
  }
  working_instance_type           = "g5.xlarge"
  working_subnet_key              = "private_app_a"
  working_private_dns_name        = "working.test.internal"
  working_private_dns_ttl_seconds = 30
  working_service_scheme          = "http"
  working_systemd_service_name    = "personal-lora-working.service"
  working_compute_settings = {
    root_volume_size_gib        = 100
    root_volume_type            = "gp3"
    cache_device_name           = "/dev/sdf"
    cache_volume_size_gib       = 200
    cache_volume_type           = "gp3"
    detailed_monitoring_enabled = false
  }
  working_runtime_settings = {
    adapter_s3_prefix        = "adapters"
    model_manifest_s3_key    = "models/w0/model-manifest.json"
    vllm_internal_base_url   = "http://127.0.0.1:8000"
    auth_mode                = "api-key"
    contract_root            = "/opt/personal-lora/contracts/w0"
    cache_root               = "/var/lib/personal-lora/cache"
    max_lora_rank            = 64
    max_manifest_bytes       = 1048576
    max_artifact_bytes       = 1073741824
    max_cache_bytes          = 2147483648
    max_output_tokens        = 4096
    request_concurrency      = 1
    request_queue_limit      = 4
    load_concurrency         = 1
    download_timeout_seconds = 300
    vllm_timeout_seconds     = 300
    disk_fatal_free_bytes    = 1073741824
  }
  training_instance_type        = "g5.xlarge"
  training_systemd_service_name = "personal-lora-training.service"
  training_compute_settings = {
    root_device_name            = "/dev/sda1"
    root_volume_size_gib        = 100
    root_volume_type            = "gp3"
    workspace_device_name       = "/dev/sdf"
    workspace_volume_size_gib   = 200
    workspace_volume_type       = "gp3"
    detailed_monitoring_enabled = false
    default_instance_warmup     = 600
  }
  training_lifecycle_settings = {
    hook_name                 = "training-termination"
    heartbeat_timeout_seconds = 3600
    default_result            = "CONTINUE"
  }
  training_runtime_settings = {
    callback_secret_json_field        = "token"
    working_max_lora_rank             = 64
    evaluation_max_loss               = 10
    artifact_version                  = "test-v1"
    code_commit                       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    image_training_code_commit        = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    container_image_digest            = "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    workspace_root                    = "/var/lib/personal-lora/training"
    model_cache_root                  = "/var/lib/personal-lora/models"
    visibility_retry_interval_seconds = 30
    visibility_max_failures           = 3
    max_raw_dataset_bytes             = 104857600
    max_processed_dataset_bytes       = 104857600
    max_checkpoint_bytes              = 1073741824
    callback_max_attempts             = 5
  }
  training_scaling_settings = {
    metric_period_seconds          = 60
    evaluation_periods             = 2
    datapoints_to_alarm            = 2
    scale_out_backlog_per_instance = 1
    scale_in_backlog_per_instance  = 0
    scale_out_adjustment           = 1
    scale_in_adjustment            = -1
    scale_out_cooldown_seconds     = 300
    scale_in_cooldown_seconds      = 300
  }

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
