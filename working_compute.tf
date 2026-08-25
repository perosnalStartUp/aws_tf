# =============================================================================
# Working compute inputs
# =============================================================================
variable "working_instance_type" {
  type        = string
  description = "Approved Working V0 GPU instance type."
  nullable    = false
}

variable "working_subnet_key" {
  type        = string
  description = "Private application subnet key for the single Working V0 instance."
  nullable    = false

  validation {
    condition     = contains(["private_app_a", "private_app_b"], var.working_subnet_key)
    error_message = "working_subnet_key must be private_app_a or private_app_b."
  }
}

variable "working_private_dns_name" {
  type        = string
  description = "Stable Working V0 FQDN inside the Terraform-managed private hosted zone."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$", var.working_private_dns_name))
    error_message = "working_private_dns_name must be a valid DNS name."
  }
}

variable "working_private_dns_ttl_seconds" {
  type        = number
  description = "Reviewed TTL for the Working V0 private A record."
  nullable    = false

  validation {
    condition = (
      var.working_private_dns_ttl_seconds >= 1 &&
      var.working_private_dns_ttl_seconds <= 86400 &&
      floor(var.working_private_dns_ttl_seconds) == var.working_private_dns_ttl_seconds
    )
    error_message = "working_private_dns_ttl_seconds must be a whole number from 1 through 86400."
  }
}

variable "working_service_scheme" {
  type        = string
  description = "Backend-to-Working scheme selected for the private runtime contract."
  nullable    = false

  validation {
    condition     = contains(["http", "https"], var.working_service_scheme)
    error_message = "working_service_scheme must be http or https."
  }
}

variable "working_systemd_service_name" {
  type        = string
  description = "Systemd unit installed by the approved Working AMI."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.@-]+\\.service$", var.working_systemd_service_name))
    error_message = "working_systemd_service_name must be a systemd .service unit name."
  }
}

variable "working_compute_settings" {
  type = object({
    root_volume_size_gib        = number
    root_volume_type            = string
    cache_device_name           = string
    cache_volume_size_gib       = number
    cache_volume_type           = string
    detailed_monitoring_enabled = bool
  })
  description = "Reviewed Working V0 encrypted root/cache volume and monitoring settings."
  nullable    = false

  validation {
    condition = (
      startswith(var.working_compute_settings.cache_device_name, "/dev/") &&
      var.working_compute_settings.root_volume_size_gib >= 8 &&
      var.working_compute_settings.cache_volume_size_gib >= 1 &&
      contains(["gp2", "gp3", "io1", "io2"], var.working_compute_settings.root_volume_type) &&
      contains(["gp2", "gp3", "io1", "io2"], var.working_compute_settings.cache_volume_type)
    )
    error_message = "Working compute settings require distinct /dev devices, root >= 8 GiB, cache >= 1 GiB, and supported encrypted EBS types."
  }
}

check "working_private_dns_contract" {
  assert {
    condition     = endswith(var.working_private_dns_name, ".${trimsuffix(var.private_zone_name, ".")}")
    error_message = "working_private_dns_name must belong to private_zone_name."
  }
}

variable "working_runtime_settings" {
  type = object({
    adapter_s3_prefix        = string
    model_manifest_s3_key    = string
    vllm_internal_base_url   = string
    auth_mode                = string
    contract_root            = string
    cache_root               = string
    max_lora_rank            = number
    max_manifest_bytes       = number
    max_artifact_bytes       = number
    max_cache_bytes          = number
    max_output_tokens        = number
    request_concurrency      = number
    request_queue_limit      = number
    load_concurrency         = number
    download_timeout_seconds = number
    vllm_timeout_seconds     = number
    disk_fatal_free_bytes    = number
  })
  description = "Required non-secret Working Adapter Manager runtime settings from the GPU contract."
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z0-9!_.*'()/-]+$", var.working_runtime_settings.adapter_s3_prefix)) &&
      !startswith(var.working_runtime_settings.adapter_s3_prefix, "/") &&
      can(regex("^[A-Za-z0-9!_.*'()/-]+$", var.working_runtime_settings.model_manifest_s3_key)) &&
      startswith(var.working_runtime_settings.vllm_internal_base_url, "http://") &&
      contains(["none", "api-key"], var.working_runtime_settings.auth_mode) &&
      startswith(var.working_runtime_settings.contract_root, "/") &&
      startswith(var.working_runtime_settings.cache_root, "/") &&
      alltrue([
        var.working_runtime_settings.max_lora_rank > 0,
        var.working_runtime_settings.max_manifest_bytes > 0,
        var.working_runtime_settings.max_artifact_bytes > 0,
        var.working_runtime_settings.max_cache_bytes >= var.working_runtime_settings.max_artifact_bytes,
        var.working_runtime_settings.max_output_tokens > 0,
        var.working_runtime_settings.request_concurrency > 0,
        var.working_runtime_settings.request_queue_limit >= 0,
        var.working_runtime_settings.load_concurrency > 0,
        var.working_runtime_settings.download_timeout_seconds > 0,
        var.working_runtime_settings.vllm_timeout_seconds > 0,
        var.working_runtime_settings.disk_fatal_free_bytes > 0,
      ])
    )
    error_message = "Working runtime settings must use scoped S3 keys, local absolute roots, a private HTTP vLLM URL, an approved auth mode, and positive measured limits."
  }
}

# =============================================================================
# Working V0 instance and private DNS
# =============================================================================
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

# =============================================================================
# Working outputs
# =============================================================================
output "working_instance_id" {
  description = "Single Working V0 EC2 instance ID."
  value       = aws_instance.working.id
}

output "working_private_dns_name" {
  description = "Stable private Working V0 DNS name consumed by Backend."
  value       = aws_route53_record.working_private.fqdn
}

output "working_private_url" {
  description = "Private Working V0 base URL; no credential value is included."
  value       = "${var.working_service_scheme}://${aws_route53_record.working_private.fqdn}:${var.working_service_port}"
}
