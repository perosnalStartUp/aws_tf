# Terraform AWS P1 Detailed Task Breakdown

Status: implementation task map. Except where explicitly marked completed, these tasks are planned
or blocked and do not represent deployed AWS resources.

## 1. How to Use This File

- Use one task ID as the normal unit of implementation and review.
- A task may share a PR with adjacent tasks only when their plan and rollback surface are the same.
- Use `TERRAFORM_P1_PR_PLAN.md` as the authoritative mapping from these task IDs to proposed PR
  review surfaces.
- Resolve only the decision gates required by the next task group.
- Every material task updates `TERRAFORM_DEV_DOC.md`.
- Architecture changes update `TERRAFORM_AWS_DESIGN.md`.
- AMI/LT/ASG release changes update `AMI_ASG_RELEASE_DESIGN.md`.
- Local validation is not deployment evidence.
- `plan`, `apply`, state mutation, Packer builds, workflow dispatch, and AWS mutations require the
  execution authorization defined in root `AGENTS.md`.

Status values:

- **Completed locally**: files/command evidence exist locally.
- **Ready**: dependencies and owner decisions are available.
- **Planned**: task is defined but an earlier implementation dependency remains.
- **Blocked**: a named decision or cross-repository contract is missing.
- **Requires authorization**: implementation is ready but the action changes or reads a named live
  environment.

## 2. Confirmed Inputs

- Terraform binary currently available: `v1.13.3` on `darwin_arm64`.
- Frontend remains on Vercel.
- Backend: private ASG across two private application subnets, public ALB, initial `desired = 1`.
- Working V0: exactly one private EC2, Route53 private DNS, no LT/ASG/ALB.
- Training: private On-Demand ASG, SQS-driven, no public listener.
- Two-AZ topology for ALB/ASG/RDS subnet coverage.
- One public NAT Gateway in AZ-A for the first low-cost version.
- Both private application subnets use the single NAT for non-S3 IPv4 egress.
- S3 uses a Gateway Endpoint; paid interface endpoints are deferred.
- Training calls the public Backend ALB URL through NAT.
- Backend and Training routine AMI releases use the approved `$Default` pointer model.
- Working AMI replacement is Terraform-managed.

## 3. Decision Gates

| ID | Required decision | Blocks | Status |
| --- | --- | --- | --- |
| DEC-001 | AWS account ID(s), region, environment names | provider, state, all regional resources | `[PARTIALLY CONFIRMED]` local work uses a test ID with Mock AWS; real ID required before `VAL-004`; region/environments remain required |
| DEC-002 | Project prefix, owner/cost tags, environment naming rules | resource names, default tags | `[DECISION REQUIRED]` |
| DEC-003 | VPC CIDR, exact AZ names, six subnet CIDRs, IPv6 choice | network | `[DECISION REQUIRED]` |
| DEC-004 | State bucket name/key convention, bootstrap owner, locking method | remote backend | `[DECISION REQUIRED]` |
| DEC-005 | Public domain, certificate ownership, ALB listeners, Backend port/health path | Backend ALB | `[DECISION REQUIRED]` |
| DEC-006 | Backend AMI, instance type, min/max, warmup and refresh preferences | Backend compute | `[DECISION REQUIRED]` |
| DEC-007 | Working AMI, GPU type, subnet/AZ, port, disks/cache, auth and DNS name | Working compute | `[DECISION REQUIRED]` |
| DEC-008 | Training AMI/GPU type, min/desired/max, queue timing and job duration | Training compute/scaling | `[DECISION REQUIRED]` |
| DEC-009 | KMS key split, S3 retention, SQS redrive/retention, log retention | data/monitoring | `[DECISION REQUIRED]` |
| DEC-010 | RDS engine/version/class/storage/Multi-AZ/backups/deletion policy and credential owner | RDS | `[DECISION REQUIRED]` |
| DEC-011 | Exact GitHub org/repo slugs, refs/environments and approval rules for the confirmed workflow owners | workflow IAM | `[PARTIALLY CONFIRMED]` repository ownership decided 2026-07-28 |
| DEC-012 | Terraform deploy execution details and approval boundary within the confirmed `terraform` repository ownership | deploy IAM/workflow | `[PARTIALLY CONFIRMED]` repository ownership decided 2026-07-28 |

