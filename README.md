# Terraform

AWS infrastructure examples built with Terraform. The aim is to show clear, reusable deployment patterns that someone else can understand and adapt to their own account.

Start with [00-bootstrap](projects/00-bootstrap/README.md), which creates regional state buckets, GitHub OIDC and separate dev/prod deployment roles in your AWS account. Then see [01-network](projects/01-network/README.md) for Transit Gateway routing, private DNS, and inspected prod egress with an on-demand GitHub Actions workflow.

## Container projects

| Project | Local check and workload |
| --- | --- |
| [03 EKS workers](projects/03-eks-workers/README.md) | Mock-plan three private EC2 workers and validate a replicated workload designed for node drains. |
| [04 ECS orders](projects/04-ecs-orders/README.md) | Mock-plan two load-balanced Fargate services and run a PostgreSQL persistence test across an API restart. |

The [shared AWS modules](modules/aws/) provide the VPC and ECR implementations and the two-AZ dev network used by both new projects. Each deployment owns its state and resources.

## Scope

- Use plain Terraform with typed inputs for the core examples. [02-jenkins-terragrunt](projects/02-jenkins-terragrunt/README.md) is a draft example using Jenkins, Terragrunt, and synthetic YAML inputs.
- Organize future code by project, then environment and region.
- Keep deployment roots small and move useful shared logic into modules as the need appears.
- Demonstrate local state for bootstrap, HCP Terraform for selected projects and S3 state for others.
- Use GitHub Actions for CLI-based automation and native VCS integration for HCP Terraform. Actions workflow files will use YAML.
- Explain the architecture, tradeoffs, cost, verification and teardown for each completed project.

The longer-term direction is one local bootstrap project, two or three HCP projects and two or three S3 backend projects. These are not all being built now.

## Using the examples

Copy the synthetic input files to ignored local files and supply your own identifiers. The bootstrap README walks through configuring an AWS identity and rendering its IAM policy.

Bootstrap runs locally. The network workflow supports manually dispatched plan, apply and destroy after you configure your AWS and GitHub integrations. See [design and operating scope](docs/README.md) for the shared repository structure.

## Local files

The `.gitignore` excludes state, saved plans, real variable files, backend settings, credentials and local tools' files. Synthetic examples can use `*.example.tfvars`, `*.example.tfvars.json` and `*.example.tfbackend`. Commit `.terraform.lock.hcl` files when deployment roots are added.

Ignore rules do not inspect file contents or protect files that are already tracked. Review every change for real identifiers and sensitive values before publishing it.

## License

The code and documentation in this repository are covered by [Apache 2.0](LICENSE), except where third-party material states otherwise. Preserve the license and required notices for any third-party code.
