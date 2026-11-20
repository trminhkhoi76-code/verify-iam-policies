## Scope

**Classification:** STATIC / VERIFICATION / AWS-EXECUTION / DOCS

**Change summary:**

**Related issue / evidence:**

## Risk and effects

- [ ] This PR makes no AWS mutation by itself
- [ ] AWS-capable changes (if any) include affected account/resources and cleanup plan
- [ ] Existing Terraform backend, module paths and resource names reviewed

## Verification

- [ ] `terraform fmt -check -recursive terraform` (result / reason not run)
- [ ] `terraform init -backend=false` and `validate` for affected roots (result / reason not run)
- [ ] Real AWS evidence, if applicable, is linked and labelled as such
- [ ] No secrets, state or generated artifacts added

**Expected actual execution:** None / Plan / Apply / Destroy (specify)
