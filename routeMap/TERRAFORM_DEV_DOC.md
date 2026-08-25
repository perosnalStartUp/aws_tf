# Terraform Development Record

This is the factual implementation record for the Terraform repository. Planned work belongs in
`TERRAFORM_P1_ROADMAP.md`; this file records only what exists and what actually ran.

## Repository Baseline

| Field | Value |
| --- | --- |
| Repository | `/Users/eric/Documents/starUp/personal_lora/terraform` |
| Branch at initialization | `vpc` |
| Commit at initialization | not created; repository had no commits |
| Existing Terraform files before initialization | none |
| Live Terraform state | not created / not inspected |
| AWS environment changed by this initialization | no |

## Current Status

| Area | Status | Evidence |
| --- | --- | --- |
| Repository governance | Implemented and statically validated locally | root `AGENTS.md`, `ai/` controls, repository skill |
| Architecture design | Implemented and statically reviewed locally | `TERRAFORM_AWS_DESIGN.md` |
| AMI/LT/ASG release design | Implemented and statically reviewed locally | `AMI_ASG_RELEASE_DESIGN.md` |
| P1 roadmap | Implemented and statically reviewed locally | `TERRAFORM_P1_ROADMAP.md` |
| Detailed P1 task map | Implemented and statically validated locally | `TERRAFORM_P1_TASKS.md` |
| Detailed P1 PR map | Implemented and statically validated locally | `TERRAFORM_P1_PR_PLAN.md` |
| Terraform `.tf` configuration | Foundation through Terraform-owned PR28 structure implemented locally | State/network/data/IAM/RDS; compute; observability/cost; operations/release contracts |
| Terraform init | Root and `bootstrap/state` initialized locally with backend disabled | AWS provider `6.47.0` locked separately in both roots |
| Terraform validate/test | Passed locally | both roots validate; root Mock tests 23/23 and State Mock tests 3/3 |
| Terraform live plan/apply | not run | no named/approved live environment inputs |
| AWS resources | not created or changed | all validation was local/mock-only |
| Packer/AMI build | not run | out of this task's execution scope |
| GitHub workflow | not created or run | ownership/activation contract documented; real delivery decisions and external repositories block executable workflows |

## Development Entries

### 2026-07-27 — Terraform Repository Control Plane and Design Baseline

Scope:

- created root repository instructions;
- created base settings, hard limits, project context, and integration contracts;
- created the repository-specific `terraform-aws-development` skill and restrictions;
- recorded the confirmed Working V0 topology;
- recorded the confirmed Backend/Training `$Default` AMI release ownership model;
- created the P1 implementation roadmap;
- did not create Terraform configuration or mutate AWS.

Decisions recorded:

- Working V0 is exactly one private Terraform-managed EC2 with Route53 private DNS and no
  LT/ASG/ALB.
- Backend and Training initial structure is Terraform-managed.
- Routine Backend/Training releases create AMI-only LT versions from `$Default`, promote
  `$Default`, and perform service-specific rollout behavior.
- Backend may use Instance Refresh; Training must not force-refresh protected jobs.
- Deployment uses exact approved AMI IDs, never an unbounded “latest” lookup.

Validation:

- local YAML/frontmatter structure checks: passed for `SKILL.md`;
- `agents/openai.yaml` YAML, description-length, and `$terraform-aws-development` prompt checks:
  passed;
- every path required by root `AGENTS.md`: exists;
- placeholder-marker and trailing-whitespace scan: no matches;
- repository file inventory: 12 files outside `.git`;
- `.tf` file inventory: empty, as intended for this documentation-only milestone;
- Terraform format/validate: not applicable because no `.tf` files were created;
- Terraform plan/apply and AWS verification: not run.

Known blockers:

- production inputs listed in `ai/BASE_SETTINGS.md` need owner decisions;
- runtime integration blockers listed in `ai/INTEGRATION_CONTRACTS.md` remain unresolved;
- GPU repository ownership language conflicts with the newly confirmed workflow write boundary and
  must be synchronized before LT/ASG implementation.

### 2026-07-27 — Final Low-Cost Network Topology

Scope:

- replaced the conceptual topology with the confirmed Mermaid network/data-flow diagram;
- recorded final route, egress, callback, security-group, and failure-domain behavior;
- synchronized base settings, integration contracts, and the P1 roadmap;
- did not create Terraform configuration or mutate AWS.

Decisions recorded:

