locals {
  working_runtime_environment = {
    ADAPTER_S3_BUCKET                = aws_s3_bucket.product.bucket
    ADAPTER_S3_PREFIX                = var.working_runtime_settings.adapter_s3_prefix
    AWS_REGION                       = var.aws_region
    MODEL_MANIFEST_S3_URI            = "s3://${aws_s3_bucket.product.bucket}/${var.working_runtime_settings.model_manifest_s3_key}"
    VLLM_INTERNAL_BASE_URL           = var.working_runtime_settings.vllm_internal_base_url
    WORKING_API_KEY_SECRET_ID        = var.working_auth_secret_arn
    WORKING_AUTH_MODE                = var.working_runtime_settings.auth_mode
    WORKING_CACHE_ROOT               = var.working_runtime_settings.cache_root
    WORKING_DISK_FATAL_FREE_BYTES    = tostring(var.working_runtime_settings.disk_fatal_free_bytes)
    WORKING_DOWNLOAD_TIMEOUT_SECONDS = tostring(var.working_runtime_settings.download_timeout_seconds)
    WORKING_LOAD_CONCURRENCY         = tostring(var.working_runtime_settings.load_concurrency)
    WORKING_MAX_ARTIFACT_BYTES       = tostring(var.working_runtime_settings.max_artifact_bytes)
    WORKING_MAX_CACHE_BYTES          = tostring(var.working_runtime_settings.max_cache_bytes)
    WORKING_MAX_LORA_RANK            = tostring(var.working_runtime_settings.max_lora_rank)
    WORKING_MAX_MANIFEST_BYTES       = tostring(var.working_runtime_settings.max_manifest_bytes)
    WORKING_MAX_OUTPUT_TOKENS        = tostring(var.working_runtime_settings.max_output_tokens)
    WORKING_REQUEST_CONCURRENCY      = tostring(var.working_runtime_settings.request_concurrency)
    WORKING_REQUEST_QUEUE_LIMIT      = tostring(var.working_runtime_settings.request_queue_limit)
    WORKING_VLLM_TIMEOUT_SECONDS     = tostring(var.working_runtime_settings.vllm_timeout_seconds)
    WORKING_W0_CONTRACT_ROOT         = var.working_runtime_settings.contract_root
  }

  working_runtime_environment_file = join("\n", [
    for key in sort(keys(local.working_runtime_environment)) :
    "${key}=${jsonencode(local.working_runtime_environment[key])}"
  ])
}

resource "aws_instance" "working" {
  ami                         = var.working_ami_id
  instance_type               = var.working_instance_type
  subnet_id                   = aws_subnet.private_application[var.working_subnet_key].id
  vpc_security_group_ids      = [aws_security_group.working.id]
  iam_instance_profile        = aws_iam_instance_profile.runtime["working"].name
  associate_public_ip_address = false
  monitoring                  = var.working_compute_settings.detailed_monitoring_enabled

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.working_compute_settings.root_volume_size_gib
    volume_type           = var.working_compute_settings.root_volume_type

    tags = {
      Name      = "${local.component_names.working}-root"
      Component = "working"
    }
  }

  ebs_block_device {
    device_name           = var.working_compute_settings.cache_device_name
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.working_compute_settings.cache_volume_size_gib
    volume_type           = var.working_compute_settings.cache_volume_type

    tags = {
      Name      = "${local.component_names.working}-cache"
      Component = "working"
    }
  }

  user_data = templatefile("${path.module}/templates/working_runtime_environment.sh.tftpl", {
    runtime_environment  = local.working_runtime_environment_file
    systemd_service_name = var.working_systemd_service_name
  })
  user_data_replace_on_change = true

  tags = {
    Name      = local.component_names.working
    Component = "working"
  }
}

resource "aws_route53_record" "working_private" {
  zone_id = aws_route53_zone.private.zone_id
  name    = var.working_private_dns_name
  type    = "A"
  ttl     = var.working_private_dns_ttl_seconds
  records = [aws_instance.working.private_ip]
}
