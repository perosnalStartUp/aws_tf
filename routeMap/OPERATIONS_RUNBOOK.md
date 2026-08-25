# Terraform Operations Runbook

## Status and Safety Boundary

This runbook defines PR23 operational procedures. It does not authorize or execute an AWS
operation. Every command that opens an SSM session, changes a route, replaces a resource, changes
retention, or deletes data requires a named environment, the real Account ID, an approved operator,
and a separately reviewed change window.

Terraform-created resources in this root are referenced by their Terraform resource attributes.
Operators copy identifiers only from an approved applied State/output or an AWS inventory verified
against that State; they do not reconstruct ARNs by hand.

## SSM Access Without SSH

The Backend, Working, and Training instance profiles include the managed SSM core policy. Their
security groups have no inbound SSH rule and the instances receive no public IP. Session Manager is
therefore the only approved interactive host-access path.

Before opening a session:

1. Confirm the caller is in the named account and region and has an approved operator role.
2. Confirm the target instance belongs to the expected environment from the `Project`,
   `Environment`, `Component`, and `Deployment` tags.
3. Confirm the instance is registered and online in Systems Manager.
4. Record the ticket/change identifier, operator, target instance ID, purpose, and start time.
5. Prefer a predefined SSM document with explicit parameters over an unrestricted shell.

During and after the session:

- do not print Secrets Manager values, environment secret values, tokens, or Terraform State;
- do not install persistent SSH keys, enable `sshd`, or open port `22`;
- do not change application files that are owned by the immutable AMI;
- send session/audit logs to the owner-approved encrypted destination when that destination exists;
- record the end time, commands or document invoked, outcome, and any detected drift.

The current Terraform root supplies runtime SSM connectivity permissions, but an operator role,
session logging destination, retention owner, and KMS access for operator audit logs remain real
environment decisions. Do not claim audited interactive access until those controls are verified.

## Single-NAT Outage

The accepted topology has one NAT Gateway in public subnet A. Both private application route tables
use it for non-S3 IPv4 egress. A NAT outage or loss of the AZ-A public path can therefore affect:

- SQS, SSM, CloudWatch Logs, Secrets Manager, KMS, ECR and public AWS endpoints unless a specific
  VPC endpoint is added later;
- Training callbacks to the public Backend ALB;
- external package, model, identity, or API endpoints.

The S3 Gateway Endpoint is independent of the NAT route. S3 traffic that matches the endpoint route
and policy can continue, but that does not prove that the application can complete an end-to-end
operation: KMS, SQS, Secrets Manager, logging, callback, or control calls may still fail.

Triage sequence:

1. Check the NAT Gateway state, Elastic IP association, public subnet route to the Internet
   Gateway, route-table associations, Network ACLs, and the NAT CloudWatch alarms.
2. Check VPC Flow Logs for rejected or missing flows without logging application payloads.
3. Separate S3 endpoint reachability from public/AWS-service reachability.
4. Pause new Training work if callbacks, queue visibility renewal, or lifecycle control cannot be
   guaranteed. Do not terminate protected in-flight workers merely to recover egress.
5. Restore the existing path or execute an approved temporary route change; record every route and
   resource identifier before and after the change.
6. Verify SSM registration, SQS receive/visibility operations, Secrets/KMS access, log delivery,
   Training callback, and external dependencies before declaring recovery.

## Future Two-NAT Upgrade and Rollback

A two-NAT design is a separate Terraform change, not an emergency console edit. The reviewed
upgrade sequence is:

1. Add a second Elastic IP and NAT Gateway in public subnet B.
2. Keep private application subnet A routed to NAT-A.
3. Change only private application subnet B's default route to NAT-B.
4. Review the plan for exactly the new EIP/NAT and the intended route change.
5. Apply in a named nonproduction environment and test both AZ paths.
6. Add per-NAT alarms/dashboard dimensions and update cost expectations.

Rollback keeps NAT-A and restores subnet B's default route to NAT-A. Only after route propagation
and service verification may NAT-B and its EIP be considered for a separately approved removal.
Never delete the old NAT path in the same unverified step that introduces the new path.

## Deletion and Retention

Normal environment teardown must not include the independent `bootstrap/state` root.

| Resource | Guardrail and required deletion evidence |
| --- | --- |
| Terraform State bucket/key | `prevent_destroy`, versioning, KMS encryption and S3 lockfile; record recovery owner and verified object version before any State operation. |
| Product S3 bucket | `prevent_destroy`, versioning and KMS encryption; inventory current objects/versions, retention obligations and restore owner before a reviewed empty/delete operation. |
| RDS | deletion protection and required final snapshot identifier; verify backups, final snapshot name, restore test owner and application shutdown before changing either guard. |
| Product/database/log KMS keys | rotation enabled and delayed deletion; inventory every dependent bucket, database, snapshot and log group before scheduling deletion. |
| CloudWatch log groups | explicit retention and KMS key; export or extend retention when incident, audit or legal-hold requirements apply. |
| EC2/Working EBS | replacement may delete root/cache volumes according to Terraform settings; durable artifacts must already be in S3 and recovery must not depend on instance-local cache. |
| AMIs and snapshots | owned by build repositories/processes; prove no environment, LT version, rollback record or protected worker still references them before deregistration/deletion. |
| Backend/Training LT versions | preserve prior release evidence and rollback versions; `$Default` pointer change is not proof that instances were replaced. |

Required teardown record:

- named account, region, environment and approving owner;
- reviewed plan with every destroy/replacement identified;
- State backup/version and lock status;
- RDS final snapshot and restore ownership;
- S3 object/version disposition;
- AMI/LT/snapshot dependency inventory;
- log retention/export decision;
- KMS dependency inventory and deletion-window decision;
- post-change AWS inventory and recovery result.

No destructive command is intentionally included in this runbook.