- one public NAT Gateway in AZ-A serves both private application subnets;
- S3 uses a Gateway Endpoint; paid interface endpoints are deferred initially;
- Backend uses a private ASG across AZ-A/AZ-B behind a public ALB with initial `desired = 1`;
- Training remains private and calls the public Backend ALB through NAT;
- Training has no inbound listener, and callback security relies on HTTPS plus the frozen
  Bearer/idempotency/replay contract;
- the first version accepts the single NAT failure domain and AZ-B cross-AZ egress cost.

Validation:

- Markdown fences: balanced;
- Mermaid block structure: passed local static checks; no Mermaid CLI renderer was installed;
- placeholder-marker and trailing-whitespace scan: no matches;
- Terraform format/validate/plan/apply: not applicable / not run;
- AWS verification: not run.

### 2026-07-27 — Empty-Directory Init and Detailed Task Decomposition

Scope:

- verified the local Terraform binary and repository state;
- ran non-interactive `terraform init` as explicitly requested;
- created `TERRAFORM_P1_TASKS.md` with atomic task IDs, dependencies, decision gates, completion
  evidence, execution waves, and deployment authorization boundaries;
- linked the task map from root instructions and the P1 roadmap;
- did not create `.tf`, contact AWS, install a provider, create state, plan, or apply.

Command evidence:

- `terraform version` -> `Terraform v1.13.3` on `darwin_arm64`;
- `terraform init -input=false -no-color` -> exit `0`;
- init output -> `Terraform initialized in an empty directory!`;
- Terraform also reported that the directory had no configuration files.

Interpretation:

- init succeeded only as an empty-directory baseline;
- no AWS provider, backend, `.terraform.lock.hcl`, Terraform state, or AWS resource was created;
- rerun init after `versions.tf` and `providers.tf` exist (`FND-007`).

Validation:

- task ID/dependency scan: 120 unique decision/task IDs; all exact references resolve;
- Markdown fences: balanced;
- Mermaid block structure: passed local static checks;
- required-file path scan: passed;
- placeholder-marker and trailing-whitespace scan: no matches;
- generated Terraform metadata check: no `.terraform/`, `.terraform.lock.hcl`, `.tf`, or state file
  exists after the empty-directory init;
- Terraform validate/plan/apply and AWS verification: not run.

### 2026-07-28 — Detailed Pull Request Decomposition

Scope:

- created `TERRAFORM_P1_PR_PLAN.md`;
- mapped the existing atomic task inventory into 30 proposed, reviewable PR surfaces;
- separated decision packets, external runtime/artifact gates, local implementation PRs, and
  explicitly authorized deployment/verification changes;
- updated repository required reading, the P1 roadmap, and the detailed task map to reference the
  PR plan;
- did not create Terraform configuration, a branch, commit, pull request, workflow, plan, State or
  AWS resource.

Decisions recorded:

- early Terraform foundation, network, data and base IAM work does not require four repositories
  to be synchronized first;
- runtime-contract, lifecycle, artifact and release-governance dependencies block only their
  consuming Training/release PRs;
- live State bootstrap, plan, apply and nonproduction verification remain separate operational
  change sets requiring a named environment and explicit authorization;
- unresolved owner inputs remain Decision Packets and are not replaced with defaults.

Validation:

- source task inventory: 120 unique decision/task IDs;
- PR sequence: 30 table rows and 30 matching detailed sections;
- planning-name/order alignment: passed for all 30 semantic PR names;
- task coverage comparison: passed with no missing or unexpected task ID;
- PR-plan task-reference comparison: passed with no unknown task ID;
- Markdown fence balance and trailing-whitespace scan: passed for all changed documents;
- required-file existence scan: passed;
- Terraform format/validate/plan/apply: not applicable / not run;
- AWS verification: not run.

Known blockers:

- DP-01 through DP-09 remain owner decisions;
- exact Working/Training AMIs and Training lifecycle evidence do not exist;
- cross-repository runtime and release-governance gates remain limited to the consuming PRs.

### 2026-07-28 — Confirm Initial PR, Bootstrap, Validation, and ALB Listener Choices

Scope:

- retained the 30-small-PR decomposition;
- confirmed `bootstrap/state` as the independently initialized State root in this repository;
- selected TFLint and Trivy Config for `foundation-toolchain` static validation;
- confirmed public ALB HTTP `80` is redirect-only to HTTPS `443`;
- inspected locally available CLI tools;
- did not install software, create Terraform configuration, initialize the bootstrap root, run a
  workflow, plan/apply, or change AWS.

Command evidence:

- `terraform version` -> Terraform `v1.13.3` on `darwin_arm64`;
- `aws --version` -> AWS CLI `2.31.6` on `darwin_arm64`;
- `tflint --version` -> command not found;
- `trivy --version` -> command not found.

