# Terraform AWS Operating Restrictions

## Change Control

- Read the plan and relevant service contracts before implementation.
- Preserve unrelated local changes and do not rewrite history.
- Treat generated plans, state, credentials, and Packer manifests according to their sensitivity;
  only immutable artifact IDs intended for deployment may enter normal records.
- Explicit user approval of file edits does not authorize live AWS changes.

## State and Provider Safety

- Bootstrap state separately and document recovery/ownership.
- Require state encryption, versioning, restricted bucket access, public-access blocking, and
  locking.
- Never commit state, backup state, plan binaries, `.terraform/`, crash logs, or secret tfvars.
- Pin compatible Terraform/provider versions after selection. Commit the provider lock file when
  configuration exists.
- Avoid provisioners and `local-exec`; use image build, user data, SSM, or explicit release steps.
- Do not use Terraform workspaces as an implicit security boundary.

## Network

- Use at least two Availability Zones for ALB/RDS/ASG resources unless a documented nonproduction
  decision says otherwise. Working V0 itself remains one instance.
- Public subnets are for public-facing load-balancer/NAT components only.
- Backend, Working, Training, and RDS belong in private subnets with no public IP.
- Prefer security-group-to-security-group rules over broad CIDRs for east-west traffic.
- Restrict egress where the required AWS/service destinations are known. Record NAT-versus-VPC-
  endpoint cost and operability decisions.
- Enable appropriate VPC, ALB, application, and database observability without logging secrets.

## IAM and Secrets

- Separate Terraform deploy, Packer build, release workflow, Backend runtime, Working runtime, and
  Training runtime roles.
- GitHub workflows assume short-lived OIDC roles with repository/ref/environment conditions.
- Scope release roles to their component Launch Template and ASG. Tag conditions supplement but do
  not replace explicit resource scope where ARN scoping exists.
- Runtime roles may access only the required S3 prefixes, queue, KMS key, log groups, and named
  secret.
- Store secret values in an approved secret service and retrieve them at runtime. Passing an ARN or
  secret identifier through Terraform is acceptable; passing the value is not.
- Be aware that RDS master passwords, generated passwords, and sensitive outputs can still enter
  state even when marked `sensitive`.

## Compute and Images

- Enforce IMDSv2, encrypted volumes, explicit volume sizing/type, and no public IP.
- Validate architecture compatibility among AMI, instance type, CUDA/runtime, and container image.
- Use exact Packer manifest AMI IDs. Never select by unbounded “latest” filters.
- Pin container images by digest in production paths.
- User data must be minimal, non-secret, idempotent, and must not perform uncontrolled package
  upgrades.
- Use SSM rather than persistent SSH keys.

## Release Ownership

- Terraform owns Backend/Training Launch Template and ASG structure.
- The release workflow clones the current `$Default`, changes only `ImageId`, verifies the diff,
  creates the version, and promotes `$Default`.
- `update_default_version` must remain disabled when the release workflow owns `$Default`.
- Terraform must ignore the AMI field that the release workflow owns, but must not ignore unrelated
  structural drift.
- A structural Launch Template change creates a candidate version. Promoting it is an explicit
  reviewed release step; do not assume `$Latest` is safe.
- Backend rollout may start Instance Refresh with explicit health and rollback checks.
- Training rollout changes only which AMI future scale-outs use unless a separate drain/replace
  operation is approved. Never force-refresh protected jobs.
- Use component-level concurrency control. Capture previous default/version/AMI for rollback.
- Verify actual fleet instance IDs, AMI IDs, health, and Launch Template versions after rollout.

## Data Services

- Encrypt S3, SQS, EBS, logs where supported, and RDS with approved KMS keys.
- Enable product-bucket public-access blocking and deny insecure transport.
- Define lifecycle policies only after dataset, adapter, log, and checkpoint retention is approved.
- Configure SQS DLQ/redrive and visibility timeout from the real job-time contract.
- RDS must use private DB subnets, restricted SG ingress, backups, deletion protection/snapshot
  policy appropriate to the environment, and an explicit migration process.
- Training must not receive RDS network access or credentials.

## Verification

- Local formatting/validation is not deployment evidence.
- A Terraform plan is valid only for the exact code, inputs, state, account, region, and time at
  which it ran.
- Review plans for replacements, destroys, IAM expansion, public exposure, KMS/data changes, ASG
  refresh, and state moves.
- Record skipped checks and reasons. Do not convert assumptions into facts.
