# Terraform AWS P1 Pull Request Plan

Status: proposed PR decomposition. PR names in this file are planning names only.
They do not claim that a branch, commit, pull request, Terraform plan, deployment, or AWS resource
exists.

Owner-confirmed PR granularity: retain all 30 small PR slices.

## 1. Purpose

This plan converts the atomic tasks in `TERRAFORM_P1_TASKS.md` into reviewable pull requests.
The split follows the current Personal LoRA system boundary:

- Vercel remains outside this repository.
- Backend is a private ASG behind one internet-facing ALB.
- Working V0 is exactly one private Terraform-managed EC2 without LT/ASG/ALB.
- Training is a private On-Demand ASG driven by SQS.
- Terraform owns AWS structure; routine Backend/Training releases own only AMI-only Launch
  Template versions, the `$Default` pointer, and the documented rollout action.

This is a sequencing and review document. It does not resolve values marked
`[DECISION REQUIRED]`.

## 2. PR Rules

Every implementation PR must:

1. have one primary ownership and rollback surface;
2. list the exact task IDs it closes;
3. resolve only the Decision Gates needed by that PR;
4. keep provider, state, plan, and secret inputs out of Git when they are environment-specific or
   sensitive;
5. update `TERRAFORM_DEV_DOC.md` with factual commands and outcomes;
6. update architecture/release documents only when their decisions actually change;
7. run `VAL-001` for Terraform code changes after provider initialization is available;
8. report live plan/apply/AWS checks as `not run` unless explicitly authorized and executed;
9. avoid bundling a live state/AWS mutation with an otherwise reviewable code change;
10. preserve unrelated work in the uncommitted repository.

Planning names are not claims that GitHub PRs exist. Suggested branches use the `codex/` prefix only when a
branch is actually created.

## 3. Decision Packets

Decision Packets are owner inputs, not implementation PRs. A PR may be drafted before its packet is
resolved, but it must not merge production-shaped placeholders as if they were approved values.

| Packet | Decisions | Needed before |
| --- | --- | --- |
| DP-01 Account and naming | `DEC-001`, `DEC-002` | `foundation-toolchain`, `foundation-provider-inputs`, all named resources |
| DP-02 Network allocation | `DEC-003` | `foundation-provider-inputs`, `network-vpc-subnets` |
| DP-03 State bootstrap | `DEC-004` | `state-bootstrap` |
| DP-04 Backend edge/compute | `DEC-005`, `DEC-006` | `security-groups`, `compute-backend-core`, `edge-backend-https` |
| DP-05 Working V0 | `DEC-007` | `network-private-dns`, `security-groups`, `iam-build-release-roles`, `compute-working-v0` |
| DP-06 Training runtime/capacity | `DEC-008` | `messaging-training-sqs`, `iam-runtime-roles`, `compute-training-asg`, `scaling-training-callback` |
| DP-07 Data/retention/observability | `DEC-009` | `data-kms-s3`, `messaging-training-sqs`, `observability-foundation`, `observability-services-cost` |
| DP-08 RDS | `DEC-010` | `security-groups`, `database-rds`, `database-migration-runner` |
| DP-09 GitHub and deployment identity | `DEC-011`, `DEC-012` | `iam-deploy-oidc`, `workflow-backend-release`, `workflow-training-release`, `workflow-working-release` |

## 4. PR Sequence