## 4. Dependency Overview

```mermaid
flowchart LR
    Decisions["Decision gates"] --> Foundation["Foundation and provider"]
    Foundation --> State["Remote state"]
    Foundation --> Network["VPC and routing"]
    Network --> Security["Security groups and IAM"]
    Network --> Data["KMS / S3 / SQS / RDS"]
    Security --> Backend["Backend ALB / ASG"]
    Security --> Working["Working V0 EC2"]
    Security --> Training["Training ASG"]
    Data --> Backend
    Data --> Working
    Data --> Training
    Backend --> Release["AMI release workflows"]
    Training --> Release
    Working --> Release
    Backend --> Observability["Monitoring"]
    Working --> Observability
    Training --> Observability
    Release --> Nonprod["Nonproduction plan/apply"]
    Observability --> Nonprod
```

## 5. Repository and Terraform Foundation

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| FND-000 | Run Terraform initialization in the empty repository and record the actual result. | none | **Completed locally 2026-07-27**: Terraform v1.13.3 returned `Terraform initialized in an empty directory!`; no configuration/provider/backend was initialized. |
| FND-001 | Add `.gitignore` entries for `.terraform/`, state/backup files, plan artifacts, crash logs, override files, and local secret tfvars while preserving the provider lock file. | none | **Completed locally 2026-07-28**: ignore rules cover generated/state/plan/secret artifacts and explicitly retain `.terraform.lock.hcl`. |
| FND-002 | Create `versions.tf` with an approved Terraform constraint and pinned-compatible AWS provider constraint. | DEC-001 | **Completed locally 2026-07-28**: Terraform is constrained to `>= 1.13.3, < 1.14.0`; AWS provider to `~> 6.47.0`; format check passed. |
| FND-003 | Create `providers.tf` with the selected region, allowed-account validation, and default tags. | DEC-001, DEC-002, FND-002 | **Completed locally 2026-07-28**: provider has no credentials, requires region/account inputs, restricts allowed account IDs, and applies deterministic default tags. |
| FND-004 | Create typed common variables for project, environment, region, account, tags, CIDRs, and feature switches. | DEC-001, DEC-002, DEC-003 | **Completed locally 2026-07-28**: typed, described and validated foundation inputs exist with no live-environment defaults. |
| FND-005 | Create `locals.tf` for normalized names, merged tags, service identifiers, and repeated constants. | FND-004 | **Completed locally 2026-07-28**: names/tags and IPv4 CIDR ranges are deterministic. |
| FND-006 | Add Terraform `check`/precondition rules for account, CIDR non-overlap, two distinct AZs, capacity bounds, exact AMI format, and no public EC2 assignment. | FND-004 | **Completed locally 2026-07-28**: valid and invalid fixtures passed 9 mock-provider tests, including CIDR containment/overlap and capacity/public-IP failures. |
| FND-007 | Re-run `terraform init` after provider configuration and commit the generated `.terraform.lock.hcl`. | FND-002, FND-003 | Init succeeds, provider checksum lock exists, `.terraform/` remains ignored. |
| FND-008 | Run baseline `terraform fmt -check -recursive` and `terraform validate`; record exact versions/results. | FND-007 | Both commands pass or blockers are recorded without claiming success. |

## 6. State Bootstrap and Access

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| STATE-001 | Write the state bootstrap decision: bucket name, region, key layout, encryption key, locking, versioning, recovery, break-glass owner, and environment separation. | DEC-001, DEC-004 | Reviewed decision contains no secret values and defines recovery responsibility. |
| STATE-002 | Use a separate Terraform root at `bootstrap/state`; prevent dependency on the backend it creates. | STATE-001 | **Decision confirmed 2026-07-28**: independently initialized root in this repository; implementation and teardown/recovery controls remain `state-bootstrap` work. |
| STATE-003 | Implement the bootstrap configuration with S3 encryption, versioning, public-access block, TLS-only policy, and least-privilege access. | STATE-002 | Local init/validate passes; no live bucket is claimed. |
| STATE-004 | Create the environment backend configuration and document partial backend arguments that must be supplied outside Git. | STATE-003 | No credential or secret is embedded; key naming separates environments. |
| STATE-005 | Provision/bootstrap the state resources in the named account. | STATE-003 | **Requires explicit authorization**; resource IDs and command evidence recorded. |
| STATE-006 | Reinitialize/migrate the root state to the remote backend and verify locking/version recovery. | STATE-004, STATE-005 | **Requires explicit authorization**; migration and lock test evidence recorded. |

