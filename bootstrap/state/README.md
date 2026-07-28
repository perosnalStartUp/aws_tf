# Terraform State Bootstrap

This directory is an independent Terraform root that creates the S3 bucket used by environment
roots. It always starts with local State and must never use the backend that it creates.

All account-specific values are required inputs. This root creates and owns the customer-managed
KMS key used by the State bucket. Its key policy enables account IAM authorization; actual KMS
usage is granted through the consuming Terraform bootstrap/deploy IAM policies. Do not grant this
State key to Backend, Working, or Training runtime roles. Test-only values belong only in
`tests/state_bootstrap.tftest.hcl`; do not copy them into deployment tfvars.

## Locking and Environment Keys

Environment roots use Terraform's S3 lockfile support (`use_lockfile = true`). No DynamoDB lock
table is created. Supply backend values outside Git:

```text
bucket         = "<real-state-bucket>"
key            = "environments/<environment>/terraform.tfstate"
region         = "<real-region>"
allowed_account_ids = ["<real-account-id>"]
```

The bootstrap bucket is shared infrastructure. Normal environment teardown must not target this
root. `prevent_destroy`, S3 versioning, TLS-only access, public-access blocking, and bucket-owner
enforced ownership provide guardrails but do not replace access review.

## Recovery Boundary

The required `owner` input identifies the recovery and break-glass owner. Before any authorized
bootstrap apply, record the real owner, approved IAM principals, bucket name, KMS key, region,
account, and recovery procedure in `routeMap/TERRAFORM_DEV_DOC.md`.

Restore uses a reviewed prior S3 object version. Never delete the bucket, object versions, or lock
objects as part of normal environment teardown. Live bootstrap, backend migration, lock testing,
force-unlock, or State mutation requires separate explicit authorization.