| Order | PR name | Review surface | Task IDs | Entry gate | State |
| ---: | --- | --- | --- | --- | --- |
| 1 | `foundation-toolchain` | Repository hygiene and pinned toolchain | `FND-001`, `FND-002`, `VAL-002` | DP-01; tool choice approved | implemented locally |
| 2 | `foundation-provider-inputs` | Provider, names, variables, checks, fixtures | `FND-003` through `FND-006`, `VAL-003` | DP-01, DP-02; `foundation-toolchain` | in progress |
| 3 | `foundation-validation` | Provider initialization and repository validation gate | `FND-007`, `FND-008`, `VAL-001` | `foundation-toolchain`, `foundation-provider-inputs`; provider download available | in progress |
| 4 | `state-bootstrap` | State/bootstrap code and backend contract | `STATE-001` through `STATE-004` | DP-01, DP-03; `foundation-toolchain`, `foundation-validation` | blocked on decisions |
| 5 | `network-vpc-subnets` | VPC, six subnets, IGW, public/DB routing | `NET-001` through `NET-006`, `NET-009` | DP-02; `foundation-provider-inputs`, `foundation-validation` | blocked on decisions |
| 6 | `network-egress-s3-endpoint` | Single NAT and S3 Gateway Endpoint | `NET-007`, `NET-008`, `NET-010` | `network-vpc-subnets` | planned |
| 7 | `network-private-dns` | Private DNS and network outputs | `NET-011`, `NET-012` | DP-05; `network-vpc-subnets`, `network-egress-s3-endpoint` | blocked on decisions |
| 8 | `security-groups` | Security-group graph | `SG-001` through `SG-007` | DP-04, DP-05, DP-08; `network-vpc-subnets` | blocked on decisions |
| 9 | `data-kms-s3` | Product KMS and S3 data boundary | `DATA-001` through `DATA-004` | DP-07; `foundation-provider-inputs`, `foundation-validation` | blocked on decisions |
| 10 | `messaging-training-sqs` | Training SQS and DLQ | `DATA-005`, `DATA-006` | DP-06, DP-07; `data-kms-s3` | blocked on decisions |
| 11 | `iam-deploy-oidc` | Terraform deploy IAM and GitHub OIDC trust | `IAM-001`, `IAM-005` | DP-09; `foundation-provider-inputs`, `foundation-validation` | blocked on decisions |
| 12 | `iam-runtime-roles` | Backend, Working, Training runtime IAM | `IAM-002` through `IAM-004` | DP-05, DP-06; `data-kms-s3`, `messaging-training-sqs` | blocked on decisions |
| 13 | `iam-build-release-roles` | IAM policy verification and release-role boundary | `IAM-006`, `IAM-007` | DP-09; `iam-deploy-oidc`, `iam-runtime-roles`; EXT-03 | blocked on external governance |
| 14 | `database-rds` | Private PostgreSQL RDS | `RDS-001` through `RDS-004` | DP-08; `security-groups`, `data-kms-s3` | blocked on decisions |
| 15 | `database-migration-runner` | One-time Backend migration release boundary | `RDS-005`, `BE-009` | DP-08; Backend execution owner confirmed; `database-rds` | blocked on Backend decision |
| 16 | `compute-backend-core` | Backend LT, target group, ASG, and ALB | `BE-001` through `BE-005` | DP-04; network/data/IAM prerequisites | blocked on decisions/artifact |
| 17 | `edge-backend-https` | Backend HTTPS/DNS and `$Default` relationship | `BE-006`, `BE-007` | DP-04; `compute-backend-core` | blocked on decisions |
| 18 | `compute-working-v0` | Working V0 single EC2 and private record | `WK-001` through `WK-004` | DP-05; exact Working AMI; network/security/runtime-IAM prerequisites | blocked on artifact/decisions |
| 19 | `compute-training-asg` | Training LT, ASG, lifecycle and protection | `TR-003` through `TR-008` | DP-06; EXT-01, EXT-02; network/messaging/runtime-IAM prerequisites | blocked on runtime/artifact |
| 20 | `scaling-training-callback` | Training SQS scaling and Backend callback route | `TR-009`, `TR-010` | `messaging-training-sqs`, `edge-backend-https`, `compute-training-asg` | blocked on compute |
| 21 | `observability-foundation` | Log groups, queue/flow-log observability foundation | `OBS-001`, `OBS-002`, `NET-013`, `DATA-007` | DP-07; network/data/messaging prerequisites | blocked on decisions |
| 22 | `observability-services-cost` | Service dashboards, alarms, budgets | `BE-008`, `WK-005`, `TR-011`, `OBS-003` through `OBS-005` | service compute/scaling and `observability-foundation` | planned |
| 23 | `operations-runbooks` | Operations and deletion/retention runbooks | `OPS-001` through `OPS-003` | network/data/runtime-IAM/database prerequisites | planned |
| 24 | `workflow-backend-release` | Backend AMI release workflow | `RELEASE-002`, `RELEASE-003` | DP-09; EXT-03; release IAM and Backend edge | blocked on artifact/governance |
| 25 | `workflow-training-release` | Training AMI release workflow | `RELEASE-004` | DP-09; EXT-03; release IAM and Training ASG | blocked on artifact/governance |
| 26 | `workflow-working-release` | Working Terraform release workflow | `RELEASE-005` | DP-09; `compute-working-v0` | blocked on Working deployment |
| 27 | `workflow-release-hardening` | Release concurrency, rollback evidence, drift tests | `RELEASE-006` through `RELEASE-008` | all component release workflows | planned |
| 28 | `validation-service-runbooks` | Service-local review and replacement runbooks | `BE-010`, `WK-006` | foundation validation, Backend edge, Working, observability | planned |
| 29 | `deployment-nonprod` | Authorized state bootstrap and nonproduction deployment | `STATE-005`, `STATE-006`, `VAL-004` through `VAL-006` | named environment and explicit authorization | requires authorization |
| 30 | `verification-nonprod` | Nonproduction security/service/release verification | `WK-007`, `TR-012`, `VAL-007` through `VAL-009` | release hardening and nonproduction deployment; explicit authorization | requires authorization |

