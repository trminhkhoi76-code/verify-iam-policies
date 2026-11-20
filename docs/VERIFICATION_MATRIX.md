# Verification matrix

| Activity | Evidence class | Does it call AWS? | Can it prove real permissions? |
| --- | --- | --- | --- |
| `terraform fmt -check` | Static style check | No | No |
| `terraform init -backend=false` | Dependency and module setup | No AWS backend/credentials required by this workflow | No |
| `terraform validate` | Static config validation | Not expected to call AWS service APIs | No |
| `terraform plan` against live state | Real read/plan | Yes, depending on providers/data sources | Only that the plan could be computed, not that apply will succeed |
| `terraform apply` | Real infrastructure mutation | Yes | Partial observed coverage for the resources and inputs actually exercised |
| `terraform destroy` | Real infrastructure mutation | Yes | Observed cleanup for that exact stack; does not prove no residuals elsewhere |
| AWS IAM simulation/evaluation | Modelled policy decision | Varies with chosen tool | Not interchangeable with a real execution result |

## Reporting requirements

Every report must state: repository commit SHA, exact Terraform root, account/environment (redact sensitive IDs before sharing), AWS role identity, command and exit status, resource coverage, artifacts, and whether the result is **STATIC**, **PLAN**, **REAL APPLY**, or **REAL DESTROY**.

Never claim “all permissions proven least privilege” from a successful `terraform plan` or one successful execution variant. Real controls also depend on SCPs, resource policies, permission boundaries, trust policies, provider versions and actual inputs.

No current AWS access, state snapshot, CloudTrail, apply or destroy results were inspected in this repository cleanup.
