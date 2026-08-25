locals {
  backend_runtime_environment = {
    APP_ENVIRONMENT     = var.environment
    AWS_REGION          = var.aws_region
    DATABASE_HOST       = aws_db_instance.postgres.address
    DATABASE_NAME       = aws_db_instance.postgres.db_name
    DATABASE_PORT       = tostring(aws_db_instance.postgres.port)
    DATABASE_SECRET_ARN = one(aws_db_instance.postgres.master_user_secret).secret_arn
    PRODUCT_KMS_KEY_ARN = aws_kms_key.product.arn
    PRODUCT_S3_BUCKET   = aws_s3_bucket.product.bucket
    TRAINING_DLQ_URL    = aws_sqs_queue.training_dlq.url
    TRAINING_QUEUE_URL  = aws_sqs_queue.training.url
    WORKING_BASE_URL    = "${var.working_service_scheme}://${aws_route53_record.working_private.fqdn}:${var.working_service_port}"
    WORKING_SECRET_ARN  = var.working_auth_secret_arn
  }

  backend_runtime_environment_file = join("\n", [
    for key in sort(keys(local.backend_runtime_environment)) :
    "${key}=${jsonencode(local.backend_runtime_environment[key])}"
  ])
}

resource "aws_launch_template" "backend" {
  name_prefix            = "${local.name_prefix}-backend-"
  description            = "Terraform-owned Backend structure; release workflow owns AMI-only versions"
  image_id               = var.backend_ami_id
  instance_type          = var.backend_instance_type
  update_default_version = false

  iam_instance_profile {
    name = aws_iam_instance_profile.runtime["backend"].name
  }

  vpc_security_group_ids = [aws_security_group.backend.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.backend_compute_settings.detailed_monitoring_enabled
  }

  block_device_mappings {
    device_name = var.backend_compute_settings.root_device_name

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.backend_compute_settings.root_volume_size_gib
      volume_type           = var.backend_compute_settings.root_volume_type
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/backend_runtime_environment.sh.tftpl", {
    runtime_environment  = local.backend_runtime_environment_file
    systemd_service_name = var.backend_systemd_service_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name      = local.component_names.backend
      Component = "backend"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = "${local.component_names.backend}-root"
      Component = "backend"
    }
  }

  tags = {
    Name      = "${local.name_prefix}-backend-launch-template"
    Component = "backend"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [image_id]
  }
}