Interpretation:

- Terraform and AWS CLI are locally available;
- TFLint and Trivy are separate selected validation dependencies and still require installation
  before their `foundation-toolchain` checks can run;
- At this entry, GitHub workflow repository ownership and the one-time migration runner remained
  decisions; the later workflow-ownership entry records the subsequent owner confirmation.

Validation:

- PR sequence remains 30 table rows and 30 matching detailed sections;
- PR-plan task references: no unknown task IDs;
- Markdown fence balance and trailing-whitespace scan: passed for all changed documents;
- Terraform format/validate/plan/apply: not applicable / not run;
- AWS verification: not run.

### 2026-07-28 — Confirm Workflow Repository Ownership

Scope:

- assigned Terraform validation/plan/apply, State bootstrap and Working V0 deployment workflows to
  `terraform`;
- assigned Backend Packer and Backend release workflows to `small_backend`;
- assigned Working/Training Packer and Training release workflows to `gpu_ec2`;
- documented the immutable AMI manifest handoff and least-privilege boundary;
- did not create or dispatch a workflow, assume an AWS role, build an AMI, plan/apply, or change
  AWS.

Decision status:

- workflow repository ownership: confirmed;
- exact GitHub org/repository slugs, refs, environments, OIDC subjects and approval rules:
  `[DECISION REQUIRED]`;
- one-time Backend migration runner: `[DECISION REQUIRED]`.

Validation:

- workflow ownership appears consistently in base settings, AWS design, release design, roadmap,
  PR plan and this development record;
- Markdown fence balance and trailing-whitespace scan: passed for all changed documents;
- Terraform/workflow/AWS execution: not run.

### 2026-07-28 — Use Mock AWS Account Inputs Before Live Planning

Scope:

- confirmed that local Terraform development/tests use a test-only 12-digit Account ID;
- required Terraform tests to use `mock_provider "aws"` without AWS credentials;
- kept the real Account ID as a required deployment input with no production default;
- set the transition boundary at `deployment-nonprod` before `VAL-004`, because a real plan reads the named AWS
  account before apply;
- did not create Terraform configuration, credentials, a plan, State or AWS resources.

Safety boundary:

- test Account IDs may exist only in `.tftest.hcl` inputs or dedicated test fixtures;
- test IDs must not enter environment `.tfvars`, backend configuration or workflow environments;
- no live plan/apply may run with a test Account ID.

Validation:

- Mock/live boundary appears consistently in base settings, task map, PR plan, roadmap and this
  development record;
- Markdown fence balance and trailing-whitespace scan: passed for all changed documents;
- Terraform test/validate/plan/apply and AWS verification: not run.

### 2026-07-28 — Implement `foundation-toolchain`

Scope:

- added Terraform artifact and local-secret ignore rules while preserving the provider lock file;
- constrained Terraform CLI to `>= 1.13.3, < 1.14.0` and AWS provider to `~> 6.47.0`;
- configured TFLint `0.64.0`, AWS ruleset `0.48.0`, and Trivy Config `0.72.0`;
- disabled only TFLint's unused-declaration rule while foundation inputs intentionally precede
  their consuming domain resources;
- installed TFLint and Trivy locally through Homebrew;
- did not use AWS credentials, run a live plan/apply, or change AWS.

Command evidence:

