# Jenkins and Terragrunt

This draft combines a Jenkins pipeline, Terragrunt deployment units, reusable AWS Terraform modules, and a small Flask app in one checkout. Each unit has a separate S3 state key. Jenkins runs the infrastructure pipeline and the demo app runs on ECS Fargate.

| Path | Purpose |
| --- | --- |
| `deployments/dev/us-west-2/ecr/` | ECR repository for the demo image |
| `deployments/dev/us-west-2/vpc-smoke/` | Standalone VPC for trying the pipeline independently |
| `deployments/dev/us-west-2/ecs-demo/` | VPC, private Fargate tasks, internal load balancer, logs and autoscaling |
| `root.hcl` | Shared provider and S3 state settings |
| [Shared AWS modules](../../modules/aws/) | VPC and ECR implementations |
| `modules/aws/ecs/` and `stacks/` | Project-specific ECS implementation and composed stacks |
| `Jenkinsfile` and `jenkins/` | Pipeline and local Jenkins controller image |
| `app/` | Demo image source with `/health` and a bounded `/load` endpoint |

Use a clean source checkout for Terragrunt. The ECS unit copies from the repository root so the cached Terraform stack can resolve the shared VPC. The original backend keys and module calls are preserved. Seven moved blocks map the existing endpoint and security-rule addresses to their optional instances. Review the actual state-backed plan for replacements before applying to an existing environment.

## Validate locally

Use Terraform 1.17.x and Terragrunt 1.2.2. From this project's directory:

```sh
terraform fmt -recursive -check
terragrunt hcl fmt --check
terragrunt hcl validate --inputs --strict

for unit in ecr vpc-smoke ecs-demo; do
  (
    cd "deployments/dev/us-west-2/$unit" &&
    terragrunt run -- init -backend=false -input=false &&
    terragrunt run --no-auto-init -- validate &&
    terragrunt run --no-auto-init -- test
  ) || exit 1
done
```

Backend-disabled initialization downloads the AWS provider. The validation and mock-plan tests require no AWS account, state bucket, or deployed resources. Tests beside the ECR module and the two stacks cover all three sample configurations, multiple ingress/egress CIDRs, duplicate CIDRs, unsupported flow-log destinations, and disabled logging.

With Python 3.12+ and the dependencies from `app/requirements.txt` installed, run the endpoint regressions:

```sh
python3 -m unittest discover -s app -p 'test_*.py' -v
```

The app tests use a simulated clock, so bound checks do not burn CPU for 90 seconds. Docker builds, Jenkins execution and live AWS acceptance remain separate checks.

Local verification, November 16, 2026: Terraform formatting/validation, Terragrunt formatting/strict input validation, all six mock tests across the three units, and all seven app tests passed. Tools were Terraform 1.17.2, Terragrunt 1.2.2, AWS provider 6.72.0 and Python 3.12 with the app's pinned requirements. Docker/Jenkins execution and live AWS deployment were not tested.

## Supported inputs

Each security-group rule creates one AWS rule per distinct IPv4 CIDR in `cidr_blocks`, for both ingress and egress. Rule addresses include the CIDR; existing deployments need state/address migration review before adopting this change.

VPC flow logging supports `CLOUD_WATCH_LOGS` only. `S3` and other destination values fail input validation; S3 bucket delivery is not implemented. Disabling `enable_flow_logs` omits the log group, delivery role/policy and flow log.

The app's `/load` endpoint accepts integer `duration` and `intensity` parameters. Invalid values return JSON with HTTP 400. Valid integers are clamped to 1–90 seconds and 1–100 percent. Environment defaults use `LOAD_DURATION_DEFAULT` and `LOAD_INTENSITY_DEFAULT`; invalid defaults are server configuration errors (HTTP 500), and explicit request values override them.

## Configure your own deployment

1. Use an existing private, versioned S3 state bucket in `us-west-2`, for example one created through [00-bootstrap](../00-bootstrap/README.md). Configure the execution identity through the standard AWS credential chain. The role needs access to the project state prefix, its lock files, and the resources the selected unit manages. Review those permissions separately if using an existing bootstrap role.
2. Set `TG_STATE_BUCKET` and `TG_AWS_ACCOUNT_ID` in your local shell. For Jenkins, enter the corresponding build parameters and configure the build agent's AWS identity separately. Keep these values out of source control. The sample repository URL uses an all-zero account placeholder, which Terragrunt replaces with the configured account ID.
3. Each unit reads its committed `service.example.yaml`. To supply local settings, copy it to the ignored `service.local.yaml` beside it and edit the copy. The Jenkins starter uses the checked-out sample files, so adapt the job to inject local overrides if needed. The example is for fresh deployments. Existing infrastructure requires a separate state and resource migration plan.
4. Deploy `ecr`, build the demo image from `app/`, then tag and push it as `latest` to the repository URL returned by `terragrunt run -- output -json ecr_repository_uris` from the ECR unit. Deploy `ecs-demo` after the image is available. The VPC smoke unit is optional and independent.

After extracting VPC and ECR on November 27, 2026, all three Terragrunt units passed backend-disabled initialization, validation and six mock tests in total, including the original four VPC endpoints. The seven application tests also passed. Tests used Terraform 1.17.2, Terragrunt 1.2.2 and a local mirror of the locked AWS provider 6.72.0.

## Run in Jenkins

For a local controller, run `docker compose -f jenkins/compose.yaml up --build -d` from this directory and open `http://localhost:8080`. Set up Pipeline and Git support, configure a trusted build agent labeled `terraform` with Terraform and Terragrunt on its PATH, and point a Pipeline-from-SCM job at `projects/02-jenkins-terragrunt/Jenkinsfile`. For a local-only demo the built-in node can use that label after you explicitly enable an executor. Use trusted branches and agents for jobs with AWS credentials.

The default action validates the selected unit. The plan action previews changes. Apply and destroy each require Jenkins approval of a saved plan. The pipeline removes its workspace and saved plans after each run.

## Verify and tear down

After deployment, obtain the load balancer DNS name from the `load_balancer_dns` output in the ECS unit. Use a client with network access from inside the demo VPC to verify that `/health` returns HTTP 200. Fargate, the load balancer, NAT, interface endpoints, logs, and image storage can incur charges. Destroy `ecs-demo` first, remove the demo image tags and images before destroying `ecr`, and destroy `vpc-smoke` if used. Keep the state bucket available through teardown.
