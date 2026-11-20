# Verify IAM Policies

This repository is a **Terraform-based permission verification harness** for Heatmap Japan infrastructure. It is **not** the source of truth for a production deployment and has no automated production deployment workflow on the current `main` branch.

**Warning:** Terraform under `terraform/environments/dev/` describes **real AWS resources**. A manually executed `terraform apply` can create resources, change IAM-adjacent infrastructure and incur charges. The word “verify” does not mean the configuration is a harmless simulation.

## Classification

| Location | Category | Intended use |
| --- | --- | --- |
| `terraform/modules/` | **REAL TERRAFORM MODULES** | AWS resources that can be created if called by a root module |
| `terraform/environments/dev/` | **AWS-CAPABLE VERIFICATION STACK** | Coverage of resource/API permissions through controlled plan/apply/destroy |
| `terraform/main.tf` and sibling root files | **REFERENCE INFRASTRUCTURE CONFIGURATION** | Larger Heatmap Japan Terraform configuration; no evidence of a managed production environment here |
| `.github/workflows/terraform-static-verification.yml` | **STATIC VERIFICATION ONLY** | Manual, credential-free Terraform validation; no plan/apply/destroy |
| `docs/` | **VERIFICATION PROCEDURES / LIMITS** | Evidence expectations and separation of test vs actual AWS effect |

There is no `terraform/environments/prod/` directory in `main`; any old documentation that described such a directory was outdated. Do not use this repository as an automatic production release path.

## Inspect without AWS writes

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/dev init -backend=false -input=false
terraform -chdir=terraform/environments/dev validate
```

You can also manually start **Terraform static verification (no AWS)** in GitHub Actions. It intentionally does not request AWS credentials. These checks may expose pre-existing formatting or configuration problems; a green result does not establish IAM least privilege.

## Real AWS permission verification

A real plan/apply/destroy requires an approved isolated test account, scoped role, pre-approved scope/cost, backend and cleanup plan. See [Safety and execution boundaries](docs/SAFETY.md) and the [Evidence matrix](docs/VERIFICATION_MATRIX.md). Do **not** run it automatically from pull requests.

## Navigation

- [Terraform configuration notes](terraform/README.md)
- [Evidence matrix](docs/VERIFICATION_MATRIX.md)
- [AWS safety checklist](docs/SAFETY.md)
- [Contribution and PR review requirements](CONTRIBUTING.md)