- `terraform fmt -check -recursive` -> exit `0`;
- `tflint --init` -> installed AWS ruleset `0.48.0`;
- `tflint --recursive --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero HIGH/CRITICAL Terraform
  misconfigurations using the updated checks bundle;
- `git diff --check` -> exit `0`.

Repository evidence:

- local branch: `codex/foundation-toolchain`;
- parent baseline commit: `43f1d43`;
- remote/GitHub PR: not created because no Git remote is configured.

### 2026-07-28 — Implement `foundation-provider-inputs`

Scope:

- added an AWS provider configured only from required region/account inputs, allowed-account
  validation, and deterministic default tags;
- added typed foundation variables for naming, tags, CIDRs/AZs, capacity, AMIs, IPv6 intent, and
  public-IP safety;
- added deterministic component names, tags, and IPv4 network-range calculations;
- added actionable checks for CIDR containment/non-overlap and Backend/Training capacity;
- added mock-provider valid/invalid tests using test-only Account ID `123456789012`;
- renamed the broad `checks.tf` filename to `foundation_checks.tf`;
- did not use AWS credentials, run a live plan/apply, or change AWS.

Command evidence:

- initial `terraform test -no-color` exposed the unsupported `cidrcontains` function;
- replaced that function with deterministic IPv4 integer-range comparisons;
- final `terraform test -no-color` -> exit `0`, 9 passed, 0 failed;
- `terraform fmt -check -recursive` -> exit `0`;
- `git diff --check` -> exit `0`.

Repository evidence:

- local branch: `codex/foundation-provider-inputs`;
- parent toolchain commit: `c80bf06`;
- remote/GitHub PR: not created because no Git remote is configured.

### 2026-07-28 — Implement `foundation-validation`

Scope:

- initialized the root without a backend after provider configuration existed;
- installed and locked AWS provider `6.47.0` checksums in `.terraform.lock.hcl`;
- ran the full foundation format, validate, mock-test, lint, and configuration-security gate;
- kept `.terraform/` ignored and did not create Terraform State;
- did not use AWS credentials, run a live plan/apply, or change AWS.

Command evidence:

- `terraform init -backend=false` -> exit `0`, AWS provider `6.47.0` installed;
- `terraform fmt -check -recursive` -> exit `0`;
- `terraform validate -no-color` -> exit `0`, configuration valid;
- `terraform test -no-color` -> exit `0`, 9 passed, 0 failed;
- `tflint --recursive --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero HIGH/CRITICAL Terraform
  misconfigurations;
- `git diff --check` -> exit `0`.

Execution boundary:

- `terraform plan`: not run;
- `terraform apply`: not run;
- AWS credentials/API: not used;
- Terraform State/AWS resources: not created.

Repository evidence:

- local branch: `codex/foundation-validation`;
- parent provider-input commit: `cc4e9ff`;
- remote/GitHub PR: not created because no Git remote is configured.

### 2026-07-28 — Implement `state-bootstrap`, `network-vpc-subnets`, and `network-egress-s3-endpoint`

Scope:

- preserved the user-selected `pr04` branch and made no branch, staging, commit, push, or PR
  operation;
- added an independent `bootstrap/state` root with a versioned/private State bucket,
  Terraform-managed rotating KMS key, TLS-only/least-privilege bucket policy, and
  `prevent_destroy`;
- added a partial root S3 backend contract using native S3 lockfiles without DynamoDB;
- added one VPC, six two-AZ subnets, IGW/public routing, and local-only DB route tables;
- added one AZ-A EIP/NAT, two private-application default routes, and a scoped S3 Gateway Endpoint;
- added only semantic Terraform filenames based on State, VPC, subnet/routing, egress, and endpoint
  ownership;
- did not use AWS credentials, run a live plan/apply, create Terraform State, or change AWS.

Input/decision boundary:

- Account IDs, State bucket/principal values, CIDRs, and AZs remain
  required deployment inputs with no live defaults;
- tests use only Account ID `123456789012`, test CIDRs/cross-root IAM ARNs, and
  `mock_provider "aws"`;
- S3 lockfile use and Terraform KMS-key ownership are confirmed; actual key use is granted through
  consumer IAM policies, while real State/network allocations remain owner decisions;
- IPv6 fails locally until subnet allocation, routing, and security controls are explicitly
  designed.

Resource-reference rule:

- resources created in the same Terraform root are connected through direct resource addresses
  such as `aws_kms_key.state.arn`, `aws_s3_bucket.state.arn`, and `aws_vpc.main.id`;
- Mock tests must not feed fake ARN/ID values back into variables when a Terraform resource address
  exists;
- external artifacts and separate-root resources may remain inputs;
- the PR4–6 S3 Endpoint bucket-ARN input was temporary until the product bucket existed.

Command evidence:

- root `terraform init -backend=false -reconfigure` -> exit `0`;
- `bootstrap/state` `terraform init -backend=false` -> exit `0`, provider `6.47.0` locked;
- both roots `terraform validate -no-color` -> exit `0`;
- root `terraform test -no-color` -> exit `0`, 12 passed, 0 failed;
- State `terraform test -no-color` -> exit `0`, 3 passed, 0 failed;
- `tflint --recursive --format compact` -> exit `0`, no issues;
- initial Trivy scan found HIGH `AWS-0132` for SSE-S3; Terraform now creates the customer-managed
  KMS key and the bucket reads its ARN from `aws_kms_key.state.arn`;
- final `trivy config --config trivy.yaml .` -> exit `0`, zero HIGH/CRITICAL
  misconfigurations.

Execution boundary:

- live `terraform plan` / `terraform apply`: not run;
- backend migration, State lock operation, AWS credentials/API: not used;
- AWS resources and real Terraform State: not created.

