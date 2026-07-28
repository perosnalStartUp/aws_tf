# Terraform AWS P1 Roadmap

P1 converts the confirmed architecture into reviewable Terraform without treating unmade product
or account decisions as defaults. Milestones may be split into separate PRs. Atomic task IDs,
dependencies, decision gates, completion evidence, and recommended execution waves are maintained
in `TERRAFORM_P1_TASKS.md`. The exact PR boundaries, entry gates, review surfaces, exclusions, and
task-to-PR mapping are maintained in `TERRAFORM_P1_PR_PLAN.md`.

## Status

| Milestone | State | Exit condition |
| --- | --- | --- |
| P1-0 Control and design baseline | Completed locally | repository instructions, skill, design, release model, roadmap statically validated |
| P1-1 State/bootstrap decisions | Blocked on decisions | reviewed backend/bootstrap configuration and recovery/access record |
| P1-2 Provider, naming, and network | Blocked on decisions | validated VPC/subnet/route/endpoints design |
| P1-3 KMS, S3, SQS | Planned | encrypted data/messaging resources and scoped policies validate |
| P1-4 IAM and security groups | Planned | deploy/build/release/runtime boundaries and SG graph validate |
| P1-5 RDS, Backend ASG, and ALB | Blocked on inputs/contracts | Backend infrastructure validates with migration/release boundary |
| P1-6 Working V0 single instance | Blocked on AMI/runtime inputs | private single EC2 and private DNS validate |
| P1-7 Training ASG/lifecycle/scaling | Blocked on runtime contract | ASG/SQS scaling/lifecycle design validates without unsafe refresh |
| P1-8 Monitoring and release integration | Planned | alarms/logs/OIDC workflows and drift cases validate |
| P1-9 Nonproduction plan/deploy | Requires explicit authorization | reviewed plan, approved apply, and recorded verification |

## P1-0 — Control and Design Baseline

- root `AGENTS.md` for automatic repository instruction discovery;
- `ai/` settings, limits, project context, and contracts;
- repository-specific Terraform development skill/restrictions;
- topology and security/ownership architecture;
- hardened AMI/LT/ASG release workflow design;
- factual dev record and roadmap.
- detailed atomic task breakdown in `TERRAFORM_P1_TASKS.md`.
- detailed 30-slice PR plan in `TERRAFORM_P1_PR_PLAN.md`.

No `.tf` or AWS mutation belongs to this milestone.

## P1-1 — State and Bootstrap

Owner decisions required:

- region/environment model; the real Account ID is deferred until the first authorized live plan,
  while local tests use Mock AWS;
- S3 backend name/key convention;
- state locking mechanism compatible with the selected Terraform version;
- bootstrap execution and break-glass ownership; the root location is confirmed as
  `bootstrap/state`;
- GitHub OIDC Terraform role repository/ref/environment conditions.

Deliverables:

- bootstrap approach and recovery runbook;
- backend/provider version constraints;
- encrypted/versioned/public-blocked state storage;
- least-privilege state access;
- `.gitignore` for Terraform artifacts and secret files.

## P1-2 — Provider, Naming, and Network

Owner decisions required:

- project/environment naming and required tags;
- VPC and subnet CIDRs;
- exact AZ-A/AZ-B names enabled for the account;
- IPv6 decision;
- Route53 private zone.

Deliverables:

- providers, typed variables, validations, locals, tags, outputs;
- pinned TFLint and Trivy Config checks;
- VPC, public/private-app/private-DB subnets;
- public route to the IGW;
- one AZ-A public NAT and both private application default routes to it;
- S3 Gateway Endpoint associated with both private application route tables;
- VPC DNS and initial flow-log/observability structure.

The public ALB decision is partially confirmed for the later Backend milestone: HTTP `80` is
redirect-only to HTTPS `443`.

## P1-3 — KMS, S3, and SQS

Deliverables:

- approved KMS key model and key policies;
- product S3 public-access block, TLS enforcement, versioning, KMS encryption;
- retention/lifecycle rules only for owner-approved prefixes/classes;
- Training queue, DLQ, encryption, redrive, long polling, visibility/retention;
- IAM policy documents split by Backend/Working/Training prefix and queue actions.

