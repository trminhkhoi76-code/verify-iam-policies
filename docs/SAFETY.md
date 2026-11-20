# AWS execution boundaries

This is a verification repository with **potentially destructive real infrastructure code**.

Before running a non-static Terraform command:

1. Confirm the intended AWS account with `aws sts get-caller-identity`. Do not run with an unverified default profile.
2. Inspect `terraform/environments/dev/backend.tf` and confirm state is isolated from production and other applications.
3. Obtain explicit approval for the affected AWS resources, budget, region, IAM role and cleanup plan.
4. Use restricted IAM credentials; never put long-lived keys in repository files or GitHub job logs.
5. Run and review a saved plan before any approved apply; record Terraform, provider, AWS account and source commit versions.
6. Validate that cleanup/destroy is scoped only to resources created by this verification and does not affect existing shared resources.
7. Record actual AWS evidence (execution/CloudTrail/returned errors) separately from simulations and documentation.

Do not add AWS credentials or `terraform apply` to a pull-request-triggered workflow. The included manual workflow performs **only static validation**.

The `dev` root deliberately uses existing VPC/security group lookups; review how those shared resources are referenced and mutated before creating anything.
