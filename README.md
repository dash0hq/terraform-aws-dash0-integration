# Dash0 AWS Integration Terraform Module

This Terraform module creates the necessary IAM roles and registers an AWS integration with [Dash0](https://www.dash0.com) for resource discovery, monitoring, and optional auto-instrumentation.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS provider >= 4.0
- A Dash0 account with an API key
- `curl` available on the machine running `terraform apply` (used to call the Dash0 API)

## Usage

```hcl
module "dash0_aws_integration" {
  source  = "dash0hq/dash0-integration/aws"
  version = "~> 1.0"

  dash0_api_key     = var.dash0_api_key
  dash0_external_id = "<your-organization-technical-id>"
  dash0_dataset     = "default"
}
```

With resources instrumentation enabled (e.g., Lambda auto-instrumentation):

```hcl
module "dash0_aws_integration" {
  source  = "dash0hq/dash0-integration/aws"
  version = "~> 1.0"

  dash0_api_key                    = var.dash0_api_key
  dash0_external_id                = "<your-organization-technical-id>"
  dash0_dataset                    = "default"
  enable_resources_instrumentation = true
}
```

## Finding Your Parameters

| Parameter | Where to find it |
|-----------|-----------------|
| `dash0_api_key` | Dash0 UI → Settings → Auth Tokens |
| `dash0_external_id` | Dash0 UI → Settings → Integrations → Add → AWS (shown as "External ID" or "Technical ID") |
| `dash0_dataset` | Dash0 UI → Settings → Datasets (use the dataset slug) |

## What This Module Creates

### IAM Roles

**Read-Only Role** (always created):
- Attaches the AWS managed `ViewOnlyAccess` policy
- Adds custom policies for Resource Explorer, Tags, Lambda, EKS, AppSync, and X-Ray access
- Trust policy allows Dash0's AWS account to assume the role using the external ID

**Resources Instrumentation Role** (optional, when `enable_resources_instrumentation = true`):
- Grants permissions to instrument Lambda functions (`GetFunctionConfiguration`, `UpdateFunctionConfiguration`)
- Grants permissions for VPC connectivity checks and Lambda layer management
- Trust policy same as the read-only role

### API Registration

A `null_resource` calls the Dash0 API to register the integration on `terraform apply` and deregister it on `terraform destroy`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `dash0_api_key` | Dash0 API key (auth token) | `string` | — | yes |
| `dash0_external_id` | Dash0 organization technical ID | `string` | — | yes |
| `dash0_dataset` | Dataset slug to associate with the integration | `string` | `"default"` | no |
| `dash0_api_url` | Dash0 API base URL | `string` | `"https://api.dash0.com"` | no |
| `dash0_aws_account_id` | Dash0 AWS account ID for the trust policy | `string` | `"115813213817"` | no |
| `enable_resources_instrumentation` | Create an additional role for Lambda auto-instrumentation | `bool` | `false` | no |
| `iam_role_name_prefix` | Prefix for IAM role names | `string` | `"dash0"` | no |
| `tags` | Tags to apply to all created resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `read_only_role_arn` | ARN of the Dash0 read-only IAM role |
| `instrumentation_role_arn` | ARN of the instrumentation IAM role (null if not enabled) |
| `aws_account_id` | AWS account ID where the integration was created |

## Destroying

Running `terraform destroy` will:
1. Call the Dash0 API to deregister the integration
2. Delete the IAM roles and policies

## Troubleshooting

**`curl` fails during apply:**
Ensure the machine running Terraform has network access to the Dash0 API (`api.dash0.com`) and `curl` is installed.

**Integration not appearing in Dash0:**
- Verify the API key is valid and has access to the specified dataset.
- Check that the `dash0_external_id` matches your organization's technical ID.
- Look at Terraform's output for error messages from the API call.

**Role assumption errors after creation:**
IAM role propagation can take a few seconds. Dash0 automatically retries role verification. If the role status stays "pending", check the trust policy and external ID.

## Contributing

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/dash0hq/terraform-aws-dash0-integration.git
   cd terraform-aws-dash0-integration
   ```

2. Initialize Terraform (for local validation):
   ```bash
   terraform init -backend=false
   ```

3. Validate your changes:
   ```bash
   terraform fmt -recursive
   terraform validate
   ```

### Commit Message Convention

This project uses commit messages to determine the version bump on release. Follow these conventions:

| Commit prefix | Version bump | Example |
|---------------|-------------|---------|
| `feat:` | Minor (0.1.0 → 0.2.0) | `feat: add support for ECS instrumentation` |
| `fix:`, `docs:`, `chore:`, etc. | Patch (0.1.0 → 0.1.1) | `fix: correct IAM policy ARN` |
| `BREAKING CHANGE:` in body or `!:` | Major (0.1.0 → 1.0.0) | `feat!: rename dash0_api_key variable` |

### Releases

Releases are automated via GitHub Actions. When a PR is merged to `main`:

1. The CI workflow runs `terraform fmt -check` and `terraform validate`
2. The release workflow determines the next [semver](https://semver.org/) version from commit messages
3. A GitHub Release is created with auto-generated release notes
4. The [Terraform Registry](https://registry.terraform.io/) automatically picks up the new release

To publish the first version, tag `v1.0.0` manually or let the workflow create it on the first merge.

### Pull Requests

- Ensure `terraform fmt -recursive` and `terraform validate` pass before opening a PR
- Update examples if you add or change variables

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.