## 7. VPC, Subnets, Routing, and DNS Foundation

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| NET-001 | Record the selected VPC/AZ/subnet CIDR map and prove that all six subnet CIDRs are contained and non-overlapping. | DEC-003, FND-004 | CIDR table and Terraform validations agree. |
| NET-002 | Implement VPC with DNS support/hostnames enabled and required tags. | NET-001 | VPC validates; no default resource is treated as an implicit dependency. |
| NET-003 | Implement two public subnets, one in each selected AZ, with public-IP auto-assignment disabled by default. | NET-002 | Both subnets are distinct, tagged, and intended only for ALB/NAT. |
| NET-004 | Implement two private application subnets for Backend/Working/Training. | NET-002 | No public-IP auto-assignment; both ASGs can consume the subnet list. |
| NET-005 | Implement two private DB subnets reserved for RDS. | NET-002 | RDS subnet group prerequisites are met; no internet default route. |
| NET-006 | Implement and attach the Internet Gateway plus public route table and `0.0.0.0/0 -> IGW`. | NET-003 | Both public subnets are associated with the intended route table. |
| NET-007 | Allocate one EIP and implement the single public NAT Gateway in AZ-A. | NET-006 | NAT exists only in the selected AZ-A public subnet; low-cost failure domain is documented. |
| NET-008 | Implement private application route tables for both AZs with `0.0.0.0/0 -> single NAT`. | NET-004, NET-007 | Both application subnets use the NAT; cross-AZ route is visible in review. |
| NET-009 | Implement DB route table associations with local-only routing unless a later RDS requirement is approved. | NET-005 | DB subnets have no IGW/NAT default route. |
| NET-010 | Implement the S3 Gateway Endpoint and associate it with both private application route tables. | NET-008 | S3 prefix-list routes avoid NAT; endpoint policy scope is reviewed. |
| NET-011 | Implement Route53 private hosted zone association for the VPC. | NET-002, DEC-007 | Zone name is explicit; VPC DNS resolution is enabled. |
| NET-012 | Add network outputs: VPC ID, subnet IDs by class/AZ, route table IDs, NAT EIP, and private zone ID. | NET-003 through NET-011 | Outputs contain identifiers only and no sensitive values. |
| NET-013 | Add VPC Flow Logs destination/role after retention and destination are decided. | DEC-009, NET-002 | Flow logs are enabled without exposing application secrets. |

## 8. Security Groups and IAM Foundation

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| SG-001 | Create separate ALB, Backend, Working, Training, RDS, and endpoint security groups with no implicit default-SG use. | NET-002 | Each resource class has an explicit SG and description. |
| SG-002 | Allow public ALB ingress on HTTPS 443 and HTTP 80 for redirect-only traffic. | DEC-005, SG-001 | Port 80 has only an HTTP-to-HTTPS redirect listener; no application EC2 receives public ingress. |
| SG-003 | Allow ALB SG to Backend SG on application and health-check ports only. | DEC-005, SG-001 | Backend ingress source is the ALB SG, not a broad CIDR. |
| SG-004 | Allow Backend SG to Working SG on the confirmed private inference port only. | DEC-007, SG-001 | Working has no other application ingress. |
| SG-005 | Keep Training application ingress empty; define only required HTTPS/DNS egress. | SG-001 | No SSH or service listener is reachable from ALB/internet. |
| SG-006 | Allow Backend SG to RDS SG on the selected PostgreSQL engine port only. | DEC-010, SG-001 | Working/Training have no RDS rule. |
| SG-007 | Encode runtime HTTPS egress through NAT/S3 endpoint without pretending the public callback preserves Training SG identity. | SG-001, NET-010 | Public ALB callback relies on TLS/application auth; SG comments explain NAT source translation. |
| IAM-001 | Implement the Terraform deploy policy boundary for one environment, including narrowly scoped `iam:PassRole`. | DEC-012, FND-005 | Policy review identifies unavoidable wildcard `Describe*` actions separately. |
| IAM-002 | Implement Backend runtime role/profile for S3 prefixes, SQS send, approved DB secret, KMS, logs/metrics, and SSM. | DATA-001 through DATA-007 | No Training lifecycle, Working secret, or workflow mutation permissions. |
| IAM-003 | Implement Working runtime role/profile for approved S3/KMS prefixes, optional auth secret, logs/metrics, and SSM. | DEC-007, DATA-001 through DATA-004 | No SQS, RDS, or LT/ASG mutation permissions. |
| IAM-004 | Implement Training runtime role/profile for SQS consume/visibility/delete, approved S3/KMS, callback secret, logs/metrics, SSM, and required ASG lifecycle calls. | DEC-008, DATA-001 through DATA-007 | Secret scope is one approved ARN; no RDS or general EC2 mutation. |
| IAM-005 | Implement GitHub OIDC provider/trust conditions without long-lived access keys. | DEC-011 | Repository, ref/environment, audience, and subject conditions are explicit. |
| IAM-006 | Implement separate Backend/Training Packer and release roles; do not combine build, release, deploy, or runtime authority. | IAM-005, RELEASE-001 | Mutation actions are scoped to the component LT/ASG and release design. |
| IAM-007 | Add IAM policy tests/review for wildcard resources, KMS encryption context, secret scope, `iam:PassRole`, LT/ASG mutations, and public access. | IAM-001 through IAM-006 | Review findings are resolved or recorded as accepted exceptions. |

