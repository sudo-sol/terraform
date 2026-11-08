# Bootstrap

Create the AWS foundation for your Terraform projects. Run this project locally using your own AWS identity. It creates:

- A dev state bucket in `us-west-2`.
- A prod state bucket in `us-east-1`.
- A GitHub OIDC provider in your AWS account.
- Separate dev and prod IAM roles for GitHub Actions.

This example uses one AWS account for both environments. Each role has access to its own state bucket. Add the AWS service permissions needed by later projects to these roles here in bootstrap; those projects can focus on their resources.

All account IDs, bucket names and GitHub subjects in the reference files are examples. Configure your own values before planning or applying. No workflows or credentials are included.

## Layout

```text
00-bootstrap/
├── README.md
├── policies/
│   ├── README.md
│   └── tf-bootstrap.json
├── stack/
│   ├── versions.tf
│   ├── variables.tf
│   ├── state-buckets.tf
│   ├── github-oidc.tf
│   ├── github-roles.tf
│   └── outputs.tf
└── deployments/
    └── account/
        ├── versions.tf
        ├── backend.tf
        ├── providers.tf
        ├── local.tf
        ├── variables.tf
        ├── main.tf
        ├── outputs.tf
        ├── bootstrap.example.tfvars
        └── .terraform.lock.hcl
```

Run Terraform from `deployments/account/`. That root selects the AWS account and providers, configures tags and local state, and calls `stack/`. The stack defines the resources. Both folders participate in one deployment and one state file.

The default provider handles dev and the account-wide IAM resources. The `prod` alias handles the prod bucket. The regions are explicit in `providers.tf` and `stack/outputs.tf`. If you change regions, update those files and the corresponding region permissions in the bootstrap user policy.

## Install the tools

- Install Git through your OS package manager.
- Install AWS CLI v2 using [AWS's instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). The browser-login option below requires v2.32.0 or newer.
- Install Terraform 1.17.x using [HashiCorp's instructions](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

Check they are on your path:

```bash
git --version
aws --version
terraform version
```

The provider lock file selects AWS provider 6.72.0. Keep it in Git and review intentional upgrades.

## Configure your inputs

From the repository root:

```bash
cd projects/00-bootstrap/deployments/account
cp bootstrap.example.tfvars terraform.tfvars
```

For an existing setup, keep your current `terraform.tfvars`. Terraform loads that file automatically; Git ignores it.

Edit these inputs:

| Input | What to set |
| --- | --- |
| `account_id` | Your 12-digit AWS account ID. Both providers check this account. |
| `state_bucket_names` | Your globally unique dev and prod bucket names. |
| `tags` | Your repository name and any additional tags. Ownership tags are set in `local.tf`. |
| `github_oidc_subjects` | The actual subjects issued for the repository that will run your workflows. |

The example account is `123456789012`. Replace it in your inputs and in the [bootstrap permissions policy](policies/tf-bootstrap.json). Keep the bucket names consistent between both files.

### GitHub subjects

Use your own workflow repository, which can be a fork or another repository where you keep these configurations. The example subjects are not usable identifiers for your repository.

GitHub may use a name-based prefix such as `repo:YOUR_OWNER/YOUR_REPO`, or an immutable prefix such as `repo:YOUR_OWNER@OWNER_ID/YOUR_REPO@REPO_ID`. Check your repository's OIDC settings and use the exact prefix. With GitHub CLI, you can inspect it using:

```bash
gh api repos/YOUR_OWNER/YOUR_REPO/actions/oidc/customization/sub --jq .sub_claim_prefix
```

Add `:ref:refs/heads/*` to that prefix for the dev input and `:ref:refs/heads/main` for prod. This gives dev access from all branches in your repository and prod access from `main`. The `Repository` resource tag is descriptive; it does not configure trust. See [GitHub's AWS OIDC guidance](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

These policies use branch subjects. A job that declares a GitHub environment has a different subject and needs a corresponding trust change.

## Set up AWS access

Use an existing authorized AWS identity to run bootstrap. It needs permission to configure the two buckets, the GitHub OIDC provider and the two deployment roles.

If you use IAM Identity Center or an existing role-based AWS CLI profile, sign in with that setup and select the profile through `AWS_PROFILE`. The [SSO instructions](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html) cover Identity Center profiles.

For an IAM user with browser login, follow the [policy setup notes](policies/README.md), enable MFA and sign in with a named profile:

```bash
aws login --profile terraform-bootstrap --region us-west-2
aws sts get-caller-identity --profile terraform-bootstrap
export AWS_PROFILE=terraform-bootstrap
```

The profile name is your choice. Verify the account before running Terraform. Keep credentials in your local AWS setup, outside the repository. GitHub Actions will later assume the dev or prod role through OIDC; it will not use this user's credentials.

## Plan and apply

From `deployments/account/` with your inputs and AWS profile configured:

```bash
terraform init
terraform fmt -check -recursive ../..
terraform validate
terraform plan
```

Review the plan, then apply:

```bash
terraform apply
terraform output
terraform plan
```

A fresh deployment has 17 managed Terraform resources: two buckets, ten bucket configuration resources, one OIDC provider, two roles and two inline policies. A repeat plan should show no changes. Fix any account-specific permission or configuration errors as they arise.

An AWS account can have only one OIDC provider with this GitHub URL. If it already exists, decide which Terraform state owns it. You can import it at `module.bootstrap.aws_iam_openid_connect_provider.github` instead of creating a second provider. Apply the same ownership rule to any existing buckets or roles.

## Resources and outputs

The buckets enable versioning, SSE-S3 encryption, disabled ACLs, public access blocking and an HTTPS-only bucket policy.

| Role | Allowed branches in your configured repository | Initial permissions |
| --- | --- | --- |
| `role-terraform-github-actions-dev` | All branches | Dev state bucket only |
| `role-terraform-github-actions-prod` | `main` | Prod state bucket only |

Each role can list its bucket, read/write its objects and delete `.tflock` lock files. It cannot delete state objects or administer the bucket through the supplied policy. The roles do not yet have workload service permissions. Keep changes to those deployment permissions in this bootstrap stack as you add service projects.

| Output | Use |
| --- | --- |
| `state_backends` | Bucket, region and backend settings for each environment. Add a unique key in every consuming root. |
| `github_oidc_provider_arn` | The account-wide GitHub OIDC provider. |
| `github_actions_role_arns` | Select the role ARN for the workflow's environment. |

Future S3 roots should use distinct keys, such as `<project>/dev/us-west-2/terraform.tfstate`, and enable `use_lockfile = true`. Workflow jobs will use `id-token: write` and `aws-actions/configure-aws-credentials` with the corresponding `role-to-assume`. Workflows are not included in this project yet.

## State, cost and cleanup

Bootstrap state stays in `deployments/account/terraform.tfstate`; it does not use the buckets it creates as its own backend. Keep a private backup after applying changes. State, saved plans and real input files stay out of Git.

S3 storage, requests and retained versions can incur charges. Remove dependent projects before deleting their backend. To destroy bootstrap, deliberately empty both versioned buckets using an authorized identity, then run `terraform destroy`. The bootstrap user policy does not grant object deletion. There are no automatic bucket-emptying settings or destroy-prevention lifecycle blocks.

## Verification

The source implementation was exercised with Terraform plan and apply in a separate AWS setup. This public version uses example identifiers and generic resource names. Its local checks are formatting and Terraform validation; it has not been applied to your AWS account. Run and review your own plan and apply. No test framework or separate authentication test project is required.
