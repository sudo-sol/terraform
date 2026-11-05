# Terraform

AWS infrastructure examples built with Terraform. The aim is to show clear, reusable deployment patterns that someone else can understand and adapt to their own account.

This repository is starting with the documentation and basic Git exclusions. There are no Terraform projects, workflows or deployed examples here yet. Projects will be added and verified one at a time.

## Scope

- Use plain Terraform with typed inputs. No Terragrunt or YAML infrastructure configuration.
- Organize future code by project, then environment and region.
- Keep deployment roots small and move useful shared logic into modules as the need appears.
- Demonstrate local state for bootstrap, HCP Terraform for selected projects and S3 state for others.
- Use GitHub Actions for CLI-based automation and native VCS integration for HCP Terraform. Actions workflow files will use YAML.
- Explain the architecture, tradeoffs, cost, verification and teardown for each completed project.

The longer-term direction is one local bootstrap project, two or three HCP projects and two or three S3 projects. These are not all being built now. There is no pre-created project catalogue or empty project tree.

## Using the examples

Published configuration will use synthetic account details, resource names and backend settings. Replace those values with your own and configure your own AWS identity and state storage before deploying anything.

The intended workflow is to plan affected deployments on branch pushes for S3 projects, and plan HCP projects when a PR is opened or updated. A merge to `main` will create fresh plans and automatically apply changes for affected deployments once the user has configured automation in their own copy. Local bootstrap is run on the user's machine.

This public repository is a reference. It has no connection to the author's AWS account or HCP organization. Cloud jobs must remain inactive until a user deliberately configures their own integrations. External contributions receive checks without access to deployment credentials or state.

## Current layout

<!-- source-inventory:start -->
- `.gitignore`
- `LICENSE`
- `README.md`
- `docs/README.md`
<!-- source-inventory:end -->

[Design and operating scope](docs/README.md) describes the planned deployment boundaries and publication rules. Folders for projects, modules, bootstrap and workflows will be added when there is something to put in them.

## Local files

The `.gitignore` excludes state, saved plans, real variable files, backend settings, credentials and local tools' files. Synthetic examples can use `*.example.tfvars`, `*.example.tfvars.json` and `*.example.tfbackend`. Commit `.terraform.lock.hcl` files when deployment roots are added.

Ignore rules do not inspect file contents or protect files that are already tracked. Review every change for real identifiers and sensitive values before publishing it.

## License

The code and documentation in this repository are covered by [Apache 2.0](LICENSE), except where third-party material states otherwise. Preserve the license and required notices for any third-party code.