`FND-000` is already recorded as completed locally against an empty directory. It is historical
evidence, not a proposed PR. `TR-001`, `TR-002`, and `RELEASE-001` are external gates described
below rather than Terraform implementation PRs.

## 5. Detailed PR Boundaries

### `foundation-toolchain` — Repository Hygiene and Pinned Toolchain

Outcome:

- ignore Terraform state, plans, crash logs, overrides and local secret tfvars;
- preserve `.terraform.lock.hcl` for later commit;
- pin approved Terraform/AWS provider constraints;
- configure pinned TFLint and Trivy Config checks.

Must not include provider configuration, backend configuration, resources, credentials, or a live
provider download. Acceptance is static review plus the checks available before initialization.

### `foundation-provider-inputs` — Provider, Names, Variables, Checks, and Fixtures

Outcome:

- selected-region AWS provider with allowed-account validation and default tags;
- typed common variables and deterministic locals;
- account, CIDR, AZ, capacity, AMI and public-IP checks;
- deterministic valid/invalid fixtures for those rules;
- AWS tests using `mock_provider "aws"` and a test-only 12-digit Account ID.

Must not include VPC resources, state bootstrap, service compute, or convenient production
defaults. The test Account ID must not enter environment `.tfvars` or a live plan path. Invalid
inputs must fail with actionable messages.

### `foundation-validation` — Provider Initialization and Repository Validation

Outcome:

- initialized providers after `foundation-toolchain` and `foundation-provider-inputs`;
- committed `.terraform.lock.hcl`;
- exact `terraform fmt -check -recursive`, `terraform init -backend=false`,
  `terraform validate` and configured static-tool evidence.

If network/provider download is unavailable, record the blocker; do not claim validation passed.

### `state-bootstrap` — State Bootstrap Code and Backend Contract

Outcome:

- reviewed State decision and recovery/access record;
- independently initializable `bootstrap/state` Terraform root;
- encrypted/versioned/public-blocked S3 State resources and least-privilege access;
- partial backend configuration with environment separation.

Must not provision the bucket or migrate State. Live bootstrap and migration are
`deployment-nonprod`.
The bootstrap root initializes with local State before its separately authorized apply. Environment
roots consume the resulting remote backend only after it exists. Normal environment teardown must
never destroy the bootstrap root, State bucket, State versions or locking resources.

### `network-vpc-subnets` — VPC, Subnets, IGW, and Base Routing

Outcome:

- selected CIDR table with containment/non-overlap evidence;
- VPC DNS support/hostnames;
- two public, two private-application and two private-DB subnets;
- IGW/public routes;
- local-only DB routing.

Must not include NAT, endpoints, Route53, security groups or compute.

### `network-egress-s3-endpoint` — Single NAT and S3 Gateway Endpoint

