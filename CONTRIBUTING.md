# Contributing

- Keep all changes on reviewed branches; do not auto-merge test evidence.
- Prefix PRs with **docs**, **static-check**, **verification**, or **AWS-execution**. The latter must include a specific account/resource/cost/cleanup impact statement.
- Distinguish model output from actual Terraform plan/apply/destroy evidence. Never report a simulated authorization result as real IAM enforcement.
- Keep generated `.terraform/` trees, binaries, state, plans, credentials and evidence logs out of git.
- Preserve module interfaces and existing resource names unless an approved scope explicitly covers infrastructure changes.
- Do not introduce automatic `terraform apply` or `destroy` under a PR or push trigger.

See [the safety procedure](docs/SAFETY.md).