## 9. Encryption, S3, SQS, Secrets, and RDS

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| DATA-001 | Decide and implement the KMS key/alias model for product S3, Training SQS, and other approved encrypted resources. | DEC-009, FND-005 | Key policies avoid account-wide runtime administration and support required service grants. |
| DATA-002 | Implement product S3 bucket with versioning, KMS default encryption, ownership controls, and public-access block. | DATA-001 | Bucket validates with no public ACL/policy path. |
| DATA-003 | Implement TLS-only bucket policy and component/prefix policy documents. | DATA-002 | Insecure transport is denied; Backend/Working/Training prefixes are explicit. |
| DATA-004 | Implement only approved lifecycle/retention rules for datasets, logs, checkpoints, and adapters. | DEC-009, DATA-002 | Durable adapters/datasets are not deleted by an assumed default. |
| DATA-005 | Implement KMS-encrypted Training queue and DLQ. | DEC-008, DEC-009, DATA-001 | Queue URLs/ARNs output; no secret; DLQ exists. |
| DATA-006 | Implement redrive, visibility, retention, long polling, receive count, and queue policy from the runtime contract. | DATA-005 | Timing values are validated against max job/renewal behavior. |
| DATA-007 | Add SQS/DLQ alarms for visible age/count and dead-letter arrival. | DATA-005, OBS-001 | Alarm thresholds/destinations are owner-approved. |
| RDS-001 | Implement private DB subnet group across the two DB subnets. | NET-005 | Both selected AZs are represented. |
| RDS-002 | Implement encrypted PostgreSQL RDS configuration from the approved engine/class/storage/backup decisions. | DEC-010, DATA-001, RDS-001, SG-006 | `publicly_accessible = false`; deletion/backup behavior is explicit. |
| RDS-003 | Implement parameter/option/log export/monitoring settings required by the Backend. | DEC-010, RDS-002 | Settings match the chosen engine version and are documented. |
| RDS-004 | Integrate an existing/managed credential secret by ARN without passing the secret value through Terraform state. | DEC-010, RDS-002 | Terraform outputs only the approved identifier; runtime retrieves the value. |
| RDS-005 | Define the one-time migration runner/release step; prohibit migrations from every ASG instance startup. | Backend contract decision, RDS-002 | Execution owner, ordering, failure and retry behavior are documented. |