Outcome:

- one EIP/NAT Gateway in AZ-A;
- both private-application route tables use that NAT for non-S3 IPv4 egress;
- S3 Gateway Endpoint is attached to both private-application route tables.

Review must call out the accepted NAT failure domain and AZ-B cross-AZ cost. Paid interface
endpoints and a second NAT remain out of scope.

### `network-private-dns` — Private DNS and Network Outputs

Outcome:

- VPC-associated private hosted zone;
- stable identifiers for VPC, subnets, route tables, NAT and private zone.

Must not create the Working record or Working instance. Secret values and credentials are never
outputs.

### `security-groups` — Security-Group Graph

Outcome:

- distinct ALB, Backend, Working, Training, RDS and endpoint groups;
- only ALB is internet-facing;
- Backend-to-RDS and Backend-to-Working use SG references;
- Training has no application ingress;
- egress/NAT comments accurately describe source translation.

Must not create IAM, ALB, RDS or EC2 resources. Rules that depend on undecided ports remain blocked
rather than widened.

### `data-kms-s3` — Product KMS and S3

Outcome:

- approved KMS key/alias model;
- versioned, private, KMS-encrypted product bucket;
- TLS-only and component/prefix policy documents;
- only owner-approved lifecycle rules.

Must not invent deletion periods. Durable datasets/adapters are not expired by convenience.

### `messaging-training-sqs` — Training SQS and DLQ

Outcome:

- KMS-encrypted queue and DLQ;
- redrive, retention, visibility and long-poll settings derived from approved runtime timing;
- queue policy and non-secret outputs.

Alarms remain `observability-foundation`. SQS interface endpoints remain out of scope.

### `iam-deploy-oidc` — Terraform Deploy IAM and GitHub OIDC

Outcome:

- environment-scoped Terraform deployment policy boundary;
- narrow `iam:PassRole`;
- GitHub OIDC provider/trust conditions for approved repositories, refs and environments.

Must not combine Terraform deployment, Packer, release or runtime authority.

### `iam-runtime-roles` — Runtime IAM

Outcome:

- separate Backend, Working and Training roles/profiles;
- prefix/queue/key/secret/log/SSM scope matching each runtime;
- Training has only the lifecycle operations required by its design;
- Working and Training receive no RDS access.

Must not create workflow roles or application secrets. Secret identifiers may be inputs; values
may not enter Terraform.

### `iam-build-release-roles` — Release IAM and Policy Verification

Outcome:

- separate Backend/Training Packer and release roles;
- mutation permissions restricted to the intended component LT/ASG surface;
- policy tests/review for wildcard resources, KMS, secret scope, `iam:PassRole` and public access.

This PR remains blocked until EXT-03 is resolved. It does not block Network, Data, RDS, Backend
structure or Working V0 work.

### `database-rds` — Private PostgreSQL RDS

Outcome:

- two-AZ DB subnet group;
- encrypted, private PostgreSQL instance/configuration;
- approved backup, deletion and logging behavior;
- runtime credential secret identifier without secret value in State.

Must not run migrations or connect Training/Working to RDS.

### `database-migration-runner` — One-Time Migration Release Boundary

Outcome:

- explicit migration execution owner;
- ordering before Backend rollout;
- retry/failure visibility and no per-instance migration startup;
- rollout gate showing migrations cannot race across the ASG.

This may be documentation/workflow infrastructure depending on the approved runner. It must not
invent Backend database credentials or execute a live migration.

### `compute-backend-core` — Backend LT, Target Group, ASG, and ALB

Outcome:

- exact bootstrap AMI and non-secret runtime references;
- hardened Launch Template;
- target group/health checks;
- private ASG across both application subnets with initial desired capacity 1;
- internet-facing ALB across both public subnets.

Must not add HTTPS/public DNS until `edge-backend-https` or run Instance Refresh. The LT must keep
`update_default_version = false`.

### `edge-backend-https` — Backend HTTPS/DNS and `$Default`

Outcome:

