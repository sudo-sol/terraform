# Design and operating scope

This document covers the shared design. Start with [00-bootstrap](../projects/00-bootstrap/README.md) for the first implemented example. Project READMEs explain setup, resources, inputs, deployment, cost and cleanup.

## Build one project at a time

Keep the examples simple and readable. Add folders and abstractions when actual code needs them. Use Terraform formatting and validation, then review a real plan and apply in your own account. Add tests only when they serve a concrete need.

The first project is local bootstrap. It creates dev and prod state buckets, a GitHub OIDC provider and separate dev/prod GitHub Actions roles using an existing authorized AWS identity. Bootstrap owns those deployment roles and their permissions. Its state remains local with a private backup. Add workload permissions here as service projects need them; service projects focus on AWS resources. HCP setup will follow when a project needs it.

## Terraform structure

Code has three responsibilities:

| Part | Responsibility |
| --- | --- |
| Deployment root | Choose the project configuration, account, environment, region and backend. |
| Project stack | Compose the resources and capabilities for a complete project. |
| Shared module | Provide a useful capability used by more than one project. |

Prefer a small amount of explicit configuration over extra tooling that hides how Terraform runs. Use direct resources, maintained upstream modules or local modules according to the project's needs. Pin upstream versions and keep third-party notices.

Bootstrap has one local root at `projects/00-bootstrap/deployments/account/`. It uses `us-west-2` for dev and `us-east-1` for prod in the example. Future service projects can use roots such as `deployments/dev/us-west-2/` and `deployments/prod/us-east-1/`. Each target gets independent state and one execution owner. Global or shared account resources need an explicit home so that regional deployments do not manage the same object. HCP-managed targets will not also run apply from a CLI runner.

## Planned automation

| Event or change | Intended behavior |
| --- | --- |
| S3 project: non-main branch push | Checks and plans for affected dev targets; no apply. The supplied prod role trusts only `main`. |
| HCP project: PR opened or updated | Native speculative plans for affected workspaces. |
| Merge to `main` | Fresh plans and automatic apply for affected targets with changes. |
| Deployment input change | Plan that deployment target. |
| Project stack change | Plan all deployments using the stack. |
| Shared module change | Plan its consumers; a conservative wider selection is acceptable initially. |
| Documentation-only change | Documentation checks, without cloud execution. |
| External contribution | Checks without access to the owner's cloud credentials or state. |

Use the merged commit for apply, not a feature-branch plan. Serialize applies per state and do not cancel an active apply when a new commit arrives. Pending or failed changes must be reconciled even if a later commit touches a different target. S3 backend locking and HCP workspace locking remain necessary.

Changed-file selection does not discover drift in untouched deployments. No scheduled drift checks are included in the initial scope. Deployment target selection must use known configurations rather than accept arbitrary filesystem paths or regions.

The goal is automatic deployment after a merge, without manual deployment approval jobs. This requires a protected `main` branch to enforce the merge boundary. Once available, require a PR and relevant successful checks, block force pushes and deletion, and apply the rule to the owner too. A solo repository does not need an independent reviewer requirement.

Use short-lived identities, minimal job permissions and actions pinned to full commit SHAs. Plans and logs can contain sensitive values, including values not marked sensitive in Terraform. Do not publish raw state, saved plans or unreviewed operational output.

Normal deployment and replacement changes become effective when merged. The teardown mechanism for each project must be defined before deployment. The bootstrap backend and identity dependencies need special care so that teardown cannot remove the tools or state needed to finish it.

## Public reference

The public repository contains a reviewed selection of the maintained implementation, using synthetic configuration. It is not a second independently developed platform or a mirror of private Git history.

Reference files use example identifiers. Configure your own account, bucket names and GitHub subjects before deploying. State, saved plans, credentials and private operational logs stay out of Git. Cloud jobs stay inactive until you deliberately configure your integrations.

The source bootstrap implementation was exercised with plan and apply. The public copy is checked locally with formatting and Terraform validation. Example values are not evidence of a deployment to your account. No publication workflow or cross-repository synchronization is included.

## Documentation

Keep the root README as the entry point. Use this folder for shared deployment guidance, backend behavior and significant design decisions as they become substantial enough to need separate documents. Link to one explanation rather than maintain copies in every project.