## 10. Backend ALB and ASG

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| BE-001 | Freeze Backend runtime inputs: exact AMI, port, health path, instance type, min/max, desired=1, warmup and refresh values. | DEC-005, DEC-006 | Inputs are recorded and validated; exact AMI only. |
| BE-002 | Define non-secret Backend user data/runtime environment identifiers for RDS, S3, SQS, Working DNS, logs, and environment. | BE-001, RDS-004, DATA-002, DATA-005, NET-011 | No password/token/secret value enters user data or state. |
| BE-003 | Implement Backend Launch Template structure: exact bootstrap AMI, instance profile, SG, IMDSv2, encrypted EBS, user data and tags. | BE-002, IAM-002, SG-003 | `update_default_version = false`; structural fields remain Terraform-owned. |
| BE-004 | Implement target group, health checks, deregistration delay, and Backend ASG across both private application subnets. | BE-003, NET-004 | Initial `desired = 1`; min/max validation; target group attachment works in plan. |
| BE-005 | Implement internet-facing ALB across both public subnets with ALB SG. | DEC-005, NET-003, SG-002 | ALB is the only public application entry point. |
| BE-006 | Implement HTTPS listener/certificate and optional HTTP-to-HTTPS redirect; add public DNS record. | DEC-005, BE-005 | TLS/domain ownership is explicit; no plaintext application listener remains. |
| BE-007 | Configure ASG to consume LT `$Default` and define safe Instance Refresh preferences. | BE-004 | Terraform does not reset workflow-owned AMI/default; health gates are explicit. |
| BE-008 | Add Backend/ALB alarms and logs for target health, 5xx, latency, instance status, ASG capacity and refresh failures. | BE-004, BE-005, OBS-001 | Alarms have destinations and tested dimensions. |
| BE-009 | Validate the one-time migration path before Backend rollout. | RDS-005, BE-007 | Migration does not race from multiple ASG instances. |
| BE-010 | Perform local Backend plan review for public exposure, replacement, LT lifecycle, desired=1, RDS access and outputs. | BE-001 through BE-009, VAL-001 | Saved plan only after live-plan authorization; review checklist recorded. |

## 11. GPU Working V0

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| WK-001 | Resolve Working host packaging/AMI blocker and freeze exact AMI, GPU type, port, disk/cache, auth, subnet/AZ and DNS inputs. | DEC-007, GPU repository evidence | AMI/build evidence exists; no unbounded AMI lookup. |
| WK-002 | Define non-secret Working runtime configuration and secret identifiers required by `INTEGRATION_CONTRACTS.md`. | WK-001, DATA-002, IAM-003 | Secret values are runtime-resolved, not in user data/state. |
| WK-003 | Implement one private `aws_instance` with exact AMI, Working SG/profile, IMDSv2 and encrypted volumes. | WK-002, NET-004, SG-004, IAM-003 | Exactly one instance; no LT, ASG, target group, public IP or SSH. |
| WK-004 | Implement Route53 private A record and replacement dependency behavior. | WK-003, NET-011 | Backend resolves the stable name to the current private address. |
| WK-005 | Add Working status/GPU/disk/process/request/log alarms. | WK-003, OBS-001 | Thresholds and destinations are explicit. |
| WK-006 | Document and test the Terraform AMI replacement/rollback sequence, including DNS update and expected downtime. | WK-004 | Nonproduction evidence records old/new instance and AMI IDs; requires apply authorization. |
| WK-007 | Verify Backend-to-Working SG/DNS/application path and deny public/Training access. | WK-004, BE-004 | **Requires deployed nonproduction environment**; connectivity/denial evidence recorded. |