### 2026-07-28 — Implement `network-private-dns`, `security-groups`, and `data-kms-s3`

Scope:

- preserved the user-selected `pr07_9` branch and made no branch, staging, commit, push, or PR
  operation;
- added a VPC-associated private Route53 zone and semantic network/SG outputs;
- added distinct ALB, Backend, Working, Training, database, and future-interface-endpoint security
  groups using standalone SG-reference rules;
- kept Training ingress empty and exposed public ingress only on ALB ports `80` and `443`;
- added a Terraform-managed rotating product KMS key and a versioned, private, KMS-encrypted
  product S3 bucket with TLS-only policy;
- generated Backend/Working/Training IAM policy JSON from explicit read/write prefix inputs;
- removed the temporary Endpoint bucket-ARN input; the Endpoint policy now directly references
  `aws_s3_bucket.product.arn`, and S3 encryption references `aws_kms_key.product.arn`;
- added no S3 lifecycle rules because retention decisions remain unresolved;
- did not use AWS credentials, run a live plan/apply, create Terraform State, or change AWS.

Input/decision boundary:

- real private-zone name, service/database ports, product bucket name, component prefixes, and KMS
  deletion window remain required deployment inputs with no live defaults;
- product KMS creation/ownership is Terraform-managed; actual use belongs to consumer IAM roles;
- whether Training SQS reuses the product key or gets a separate key remains undecided;
- paid Interface Endpoints remain deferred, so SQS, SSM, Logs, Secrets Manager, and public Backend
  callback paths use TCP `443` through the single NAT.

Security-scan exception:

- Trivy `AVD-AWS-0104` is suppressed only for the Backend, Working, and Training TCP `443` egress
  rules required by the confirmed single-NAT/no-interface-endpoint P1 design;
- the exception permits no other port or protocol;
- it must be removed when approved Interface Endpoints replace the applicable public AWS API
  paths.

Command evidence:

- root `terraform validate -no-color` -> exit `0`;
- root `terraform test -no-color` -> exit `0`, 17 passed, 0 failed;
- `tflint --recursive --format compact` -> exit `0`, no issues;
- initial Trivy scan reported three `AWS-0104` findings for the required TCP `443` NAT paths;
- final `trivy config --config trivy.yaml .` -> exit `0`, zero unsuppressed HIGH/CRITICAL
  misconfigurations and logs exactly three named ignored findings;
- `terraform fmt -check -recursive` and `git diff --check` -> exit `0`.

Execution boundary:

- live `terraform plan` / `terraform apply`: not run;
- AWS credentials/API: not used;
- AWS resources and real Terraform State: not created.

### 2026-07-28 — Implement local PR10–15 structure

Scope:

- preserved the user-selected `pr10_15` branch and made no branch, staging, commit, push, or PR
  operation;
- added a dedicated Terraform-managed rotating Training SQS/DLQ KMS key, encrypted Training queue
  and DLQ, redrive allow policy, explicit queue policy, non-secret outputs, and required
  visibility/renewal/retention/long-poll inputs;
- added exact-subject GitHub OIDC trust and distinct Terraform deploy, Backend/Training Packer,
  Backend/Training release, and Backend/Working/Training runtime roles;
- scoped runtime access to direct product S3, queue KMS/SQS, database KMS/managed-secret resource
  references plus explicitly external Working/Training secret and future log-group inputs;
- isolated unavoidable read/build wildcard permissions in the Packer/release/deploy policies and
  kept `iam:PassRole` limited to direct environment role references;
- added a private PostgreSQL RDS instance, two-AZ database subnet group, parameter group, optional
  Enhanced Monitoring role, Terraform-managed database KMS key, backups/deletion controls, and an
  AWS-managed master password Secret;
- added `BACKEND_MIGRATION_RUNBOOK.md` as the PR15 singleton migration and rollout-gate contract;
  no executable migration workflow was invented because its owner and lock platform remain
  unresolved.

Input and ownership boundary:

- real AWS account ID, GitHub organization/repositories/exact OIDC subjects, SQS timing, external
  secret/log ARNs, future Launch Template/ASG names, and RDS sizing/version/retention values remain
  required deployment inputs with no live defaults;
- Mock tests use Account ID `123456789012`, `example-org`, fake but syntactically valid external
  ARNs, and `mock_provider "aws"` only;
- Training SQS/DLQ now uses its own Terraform-managed key; RDS/storage/managed-secret encryption
  uses a separate Terraform-managed database key;
