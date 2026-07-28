# Backend Database Migration Release Runbook

## Status

This document defines the PR15 migration boundary. It does not select or implement an execution
platform.

- Execution owner: `[DECISION REQUIRED]`
- Candidate owners to approve: Backend release workflow, a dedicated one-shot ECS task, or an
  operator-run SSM command against a dedicated migration instance.
- Live migration: not run.
- GitHub workflow: not created.

The selected owner must be able to reach the private RDS endpoint, assume only a migration-specific
IAM role, retrieve the RDS-managed credential secret at runtime, and emit durable execution
evidence. A normal Backend ASG instance is not an acceptable owner.

## Non-Negotiable Boundary

Database migration is a singleton release step. Backend Launch Template user data, service startup,
health checks, and Auto Scaling lifecycle hooks must not invoke migrations.

```text
approved immutable Backend artifact
        |
        v
singleton migration lock -> migration succeeds -> Backend rollout may start
        |                          |
        |                          +-> durable evidence
        v
failure/unknown status -> rollout remains blocked
```

No migration result, a stale result, or an unverified result is a failure-closed condition.

## Required Inputs

The future runner receives identifiers, never secret values:

- environment and AWS region;
- immutable Backend artifact identifier and digest;
- migration bundle/version embedded in that artifact;
- RDS endpoint, database name, and port;
- `aws_db_instance.postgres.master_user_secret[0].secret_arn` through an approved Terraform output;
- migration-specific IAM role ARN;
- lock identifier scoped to project and environment;
- release/evidence destination.

Same-root Terraform resources must be referenced through their resource attributes. Hand-written
ARNs are allowed only for resources outside this root or resources intentionally scheduled for a
later PR, and must be replaced by direct references when those resources are created.

## Required Execution Sequence

1. Verify the approved Backend artifact identifier and digest.
2. Acquire an atomic singleton lock for the project/environment migration version.
3. Record the execution ID, artifact digest, migration version, actor, and start timestamp.
4. Resolve the AWS-managed RDS secret at runtime and connect through the private network path.
5. Run an idempotent migration command exactly once for that migration version.
6. Persist success/failure, schema version, finish timestamp, and sanitized logs.
7. Release or mark the lock according to the approved lock implementation.
8. Permit Backend rollout only when the exact artifact/migration pair has a verified success.

The rollout process must re-read the durable result. A workflow job's in-memory success flag is
not sufficient evidence.

## Retry and Failure Rules

- A failed migration blocks Backend rollout.
- A retry uses the same immutable artifact and migration version unless a new artifact is approved.
- The migration command must safely detect already-applied migrations.
- Concurrent executions must fail before connecting to RDS or must observe the same completed
  result; they must not both apply schema changes.
- Timeout, runner termination, missing logs, or ambiguous lock ownership requires operator review.
- Rollback is application-specific and is not inferred as a reverse migration. The release owner
  must use an approved forward fix or documented database recovery procedure.

## Required IAM and Network Boundary

The future migration role may receive only:

- `secretsmanager:DescribeSecret` and `secretsmanager:GetSecretValue` on the RDS-managed secret ARN;
- `kms:Decrypt` and `kms:DescribeKey` on `aws_kms_key.database.arn`;
- the minimum permissions required by the selected lock/evidence mechanism;
- log write permissions on its dedicated log group.

It receives no SQS, Training lifecycle, product-data write, Launch Template, or ASG mutation
permissions. The runner network path permits PostgreSQL only to `aws_security_group.database`.

## Release Evidence Checklist

- [ ] Execution owner and runner platform approved.
- [ ] Singleton lock implementation reviewed with a stale-lock recovery procedure.
- [ ] Migration-specific IAM role and network identity reviewed.
- [ ] Artifact identifier and digest recorded.
- [ ] Migration version recorded.
- [ ] Start/end timestamps and execution ID recorded.
- [ ] Sanitized logs retained; no credential value logged.
- [ ] Exact success result consumed by the Backend rollout gate.
- [ ] Failure/retry exercise completed in a nonproduction environment.
- [ ] Concurrent-run negative test proves only one execution can migrate.

Until every required decision and test above is complete, PR15 remains a documented boundary rather
than an executable release workflow.
