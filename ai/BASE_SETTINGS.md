# Terraform AWS Base Settings

## Purpose

This repository defines the AWS infrastructure shared by the Personal LoRA backend, GPU Working
inference service, and GPU Training worker. The frontend remains on Vercel and is outside this
Terraform repository.

## Confirmed Service Topology

| Service | Compute model | Entry path | Release behavior |
| --- | --- | --- | --- |
| Backend | Private EC2 Auto Scaling Group, initial `desired = 1` | Internet-facing ALB | AMI-only Launch Template version, promote `$Default`, then Instance Refresh |
| GPU Working V0 | Exactly one private EC2 | Backend through Route53 private DNS | Terraform replaces the instance when its approved AMI ID changes |
| GPU Training | Private GPU EC2 Auto Scaling Group | SQS-driven; no public listener | AMI-only Launch Template version, promote `$Default`; do not force-refresh protected jobs |

Working V0 deliberately has no Launch Template, ASG, or ALB. A later HA/multi-instance Working
design is a new architecture decision, not an implicit extension of V0.

## Confirmed Network Cost Model

- Use public and private application subnets across AZ-A and AZ-B.
- Use one public NAT Gateway in AZ-A for the first low-cost version.
- Route both private application subnets through that NAT for non-S3 IPv4 egress.
- Add an S3 Gateway Endpoint to both private application route tables.
- Defer paid interface endpoints; SQS and required AWS management APIs initially use NAT.
- Training calls the public Backend ALB URL through NAT for callbacks/control.
- Accept the single NAT failure domain and AZ-B cross-AZ egress cost until a later HA upgrade.

## Terraform Layout

- Keep one root module per deployable environment unless a later decision introduces reusable
  child modules.
- Split root configuration by responsibility (`network.tf`, `iam.tf`, `backend_compute.tf`,
  `working_compute.tf`, and similar), not by ad hoc implementation history.
- Use typed variables with validation and descriptions. Do not hide required decisions behind
  arbitrary defaults.
- Use stable resource names and shared tags derived from project, environment, component, and
  owner inputs.
- Publish only outputs required by another component, operator, or workflow.

## Local Account Test Strategy

- Local development before the first authorized live AWS plan uses a 12-digit test Account ID
  only inside Terraform test inputs.
- Terraform tests use `mock_provider "aws"` and must not require AWS credentials or contact AWS.
- The real `aws_account_id` remains a required deployment input with no production default.
- Do not place the test Account ID in environment `.tfvars`, backend configuration, workflow
  environments, or any path used by a real plan/apply.
- The real Account ID and credentials are required no later than the first authorized live
  `terraform plan`; they cannot be deferred until after plan review.

## State

- Use an encrypted, versioned S3 backend with Terraform's native S3 lockfile
  (`use_lockfile = true`); do not add a DynamoDB locking table.
- Bootstrap resources for state use a separate Terraform root at `bootstrap/state` in this
  repository. That root is a separately reviewed exception because Terraform cannot use a backend
  that does not yet exist.
- Separate environments by separate state keys and access boundaries.
- Never place runtime secrets, private keys, callback tokens, or generated credentials in Terraform
  variables, outputs, locals, user data, or state.
- Pin Terraform and provider version ranges after the initial compatibility decision.

The bootstrap root location and S3 lockfile mechanism are confirmed. Terraform creates and owns
the customer-managed State KMS key. Its key policy enables account IAM authorization; actual use is
granted through the consuming Terraform bootstrap/deploy IAM policies. The backend bucket name,
key convention, region, recovery owner, IAM principal details, and environment access boundaries
remain `[DECISION REQUIRED]`.

## Infrastructure and Release Ownership

Terraform owns resource structure:

- VPC, subnets, routes, endpoints/NAT decisions, DNS, security groups;
- IAM roles, instance profiles, policies, KMS, S3, SQS, RDS, ALB;
- Launch Template structure and ASG configuration for Backend and Training;
- the single Working V0 EC2 instance;
- monitoring and scaling policy structure.

Terraform creates and owns customer-managed KMS keys for Terraform-managed encrypted resources.
Key policies enable account IAM authorization; the IAM policy of each consuming program/role
grants actual use of the specific key ARN. Resource configuration references created keys directly
through addresses such as `aws_kms_key.product.arn`.

The AMI release workflow owns a deliberately narrow mutable surface for Backend and Training:

- create an AMI-only Launch Template version cloned from the current `$Default`;
- promote or restore the Launch Template `$Default` pointer;
- start and observe the service-specific rollout action.

Terraform must not continually reset the AMI field or `$Default` pointer managed by that release
surface. The workflow must not change instance profile, user data, security groups, instance type,
storage, metadata options, capacity, scaling policies, or any other structural field.

Confirmed workflow repository ownership:

- `terraform` owns Terraform validation/plan/apply, State bootstrap, and Working V0 AMI
  replacement through Terraform.
- `small_backend` owns Backend Packer builds and the Backend AMI release workflow.
- `gpu_ec2` owns Working/Training Packer builds and the Training AMI release workflow.
- Working Packer produces the immutable AMI manifest in `gpu_ec2`, but deployment crosses into a
  reviewed Terraform AMI-input change because Working V0 has no LT/ASG release surface.

The exact GitHub organization/repository slugs, refs, environments, subjects, and approval rules
remain `[DECISION REQUIRED]` for OIDC trust policies.

## AMI Selection

- Packer builds an immutable AMI and emits its exact AMI ID in a machine-readable manifest.
- Terraform or the release workflow consumes an explicitly approved AMI ID.
- Do not use `data "aws_ami"` with `most_recent = true` for production deployment.
- Working V0 AMI updates are Terraform input changes.
- Backend and Training routine releases use the `$Default` pointer workflow described in
  `routeMap/AMI_ASG_RELEASE_DESIGN.md`.

## Current Undecided Inputs

Do not implement production values until the owner decides at least:

- AWS account(s), region, environment names, naming/tagging values;
- VPC CIDR, exact Availability Zone names, and subnet CIDRs;
- Route53 private zone and Working service name;
- Backend minimum/maximum capacity, Working/Training capacity, and all instance types;
- approved initial AMI IDs;
- domain, certificate, ALB listener, and health-check settings;
- RDS engine version, class, storage, backup, Multi-AZ, and deletion policy;
- S3 retention/versioning/lifecycle details;
- SQS visibility, DLQ, redrive, and scaling thresholds;
- Terraform state bucket/key/lock/access values and GitHub OIDC role boundaries.

The public ALB listener decision is partially confirmed: expose HTTP `80` only to redirect to
HTTPS, never for plaintext application traffic. Domain, certificate, HTTPS policy, Backend port,
and health-check settings remain `[DECISION REQUIRED]`.
