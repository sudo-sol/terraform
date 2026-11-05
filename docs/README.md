# Design and operating scope

This document covers the shared design. Each project's README will cover its own architecture, inputs, deployment, cost, verification and teardown when that project is added. Module READMEs will explain their interfaces and examples.

## Build one project at a time

Start with the foundation needed for the first project. Add folders and shared abstractions only when actual code needs them. A project is ready to move on from when its behavior, deployment, verification, teardown and documentation have been checked.

The first implementation is intended to be local bootstrap. It creates deployment identities and S3 state infrastructure using an existing authorized AWS identity. Its state remains local with a private backup. HCP workspace configuration and AWS trust for HCP will be added when the first HCP project needs them.

## Terraform structure

Future code will have three responsibilities:

| Part | Responsibility |
| --- | --- |
| Deployment root | Choose the project configuration, account, environment, region and backend. |
| Project stack | Compose the resources and capabilities for a complete project. |
| Shared module | Provide a useful capability used by more than one project. |

Prefer a small amount of explicit configuration over extra tooling that hides how Terraform runs. Use direct resources, maintained upstream modules or local modules according to the project's needs. Pin upstream versions and keep third-party notices.

Each project/environment/region target gets independent state and one execution owner. Global or shared account resources need an explicit home so that regional deployments do not manage the same object. HCP-managed targets will not also run apply from a CLI runner.

## Planned automation

| Event or change | Intended behavior |
| --- | --- |
| S3 project: trusted branch push | Checks and plans for affected targets; no apply outside `main`. |
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

Before publication, select allowed files, replace operational identifiers, inspect file contents and scan for secrets. Review documentation, diagrams and verification evidence as well as code. Public workflows must not connect to the author's AWS or HCP accounts. Cloud jobs stay inactive until a user deliberately configures their own integrations.

State which checks actually ran. Examples and intended behavior are not evidence of a deployment. No publication workflow or cross-repository synchronization is being added at this stage.

## Documentation

Keep the root README as the entry point. Use this folder for shared deployment guidance, backend behavior and significant design decisions as they become substantial enough to need separate documents. Link to one explanation rather than maintain copies in every project.