- certificate/listener/public DNS integration;
- HTTP `80` listener used only for HTTP-to-HTTPS redirect;
- ASG consumes LT `$Default`;
- reviewed Instance Refresh preferences without starting a refresh.

Must not implement the routine AMI release workflow; that belongs to `workflow-backend-release`.

### `compute-working-v0` — Working V0 Single EC2

Outcome:

- exact approved Working AMI;
- one private hardened `aws_instance`;
- Working runtime inputs/secret identifiers;
- private Route53 record and replacement dependency behavior.

The PR must fail review if it introduces a Working LT, ASG, target group, ALB, public IP or SSH.

### `compute-training-asg` — Training LT, ASG, Lifecycle, and Protection

Outcome:

- exact approved Training AMI and non-secret runtime configuration;
- hardened On-Demand Launch Template and private ASG;
- termination lifecycle hook;
- runtime permissions/boundaries for lifecycle completion and scale-in protection.

Must not implement queue scaling, forced refresh, Spot, or public ingress. The PR is blocked until
runtime lifecycle behavior and the exact AMI exist.

### `scaling-training-callback` — Training Scaling and Callback Route

Outcome:

- backlog-per-InService-instance metric math with explicit zero-instance behavior;
- scaling settings derived from approved job/warmup evidence;
- public Backend ALB callback configuration through the single NAT path.

Must not claim the callback or scale-from-zero path is verified before `verification-nonprod`.

### `observability-foundation` — Observability Foundation

Outcome:

- notification, retention, severity, dashboard and budget decisions;
- encrypted component log groups;
- VPC Flow Logs;
- SQS age/depth/DLQ alarms.

Must not add placeholder recipients or thresholds.

### `observability-services-cost` — Service Dashboards, Alarms, and Budgets

Outcome:

- Backend/ALB, Working, Training, RDS, SQS/DLQ and NAT visibility;
- dashboard dimensions tied to Terraform resources;
- budget/cost anomaly alerts with approved recipients.

Application metrics may be wired, but Terraform does not invent runtime emission that the service
does not provide.

### `operations-runbooks` — Operations Runbooks

Outcome:

- SSM access without inbound SSH;
- single-NAT outage behavior and future two-NAT upgrade/rollback;
- explicit deletion/retention process for State, RDS, S3, AMIs, snapshots and logs.

No destructive command is executed by this PR.

### `workflow-backend-release` — Backend AMI Release Workflow

Outcome:

- exact Packer-manifest input contract;
- OIDC/concurrency guarded Backend AMI-only LT version;
- `$Default` promotion, semantic ImageId-only diff, Instance Refresh, health verification and
  rollback evidence.

Workflow dispatch and AWS mutation are outside the PR's local validation.

### `workflow-training-release` — Training AMI Release Workflow

Outcome:

- Training AMI-only LT version and `$Default` promotion;
- validation of new scale-outs;
- no routine Instance Refresh, instance termination or removal of protection.

Mixed-version draining is expected and observable.

### `workflow-working-release` — Working Terraform Release Workflow

Outcome:

- approved Terraform input update/plan/apply path for the Working AMI;
- replacement and DNS evidence contract;
- explicit prohibition on Working LT/ASG API calls.

The workflow may prepare a plan without authorization only if it does not read a live environment;
a real plan/apply follows the repository execution boundary.

### `workflow-release-hardening` — Release Hardening and Drift Tests

Outcome:

- component/environment concurrency and stale-default guard;
- standardized rollback evidence;
- tests for no release, AMI-only release, structural drift, and structural update after an AMI
  release.

Live drift cases require nonproduction authorization. Static helpers/tests may merge earlier with
unexecuted live cases clearly marked.

### `validation-service-runbooks` — Service Review and Replacement Runbooks

Outcome:

- Backend review checklist for exposure, RDS access, desired capacity and LT lifecycle;
- Working replacement/rollback/DNS downtime runbook.

This PR records procedures and local/static checks. Actual replacement evidence belongs to
`verification-nonprod`.

### `deployment-nonprod` — Authorized State and Nonproduction Deployment

Outcome:

- provision State bootstrap resources;
- migrate/verify remote State;
- produce and review a saved nonproduction plan;
- apply only after separate explicit authorization.

