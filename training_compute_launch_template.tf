locals {
  training_asg_name = "${local.name_prefix}-training"

  training_runtime_environment = {
    IMAGE_TRAINING_CODE_COMMIT                 = var.training_runtime_settings.image_training_code_commit
    TRAINING_AMI_ID                            = var.training_ami_id
    TRAINING_ARTIFACT_VERSION                  = var.training_runtime_settings.artifact_version
    TRAINING_ASG_NAME                          = local.training_asg_name
    TRAINING_AWS_REGION                        = var.aws_region
    TRAINING_BACKEND_BASE_URL                  = "https://${aws_route53_record.backend_public.fqdn}"
    TRAINING_BUCKET                            = aws_s3_bucket.product.bucket
    TRAINING_CALLBACK_MAX_ATTEMPTS             = tostring(var.training_runtime_settings.callback_max_attempts)
    TRAINING_CALLBACK_SECRET_ARN               = var.training_callback_secret_arn
    TRAINING_CALLBACK_SECRET_JSON_FIELD        = var.training_runtime_settings.callback_secret_json_field
    TRAINING_CODE_COMMIT                       = var.training_runtime_settings.code_commit
    TRAINING_CONTAINER_IMAGE_DIGEST            = var.training_runtime_settings.container_image_digest
    TRAINING_EVALUATION_MAX_LOSS               = tostring(var.training_runtime_settings.evaluation_max_loss)
    TRAINING_KMS_KEY_ARN                       = aws_kms_key.product.arn
    TRAINING_MAX_CHECKPOINT_BYTES              = tostring(var.training_runtime_settings.max_checkpoint_bytes)
    TRAINING_MAX_PROCESSED_DATASET_BYTES       = tostring(var.training_runtime_settings.max_processed_dataset_bytes)
    TRAINING_MAX_RAW_DATASET_BYTES             = tostring(var.training_runtime_settings.max_raw_dataset_bytes)
    TRAINING_MODEL_CACHE_ROOT                  = var.training_runtime_settings.model_cache_root
    TRAINING_QUEUE_URL                         = aws_sqs_queue.training.url
    TRAINING_VISIBILITY_MAX_FAILURES           = tostring(var.training_runtime_settings.visibility_max_failures)
    TRAINING_VISIBILITY_RENEW_INTERVAL_SECONDS = tostring(var.training_visibility_renew_interval_seconds)
    TRAINING_VISIBILITY_RETRY_INTERVAL_SECONDS = tostring(var.training_runtime_settings.visibility_retry_interval_seconds)
    TRAINING_VISIBILITY_TIMEOUT_SECONDS        = tostring(var.training_queue_visibility_timeout_seconds)
    TRAINING_WORKING_MAX_LORA_RANK             = tostring(var.training_runtime_settings.working_max_lora_rank)
    TRAINING_WORKSPACE_ROOT                    = var.training_runtime_settings.workspace_root
  }

  training_runtime_environment_file = join("\n", [
    for key in sort(keys(local.training_runtime_environment)) :
    "${key}=${jsonencode(local.training_runtime_environment[key])}"
  ])
}

resource "aws_launch_template" "training" {
  name_prefix            = "${local.name_prefix}-training-"
  description            = "Terraform-owned Training structure; release workflow owns AMI-only versions"
  image_id               = var.training_ami_id
  instance_type          = var.training_instance_type
  update_default_version = false

  iam_instance_profile {
    name = aws_iam_instance_profile.runtime["training"].name
  }

  vpc_security_group_ids = [aws_security_group.training.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.training_compute_settings.detailed_monitoring_enabled
  }

  block_device_mappings {
    device_name = var.training_compute_settings.root_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.training_compute_settings.root_volume_size_gib
      volume_type           = var.training_compute_settings.root_volume_type
    }
  }

  block_device_mappings {
    device_name = var.training_compute_settings.workspace_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.training_compute_settings.workspace_volume_size_gib
      volume_type           = var.training_compute_settings.workspace_volume_type
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/training_runtime_environment.sh.tftpl", {
    runtime_environment  = local.training_runtime_environment_file
    systemd_service_name = var.training_systemd_service_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = local.component_names.training
      Component = "training"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = "${local.component_names.training}-volume"
      Component = "training"
    }
  }

  tags = {
    Name      = "${local.name_prefix}-training-launch-template"
    Component = "training"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [image_id]
  }
}