- resources present in this root use `aws_*.<semantic_name>.arn` or `.id`; remaining constructed
  LT/ASG ARNs and ARN variables identify external or future-PR resources and must be replaced with
  direct references when their resources are added;
- Packer/release role activation remains blocked on EXT-03;
- migration execution owner, singleton-lock implementation, and workflow location remain
  `[DECISION REQUIRED]`.

Command evidence:

- `terraform fmt -check -recursive` -> exit `0`;
- root `terraform validate -no-color` -> exit `0`;
- root `terraform test -no-color` -> exit `0`, 20 passed, 0 failed;
- `tflint --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero unsuppressed HIGH/CRITICAL
  misconfigurations and exactly the three previously documented TCP `443` NAT egress ignores;
- `git diff --check` -> exit `0`;
- local validation required running the provider/scanner processes outside the filesystem sandbox;
  it did not read AWS credentials or contact AWS APIs.

Execution boundary:

- live `terraform plan` / `terraform apply`: not run;
- database migration and GitHub workflow: not created or run;
- AWS credentials/API: not used;
- AWS resources and real Terraform State: not created.

### 2026-07-28 — Implement local PR16–20 compute and scaling structure

Scope:

- preserved the user-selected `pr16_20` branch and made no branch, staging, commit, push, or PR
  operation;
- added the Backend Launch Template, private two-subnet ASG, target group, internet-facing ALB,
  HTTPS listener, redirect-only HTTP listener, public Route53 alias, and release-preference output;
- added Working V0 as exactly one private `aws_instance` with encrypted root/cache EBS, IMDSv2,
  dedicated runtime profile/SG, and private Route53 A record;
- added the Training hardened Launch Template, On-Demand-only private ASG, termination lifecycle
  hook, direct own-ASG lifecycle/protection IAM, and SQS backlog-per-InService scaling alarms;
- changed Backend/Training release IAM and Training lifecycle IAM from future constructed ARNs to
  direct Terraform resource references;
- added semantic component files and separate Backend/Working/Training runtime templates; no
  numbered or history-based Terraform filenames were introduced.

Runtime and ownership boundary:

- Backend and Training ASGs consume LT `$Default`; both LTs keep
  `update_default_version = false`, ignore only release-owned `image_id`, and leave structural
  fields visible to Terraform;
- Terraform has no automatic Backend `instance_refresh` block. Reviewed preferences are an output
  for the future Backend release workflow; no refresh is started by local validation;
- Working still has no Launch Template, ASG, target group, ALB, public IP, or SSH configuration;
- Training has no Mixed Instances Policy, Spot capacity, public listener, or routine Instance
  Refresh;
- Training ignores only autoscaling-owned `desired_capacity` drift; Terraform continues to own
  min/max and every other ASG structural field;
- scale-from-zero metric math uses visible queue messages directly when InService worker count is
  zero; all periods, thresholds, adjustments, cooldowns, warmup, and lifecycle results are
  required inputs rather than deployment defaults;
- runtime templates write only non-secret identifiers and configuration. Database/callback/API-key
  values remain runtime-resolved from their secret ARNs.

Mock and external blockers:

- Account ID `123456789012`, fake AMIs/domain/certificate/commit/digest, instance types, sizes,
  health values, lifecycle values, and scaling thresholds exist only in `.tftest.hcl`;
- real Backend/Working/Training AMIs, systemd units, health paths, runtime consumption, GPU sizes,
  certificate/domain, and measured scaling inputs remain unverified;
- Backend/Training message, callback and control alignment (EXT-01), Training protection/hook
  completion evidence (EXT-02), release ownership governance (EXT-03), and Working/Training AMI
  evidence (EXT-04) remain blockers;
- the Backend numeric-LT-version document and GPU Terraform-sole-writer document still conflict
  with the approved `$Default` field ownership. No release workflow/role activation is claimed.

Security-scan exception:

- Trivy `AVD-AWS-0053` is suppressed only on `aws_lb.backend`, because the confirmed topology
  requires one internet-facing Backend ALB;
- the ALB forwards only through its SG to the private Backend target group; Working, Training,
  RDS, and application EC2 remain private;
- the existing three `AVD-AWS-0104` ignores remain limited to the documented TCP `443` NAT egress
  rules.

Command evidence:

- root `terraform validate -no-color` -> exit `0`;
- root `terraform test -no-color` -> exit `0`, 22 passed, 0 failed;
- `terraform fmt -check -recursive` -> exit `0`;
- `tflint --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero unsuppressed HIGH/CRITICAL
  misconfigurations and exactly four documented ignores (three TCP `443` NAT egress rules and the
  sole public Backend ALB);