This is an operational change set, not implied by merging code. Account, region, environment,
credentials, plan review and apply approval must be recorded.

Mock inputs stop at this boundary. The real Account ID and credentials are required before the
first live `terraform plan`, not only before `apply`.

### `verification-nonprod` — Nonproduction Verification

Outcome:

- positive and negative network/security checks;
- Backend-to-Working private path;
- Training NAT callback, SQS and lifecycle behavior;
- Working replacement/DNS behavior;
- Backend/Training release and rollback evidence;
- final evidence-backed milestone classification.

This PR/acceptance record cannot begin until a named nonproduction deployment exists.

## 6. External Gates That Do Not Block Early Terraform PRs

| Gate | Required fact | Blocks |
| --- | --- | --- |
| EXT-01 | Backend/Training message, callback and control contracts are aligned (`TR-001`) | `compute-working-v0` onward |
| EXT-02 | Training runtime proves scale-in protection and lifecycle-hook completion (`TR-002`) | `compute-working-v0` onward |
| EXT-03 | GPU/release governance accepts the field-scoped `$Default` workflow boundary (`RELEASE-001`) | `iam-build-release-roles`, `workflow-backend-release`, `workflow-training-release`, `workflow-release-hardening` |
| EXT-04 | Exact Working and Training AMIs exist with build evidence | `compute-working-v0` and `compute-training-asg` respectively |

These gates do not block the foundation, State, network, security, data, deploy-IAM, runtime-IAM,
or `database-rds` PRs. Terraform may
continue without synchronizing all four repositories, provided it does not represent an unresolved
consumer contract as deployed or verified.

`RELEASE-002` is included in `workflow-backend-release` as the Terraform/release input contract. Producing each
component's actual manifest remains the component build repository's responsibility.

## 7. Parallelism

After `foundation-validation`:

- `state-bootstrap` and `network-vpc-subnets` can be reviewed independently.
- `data-kms-s3` can begin independently of `network-vpc-subnets` when its naming/KMS decisions are
  ready.

After the security, data, messaging, deploy-IAM and runtime-IAM foundations:

- `database-rds` / `database-migration-runner` Backend data work;
- `compute-working-v0`;
- `compute-training-asg` / `scaling-training-callback`;
- `observability-foundation`

can proceed on separate branches when their own gates are satisfied. They must not duplicate or
edit the same shared IAM, variable or output surfaces without rebasing/review.

## 8. Coverage Check

The plan accounts for:

- completed historical task: `FND-000`;
- all remaining `FND-*`, `STATE-*`, `NET-*`, `SG-*`, `IAM-*`, `DATA-*`, `RDS-*`, `BE-*`, `WK-*`,
  `TR-*`, `OBS-*`, `OPS-*`, `RELEASE-*`, and `VAL-*` tasks;
- external prerequisite tasks `TR-001`, `TR-002`, and `RELEASE-001`;
- all decision gates `DEC-001` through `DEC-012`.

No planning name is evidence that the corresponding PR exists.

## 9. Owner Confirmations Still Required

The PR boundaries above do not require these answers to exist, but implementation does:

1. DP-01 through DP-09 values.
2. Where the one-time Backend migration runner executes.
3. Exact GitHub organization/repository slugs, refs, environments and approval rules used by the
   confirmed workflow owners.

Confirmed 2026-07-28:

- retain 30 small PR slices;
- State bootstrap is the separate `bootstrap/state` Terraform root;
- `foundation-toolchain` uses TFLint plus Trivy Config;
- public HTTP `80` is redirect-only.
- workflow ownership is split as follows:
  - `terraform`: Terraform deploy/State and Working V0 deployment;
  - `small_backend`: Backend Packer and Backend release;
  - `gpu_ec2`: Working/Training Packer and Training release.
- all pre-live-plan local validation uses a test-only Account ID and Mock AWS Provider; the real
  Account ID is deferred until `deployment-nonprod` before `VAL-004`.

Until confirmed, the relevant PR remains `blocked on decisions`; no default in this document
answers on the owner's behalf.