Exit requires cross-checking `ai/INTEGRATION_CONTRACTS.md`.

## P1-4 — IAM and Security Groups

Deliverables:

- separate Terraform deploy, Packer build, Backend release, Training release, and runtime roles;
- GitHub OIDC trust with repository/ref/environment conditions;
- separate instance profiles for Backend, Working, and Training;
- SSM/log/metric access as required;
- SG graph matching `TERRAFORM_AWS_DESIGN.md`;
- policy validation focused on wildcard, `iam:PassRole`, KMS, secret, EC2/LT/ASG mutation scope.

GPU governance must be synchronized with the field-scoped workflow ownership before release-role
policies are enabled.

## P1-5 — RDS, Backend ASG, and ALB

Owner inputs:

- domain/certificate/listeners;
- backend port and health path;
- Backend AMI, instance type, min/max capacity, and refresh preferences;
- RDS engine/version/class/storage/Multi-AZ/backups/deletion policy;
- credential secret ownership and migration runner.

Deliverables:

- private RDS subnet group/SG/parameter/logging/backup configuration;
- Backend LT/ASG/ALB/target group and alarms;
- ASG `$Default` relationship and narrow AMI lifecycle ownership;
- one-time migration release path;
- nonproduction drift tests for no-op, AMI-only workflow change, and structural change.

## P1-6 — Working V0

Owner inputs:

- exact approved Working AMI ID;
- GPU instance type, subnet/AZ, service port, disks/cache;
- private DNS name and TTL;
- authentication mode/secret identifier;
- expected replacement downtime and health check method.

Deliverables:

- one private `aws_instance`, encrypted volumes, IMDSv2, Working runtime role/SG;
- Route53 private record;
- runtime configuration without secret values in state/user data;
- explicit replacement and rollback procedure;
- no LT, ASG, or ALB.

## P1-7 — Training ASG, Lifecycle, and Scaling

Blocked until:

- Backend message/callback/control endpoint contracts align;
- lifecycle-hook completion and scale-in protection behavior exist and are testable;
- real Training AMI/runtime evidence is available;
- SQS visibility/job duration parameters are decided.

Deliverables:

- Training LT/ASG with On-Demand initial capacity;
- SQS-driven scaling and scale-to-zero behavior;
- termination lifecycle hook/heartbeat/permissions;
- public Backend ALB callback through the single NAT with application authentication;
- `$Default` release relationship without forced Instance Refresh;
- metrics/alarms for queue age, DLQ, capacity, lifecycle, GPU, disk, and job outcome.

## P1-8 — Monitoring and Release Integration

Deliverables:

- log groups/retention, dashboards, service alarms, notification targets;
- Backend and Training OIDC release workflows following `AMI_ASG_RELEASE_DESIGN.md`;
- exact Packer manifest handoff;
- component concurrency controls;
- normalized AMI-only LT version diff verification;
- rollback and actual-fleet verification;
- cost/budget alerts after owner thresholds are decided.

Confirmed repository split:

- Terraform deploy/State and Working V0 deployment: `terraform`;
- Backend Packer/release: `small_backend`;
- Working/Training Packer and Training release: `gpu_ec2`.

Exact GitHub org/repository identifiers, refs, environments and approval rules remain owner inputs
for the OIDC trust policies.

## P1-9 — Nonproduction Plan and Deployment

This milestone does not begin from repository-edit permission alone.

Required sequence:

1. identify the real account, region, environment, and credentials; local Mock values are
   prohibited from this point;
2. run local/static validation;
3. generate and review a saved nonproduction plan;
4. review destructive replacements, public exposure, IAM/KMS, state, and cost impact;
5. obtain explicit apply authorization;
6. apply and record exact resources/results;
7. verify network paths, IAM denials, service health, release/rollback, and observability;
8. update development records with evidence.

## Decisions Needed From the Owner

The consolidated decision list is in `ai/BASE_SETTINGS.md`. The next implementation task should
start with DP-01 through DP-03 in `TERRAFORM_P1_PR_PLAN.md`, then implement
`foundation-toolchain`, `foundation-provider-inputs`, `foundation-validation`, and
`state-bootstrap` in order.
Later service/runtime decisions remain gated to their consuming PRs.
