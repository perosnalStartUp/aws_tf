# Terraform Integration Contracts

This document records infrastructure-facing contracts. Runtime repositories remain authoritative
for exact request schemas and application behavior.

## Backend Dependencies

Terraform must eventually provide the backend with references to:

- RDS PostgreSQL endpoint/database and a runtime-resolved credential secret;
- product S3 bucket/prefixes and KMS key;
- Training SQS queue and DLQ;
- the Working private DNS base URL;
- application/logging environment metadata.

Backend startup must not run database migrations from every ASG instance. Migrations require one
explicit, observable release step.

## Working V0 Dependencies

Working V0 is one private EC2 instance addressable from Backend through Route53 private DNS.
Terraform must support the runtime configuration required by the GPU repository, including:

`AWS_REGION`, `ADAPTER_S3_BUCKET`, `ADAPTER_S3_PREFIX`, `MODEL_MANIFEST_S3_URI`,
`VLLM_INTERNAL_BASE_URL`, `WORKING_AUTH_MODE`, `WORKING_API_KEY_SECRET_ID`,
`WORKING_W0_CONTRACT_ROOT`, `WORKING_CACHE_ROOT`, `WORKING_MAX_LORA_RANK`,
`WORKING_MAX_MANIFEST_BYTES`, `WORKING_MAX_ARTIFACT_BYTES`, `WORKING_MAX_CACHE_BYTES`,
`WORKING_MAX_OUTPUT_TOKENS`, `WORKING_REQUEST_CONCURRENCY`, `WORKING_REQUEST_QUEUE_LIMIT`,
`WORKING_LOAD_CONCURRENCY`, `WORKING_DOWNLOAD_TIMEOUT_SECONDS`,
`WORKING_VLLM_TIMEOUT_SECONDS`, and `WORKING_DISK_FATAL_FREE_BYTES`.

This list defines integration names, not permission to store secret values in Terraform. The
instance role must retrieve any secret at runtime.

## Training Dependencies

Terraform must support the Training runtime configuration required by the GPU repository,
including:

`TRAINING_AWS_REGION`, `TRAINING_BUCKET`, `TRAINING_QUEUE_URL`,
`TRAINING_BACKEND_BASE_URL`, `TRAINING_CALLBACK_SECRET_ARN`,
`TRAINING_CALLBACK_SECRET_JSON_FIELD`, `TRAINING_ASG_NAME`, `TRAINING_KMS_KEY_ARN`,
`TRAINING_WORKING_MAX_LORA_RANK`, `TRAINING_EVALUATION_MAX_LOSS`,
`TRAINING_ARTIFACT_VERSION`, `TRAINING_CODE_COMMIT`, `IMAGE_TRAINING_CODE_COMMIT`,
`TRAINING_CONTAINER_IMAGE_DIGEST`, `TRAINING_AMI_ID`, `TRAINING_WORKSPACE_ROOT`,
`TRAINING_MODEL_CACHE_ROOT`, `TRAINING_VISIBILITY_TIMEOUT_SECONDS`,
`TRAINING_VISIBILITY_RENEW_INTERVAL_SECONDS`, `TRAINING_VISIBILITY_RETRY_INTERVAL_SECONDS`,
`TRAINING_VISIBILITY_MAX_FAILURES`, `TRAINING_MAX_RAW_DATASET_BYTES`,
`TRAINING_MAX_PROCESSED_DATASET_BYTES`, `TRAINING_MAX_CHECKPOINT_BYTES`, and
`TRAINING_CALLBACK_MAX_ATTEMPTS`.

The Training instance role requires narrowly scoped access to its SQS queue, approved S3 prefixes,
the product KMS key, its callback secret, CloudWatch/logging, and the EC2/ASG lifecycle operations
explicitly required by the worker design.

`TRAINING_BACKEND_BASE_URL` uses the public Backend ALB domain. Training resolves that public name
and reaches it from the private subnet through the single NAT Gateway. Callback security is
application-level HTTPS/Bearer/idempotency validation; the public path does not make Training
publicly reachable.

## Known Cross-Repository Blockers

These are unresolved integration blockers and must not be represented as completed:

1. Backend Training messages and the frozen Training schema differ, including
   `schemaVersion=training-job-v1` and model identity.
2. Backend callback authentication/body semantics differ from the Training Bearer,
   `Idempotency-Key`, `callbackId`, and exact-replay contract.
3. Backend lacks the authoritative internal Training job-control endpoint expected by the worker.
4. Training requires an explicit termination lifecycle-hook completion path; instance protection
   alone is insufficient.
5. Database migration execution must be separated from normal Backend ASG startup.
6. Working host packaging/AMI and a real Training AMI are not yet verified.
7. The checkpoint lifecycle draft and the worker's
   `checkpoints/{jobId}/worker_state.json` persistence path must be reconciled.
8. Training requires one callback secret ARN at runtime; IAM must permit only that approved secret.
9. Training Spot capacity remains prohibited until interruption/resume is verified.
10. Product S3 must use KMS because Training writes with `aws:kms`.

## Terraform Outputs and Workflow Inputs

Exact names will be finalized with the `.tf` layout. At minimum, downstream automation needs
stable references for:

- Backend and Training Launch Template IDs/names;
- Backend and Training ASG names;
- Working instance identity and private DNS name;
- product bucket, KMS key, Training queue/DLQ;
- Backend ALB/DNS endpoint;
- environment/account/region identity.

Outputs must not reveal secret values or credentials.