## 12. GPU Training ASG and SQS Scaling

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| TR-001 | Align Backend message schema, model identity, callback auth/body, exact replay, and job-control endpoint with Training. | cross-repository blocker | Backend and GPU design/tests agree; otherwise remaining Training deployment tasks stay blocked. |
| TR-002 | Implement and test Training scale-in protection plus termination lifecycle-hook completion path in the runtime. | cross-repository blocker | Runtime evidence covers success, failure, retry, timeout and shutdown. |
| TR-003 | Produce/verify exact Training AMI and freeze GPU type, min/desired/max, job duration, queue visibility/renewal and callback inputs. | DEC-008, TR-001, TR-002 | Real AMI/runtime evidence exists; initial capacity remains On-Demand. |
| TR-004 | Define non-secret Training runtime configuration and callback secret ARN/field. | TR-003, DATA-005, IAM-004 | All names in `INTEGRATION_CONTRACTS.md` are supplied without secret values. |
| TR-005 | Implement Training Launch Template with exact bootstrap AMI, role, SG, IMDSv2, encrypted EBS, user data and tags. | TR-004, NET-004, SG-005, IAM-004 | `update_default_version = false`; no public IP/listener. |
| TR-006 | Implement Training ASG across private application subnets with On-Demand instances and confirmed min/desired/max. | TR-005 | ASG consumes `$Default`; no routine Instance Refresh. |
| TR-007 | Implement termination lifecycle hook, heartbeat timeout, default result, notification/event path, and runtime permissions. | TR-002, TR-006 | Terraform and runtime completion action names/timeouts agree. |
| TR-008 | Implement scale-in protection permissions and document the exact set/remove boundaries. | TR-002, IAM-004, TR-006 | Active jobs are protected; idle/completed workers can terminate. |
| TR-009 | Implement SQS backlog-per-InService-instance metric math and scaling policy, including scale-from-zero behavior. | DATA-006, TR-006 | Scaling thresholds derive from acceptable latency/job throughput, not arbitrary defaults. |
| TR-010 | Configure `TRAINING_BACKEND_BASE_URL` to the public Backend domain and validate the NAT callback route. | BE-006, NET-008, TR-004 | HTTPS callback succeeds through NAT/ALB; Training remains unreachable inbound. |
| TR-011 | Add Training alarms/logging for queue age/DLQ, ASG capacity, lifecycle timeout, GPU/disk, callback failure and job outcome. | TR-006 through TR-010, OBS-001 | Alarm dimensions/actions are correct and no secret is logged. |
| TR-012 | Validate that `$Default` promotion affects new scale-outs without terminating protected mixed-version workers. | TR-006, RELEASE-004 | Requires nonproduction release authorization and recorded instance AMI/LT/lifecycle evidence. |

## 13. Observability, Cost, and Operations

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| OBS-001 | Decide notification destinations, log retention, alarm severity conventions, dashboard scope and budget thresholds. | DEC-009 | Values and ownership are recorded. |
| OBS-002 | Implement component log groups with encryption/retention and explicit names. | OBS-001, DATA-001 | Runtime roles can write only their own approved logs. |
| OBS-003 | Implement shared CloudWatch dashboard for ALB/Backend, RDS, Working, Training, SQS/DLQ and NAT. | service alarms | Dashboard references real resource dimensions. |
| OBS-004 | Implement NAT health/traffic/error alarms and cost visibility for the accepted single-NAT design. | NET-007, OBS-001 | NAT failure and unexpected data processing are observable. |
| OBS-005 | Implement AWS Budget/Cost Anomaly alerts after account recipients/thresholds are approved. | DEC-001, OBS-001 | Alert recipients and thresholds are not placeholders. |
| OPS-001 | Write SSM access runbook with IAM session control and no inbound SSH. | IAM runtime roles | Operators can identify the command path and audit location. |
| OPS-002 | Write single-NAT outage behavior and future two-NAT upgrade/rollback runbook. | NET-007 | Expected S3-versus-public API behavior is documented. |
| OPS-003 | Write resource deletion/retention runbook for RDS, S3, AMIs, snapshots, logs and state. | data decisions | No destructive operation is presented as automatic. |

## 14. AMI Build and Release Integration

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| RELEASE-001 | Synchronize GPU governance from “Terraform sole LT/ASG writer” to the approved field-scoped `$Default` workflow model. | owner-approved design | GPU design/dev docs and Terraform release design no longer conflict. |
| RELEASE-002 | Standardize Packer manifest output: exact AMI ID, account/region, component, commit, build run, architecture, container digest and checks actually run. | component build repositories | Release consumes the manifest, not an AMI name search. |
| RELEASE-003 | Implement Backend OIDC release workflow: lock, validate AMI, clone `$Default`, ImageId-only diff, promote, refresh, verify and rollback. | IAM-005, IAM-006, BE-007, RELEASE-002 | Nonproduction evidence verifies actual instance AMI/LT/ALB health. |
| RELEASE-004 | Implement Training OIDC release workflow: lock, validate AMI, clone `$Default`, ImageId-only diff, promote, verify new launches, no forced refresh. | IAM-005, IAM-006, TR-006, RELEASE-002 | Protected jobs remain; mixed-version draining is observable. |
| RELEASE-005 | Implement Working release workflow as an approved Terraform AMI input update/plan/apply path; prohibit LT/ASG API calls. | WK-006, DEC-012 | Replacement and DNS evidence are captured. |
| RELEASE-006 | Add per-component/environment GitHub concurrency controls and stale-default compare-before-promote guard. | RELEASE-003 through RELEASE-005 | Concurrent releases cannot silently overwrite/restore the wrong default. |
| RELEASE-007 | Add rollback evidence collection for prior/new default, AMI, LT version, instance IDs, lifecycle, ALB/app health and Training job state. | RELEASE-003, RELEASE-004 | Pointer rollback is not claimed as fleet rollback without instance evidence. |
| RELEASE-008 | Test Terraform drift cases: no release, AMI-only external release, structural drift, and structural update after a prior AMI release. | RELEASE-003, RELEASE-004 | Plan preserves workflow AMI/default ownership and detects unrelated structural drift. |