- `git diff --check` -> exit `0`;
- live `terraform plan`, drift tests, AMI validation, runtime smoke, callback test, scale-from-zero
  test, and lifecycle test: not run.

Execution boundary:

- live `terraform plan` / `terraform apply`: not run;
- Instance Refresh, GitHub workflow, Packer, lifecycle action, and scaling action: not run;
- AWS credentials/API: not used;
- AWS resources and real Terraform State: not created.

### 2026-07-28 — Implement local PR21–28 Terraform-owned boundary

Scope:

- added required, validated observability inputs without live-environment defaults;
- added a rotating Terraform-managed CloudWatch Logs KMS key, encrypted Backend/Working/Training
  log groups, encrypted VPC Flow Log group, least-privilege Flow Log role/policy and VPC Flow Log;
- changed runtime log IAM from external/mock log ARNs to direct Terraform log-group references;
- added direct-resource SQS depth/age/DLQ, Backend ALB/capacity, Working EC2, RDS and NAT alarms;
- enabled Backend/Training ASG capacity metrics used by scaling, alarms and the shared dashboard;
- added the shared ALB/SQS/ASG/RDS/Working/NAT dashboard, monthly Budget and Cost Anomaly monitor;
- added the required `Deployment` tag used by the scoped Budget filter;
- added Mock assertions for log-key rotation, retention, flow scope, queue/capacity alarms,
  ASG metrics and dashboard naming, plus an invalid-retention case;
- documented SSM/no-SSH access, single-NAT outage, future two-NAT upgrade/rollback, retention and
  deletion safety in `OPERATIONS_RUNBOOK.md`;
- documented Backend saved-plan review and Working replacement/DNS/downtime/rollback evidence in
  `SERVICE_VALIDATION_RUNBOOK.md`;
- documented repository ownership, direct-resource reference rules, Working plan/apply gates,
  concurrency/stale-default/rollback rules and static/live drift cases in
  `RELEASE_WORKFLOW_CONTRACT.md`.

Ownership and incomplete service metrics:

- PR24 Backend workflow remains owned by `small_backend`; PR25 Training workflow remains owned by
  `gpu_ec2`; neither external repository was changed;
- no executable Working deploy workflow was invented because `DEC-012` lacks the real GitHub
  Environment approval rule, backend-config delivery, complete variable delivery and protected
  saved-plan policy;
- Terraform implements infrastructure-native metrics only. GPU, disk, process, request, lifecycle,
  callback and job-result metrics remain consumer-runtime responsibilities and are explicitly
  recorded as partial rather than fabricated;
- alarm action ARNs and cost email recipients are required external inputs because this root does
  not own the notification topic/recipients; their test values remain Mock-only;
- same-root KMS, S3, SQS, RDS, LT, ASG and Log Group identifiers are direct Terraform resource
  references. Hand-written identifiers remain only for external secrets/topics/certificates/zones
  and tests.

Command evidence:

- `terraform validate -no-color` -> exit `0`;
- `terraform test -no-color` -> exit `0`, 23 passed, 0 failed with `mock_provider "aws"`;
- `terraform fmt -check -recursive` -> exit `0`;
- `tflint --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero unsuppressed HIGH/CRITICAL
  misconfigurations and exactly four documented ignores (three TCP `443` NAT egress rules and the
  sole public Backend ALB);
- `git diff --check` -> exit `0`;
- local provider/TFLint processes required execution outside the filesystem sandbox; no AWS
  credentials or AWS API were used.

Execution boundary:

- live State bootstrap/migration and live `terraform plan` / `terraform apply`: not run;
- GitHub workflow dispatch/mutation, Packer, LT promotion, Instance Refresh, scaling, lifecycle
  completion, Working replacement and DNS propagation test: not run;
- PR29/30 cannot begin without the real Account ID, region, environment, backend values, complete
  owner-approved Terraform inputs, credentials and explicit authorization;
- AWS resources and real Terraform State: not created or changed;
- branch remained `pr16_20`; no branch, staging, commit, push or PR operation was performed.

### 2026-08-24 — Add bilingual repository README and implementation architecture guide

Scope:

- added `README.md` and `README.zh-CN.md` with reciprocal language navigation;
- documented the implemented Backend, Working/Serving V0, and Training compute models;
- added Mermaid diagrams for the full AWS topology, SQS-to-ASG Training sequence, and Backend
  ALB/ASG target lifecycle;
- documented the exact SQS scale-from-zero metric expression, queue reliability behavior,
  Training scale-in protection, Backend health replacement/draining, and AMI ownership model;
- inventoried the Terraform-managed network, edge, compute, data, messaging, IAM, observability,
  cost, State, and operations resources;
- inspected the sibling Backend/GPU implementation to distinguish the implemented
  `SetInstanceProtection` path from the still-absent direct runtime lifecycle-hook heartbeat and
  completion calls, and retained the existing SQS/callback contract-alignment boundary;
- did not copy `gpu_ec2/routeMap/design/image.png` because it combines the current Working V0 with
  a future Working V1 internal-ALB/ASG topology and would misrepresent this repository's deployed
  shape;
- did not change Terraform resources, service contracts, workflows, State, or AWS.

Status boundary:

- the READMEs describe the Terraform resource graph as implemented in this repository;
- they explicitly separate repository implementation from live AWS deployment/verification;
- they do not claim that lifecycle-hook completion, real SQS scaling, ALB replacement, AMI
  rollout, plan, apply, or AWS smoke tests ran.

Validation:

- `git diff --check` -> exit `0`;
- README Markdown fence parity, local-link target existence, and critical SQS/protection/ALB term
  checks -> exit `0`;
- `terraform fmt -check -recursive` -> exit `0`;
- sandboxed `terraform validate -no-color` could not start the already-installed AWS provider;
  rerunning the same local validation outside the filesystem sandbox -> exit `0`, configuration
  valid, with no AWS credentials/API use;
- `terraform test -no-color` -> exit `0`, 23 passed and 0 failed with `mock_provider "aws"`;
- `tflint --recursive --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero misconfigurations and the same four
  documented ignores (three HTTPS NAT-egress rules and the sole public Backend ALB);
- live `terraform plan` / `terraform apply`: not run;
- AWS credentials/API and AWS resources: not used or changed.

### 2026-08-24 — Consolidate Terraform root files by infrastructure domain

Scope:

- reduced the root Terraform file count from 64 to 16 without changing resource addresses,
  variable names, output names, expressions, lifecycle settings, policies, or provider/backend
  contracts;
- consolidated network resources, inputs, locals and outputs into `network.tf`;
- consolidated security groups and rules into `security.tf`;
- consolidated product S3/KMS/policies into `data_storage.tf`;
- consolidated Training SQS/DLQ/KMS/policies into `messaging.tf`;
- consolidated PostgreSQL RDS/KMS into `database.tf`;
- consolidated OIDC, workflow, runtime, deploy, Packer and release IAM into `iam.tf`;
- consolidated Backend, Working and Training resources into `backend_compute.tf`,
  `working_compute.tf` and `training_compute.tf` respectively;
- consolidated logs, Flow Logs, alarms, dashboard and cost controls into `observability.tf`;
- kept `backend.tf`, `versions.tf`, `providers.tf`, `variables.tf`, `locals.tf`, and
  `foundation_checks.tf` separate because they are cross-domain root contracts;
- kept the independent `bootstrap/state` root unchanged;
- updated both READMEs and `TERRAFORM_AWS_DESIGN.md` to match the consolidated layout;
- did not change AWS topology, runtime contracts, IAM authority, State, workflows, or live AWS.

Validation:

- root `.tf` inventory -> reduced from 64 files to 16 files; `bootstrap/state` remained unchanged;
- declaration inventory comparison against `HEAD` for every root/bootstrap `resource`, `data`,
  `variable`, `output`, and `check` header -> no differences;
- `git diff --check` -> exit `0`;
- `terraform fmt -check -recursive` -> exit `0`;
- sandboxed `terraform validate -no-color` could not start the already-installed AWS provider;
  rerunning outside the filesystem sandbox -> exit `0`, configuration valid, with no AWS
  credentials/API use;
- `terraform test -no-color` -> exit `0`, 23 passed and 0 failed with `mock_provider "aws"`;
- `tflint --recursive --format compact` -> exit `0`, no issues;
- `trivy config --config trivy.yaml .` -> exit `0`, zero misconfigurations and the same four
  documented ignores, now at their consolidated file locations;
- live `terraform plan` / `terraform apply`: not run;
- AWS credentials/API and AWS resources: not used or changed.

## Evidence Rules

Each future entry records:

- date, branch, and commit/PR when one exists;
- scope and files changed;
- architecture/contract decisions;
- commands run and exact outcomes;
- plan/apply environment and artifact reference when authorized;
- resources built/deployed and verification evidence;
- blockers, assumptions, and rollback notes.
