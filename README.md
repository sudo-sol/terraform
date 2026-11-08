# Terraform

AWS infrastructure examples built with Terraform. The aim is to show clear, reusable deployment patterns that someone else can understand and adapt to their own account.

Start with [00-bootstrap](projects/00-bootstrap/README.md), which creates regional state buckets, GitHub OIDC and separate dev/prod deployment roles in your AWS account. More service projects will be added one at a time. No deployment workflows are included yet.

## Scope

- Use plain Terraform with typed inputs. No Terragrunt or YAML infrastructure configuration.
- Organize future code by project, then environment and region.
- Keep deployment roots small and move useful shared logic into modules as the need appears.
- Demonstrate local state for bootstrap, HCP Terraform for selected projects and S3 state for others.
- Use GitHub Actions for CLI-based automation and native VCS integration for HCP Terraform. Actions workflow files will use YAML.
- Explain the architecture, tradeoffs, cost, verification and teardown for each completed project.

The longer-term direction is one local bootstrap project, two or three HCP projects and two or three S3 backend projects. These are not all being built now.

## Using the examples

Reference inputs and IAM policies use example account details, resource names and GitHub subjects. Replace them with your own and configure an AWS identity before deploying anything. The bootstrap README walks through that setup.

The planned S3 workflow will plan affected dev deployments on branch pushes, then create fresh plans and apply affected dev/prod deployments on `main`. The bootstrap role trust allows all branches for dev and only `main` for prod. HCP projects will use native PR plans. These workflows will be added later; bootstrap runs locally.

This repository is a reference for your own account. Configure your AWS and GitHub integrations in your copy. Future cloud jobs must remain inactive until that setup is complete, and external contributions must not receive deployment credentials or state.

[Design and operating scope](docs/README.md) explains the shared structure. The first project lives in `projects/00-bootstrap/`, with its local execution root in `deployments/account/`. Shared modules and workflows will be added when needed.

## Local files

The `.gitignore` excludes state, saved plans, real variable files, backend settings, credentials and local tools' files. Synthetic examples can use `*.example.tfvars`, `*.example.tfvars.json` and `*.example.tfbackend`. Commit `.terraform.lock.hcl` files when deployment roots are added.

Ignore rules do not inspect file contents or protect files that are already tracked. Review every change for real identifiers and sensitive values before publishing it.

## License

The code and documentation in this repository are covered by [Apache 2.0](LICENSE), except where third-party material states otherwise. Preserve the license and required notices for any third-party code.