## 15. Validation and Deployment Gates

| ID | Task description | Depends on | Completion evidence |
| --- | --- | --- | --- |
| VAL-001 | Run `terraform fmt -check -recursive`, `terraform init -backend=false`, and `terraform validate`. | any Terraform code change | Exact command/output recorded; skipped checks are explicit. |
| VAL-002 | Add/configure selected lint/security/policy tools and pin their versions. | FND-002 | **Completed locally 2026-07-28**: TFLint `0.64.0` plus AWS ruleset `0.48.0` returned no issues; Trivy `0.72.0` returned zero HIGH/CRITICAL Terraform misconfigurations. |
| VAL-003 | Add deterministic tests or fixture validation for account IDs, CIDRs, names/tags, capacity bounds, policies and lifecycle ownership. | FND-006, implementation | **Completed locally 2026-07-28**: `terraform test -no-color` passed 9/9 cases through `mock_provider "aws"` and test-only Account ID `123456789012`; AWS credentials were not used. |
| VAL-004 | Generate a saved nonproduction plan in the named account/region/environment. | implementation complete | **Requires explicit authorization and the real Account ID/credentials**; plan artifact handled securely. |
| VAL-005 | Review the plan for creates/replacements/destroys, public paths, NAT routes, IAM/KMS, secret/state exposure, LT/ASG lifecycle, RDS/S3 retention and expected cost. | VAL-004 | Human-readable review checklist and decision recorded. |
| VAL-006 | Apply the approved nonproduction plan without `-target`. | VAL-005 | **Requires explicit authorization**; exact apply evidence/resource IDs recorded. |
| VAL-007 | Run network/security smoke tests: public ALB, private Backend/RDS/Working, Training NAT callback, S3 endpoint, SQS via NAT, no SSH/public EC2, and negative SG/IAM cases. | VAL-006 | Success and denial evidence recorded for each path. |
| VAL-008 | Run service release/rollback and ASG lifecycle tests for Backend, Working and Training. | VAL-006, release workflows | Real instance/AMI/LT/health/job evidence recorded. |
| VAL-009 | Update all design/dev records and classify each milestone as implemented, deployed or verified using evidence. | VAL-001 through VAL-008 | No planned or local-only task is mislabeled production-ready. |

## 16. Recommended Execution Waves

### Wave 0 — Decisions and local foundation

`DEC-001` through `DEC-004`, then `FND-001` through `FND-008`.

### Wave 1 — State and network

`STATE-001` through `STATE-004`, then `NET-001` through `NET-012`.
Live state bootstrap/migration remains separately authorized.

### Wave 2 — Encryption, data, SG, and runtime IAM

`DATA-001` through `DATA-007`, `RDS-001` through `RDS-005`, `SG-001` through `SG-007`, and
`IAM-001` through `IAM-007`.

### Wave 3 — Service compute

- Backend: `BE-001` through `BE-010`.
- Working: `WK-001` through `WK-007`.
- Training: resolve `TR-001`/`TR-002`, then `TR-003` through `TR-012`.

The three service branches can progress in parallel after their shared network/data/IAM
dependencies are stable.

### Wave 4 — Release, observability, and nonproduction verification

`OBS-*`, `OPS-*`, `RELEASE-*`, then `VAL-004` through `VAL-009`.

## 17. Recommended Next Task

Resolve DP-01 through DP-03 from `TERRAFORM_P1_PR_PLAN.md`, covering `DEC-001` through `DEC-004`.
Then implement `foundation-toolchain`, `foundation-provider-inputs`, `foundation-validation`, and
`state-bootstrap` in order. Do not start service compute from placeholder account,
CIDR, state, provider, AMI or runtime values.
