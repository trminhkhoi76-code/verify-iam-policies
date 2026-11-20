# Heatmap Japan — IAM permission verification Terraform

**Status: AWS-capable verification fixture, NOT a verified production deployment.**

The repository contains a copy/reference configuration of Heatmap Japan infrastructure under `terraform/`, reusable real AWS resource modules in `modules/`, and a targeted `environments/dev/` verification root. The latter assembles many resource variants to exercise permissions used by the deployment role.

## Current repository layout

```text
terraform/
├── main.tf, variables.tf, outputs.tf  # broad reference root configuration
├── environments/
│   └── dev/
│       ├── backend.tf                 # AWS S3 backend; account-specific
│       ├── main.tf                    # test resource coverage against a real AWS account
│       └── outputs.tf
└── modules/                            # real Terraform modules; not mocks
```

There is **no** `environments/prod/` in the checked `main` tree. Earlier setup instructions describing prod deployment, Valkey monthly costs and a different S3 state bucket do not match this snapshot and must not be used as an operational runbook.

## Safe static validation (without AWS credentials)

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/dev init -backend=false -input=false
terraform -chdir=terraform/environments/dev validate
```

`-backend=false` avoids contacting the configured S3 state backend. Terraform may still download public providers/modules as part of initialization. Do not confuse this with `terraform plan`: the latter may access AWS, state and data sources.

## Controlled real verification

`environments/dev/main.tf` contains AWS data sources and resources for IAM coverage tests (including ECS, Lambda and Valkey variants). The backend is configured for a specific test environment. **Do not assume that backend, AWS account, and privileges are safe just because they are labelled dev.**

Before `plan`, `apply` or `destroy`: obtain an isolated test account, explicit change approval, verified role identity, dedicated remote state, resource inventory, cleanup plan and cost budget. Keep AWS run links, exact Terraform plan, CloudTrail/role evidence and cleanup evidence. Passing a plan alone is not proof of all `apply` permissions.

## Generated artifacts

The Lambda module uses `archive_file` to generate a placeholder zip at `modules/lambda-functions/.terraform/dummy.zip`. It is build output, not maintainable source. The previously committed zip is removed from version control and ignored; it can be generated when Terraform evaluates the archive data source.

See [safety](../docs/SAFETY.md) and [evidence classification](../docs/VERIFICATION_MATRIX.md).
