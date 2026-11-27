# ECS orders

An operator reaches the public Application Load Balancer over HTTP from an allowed IPv4 CIDR. It forwards to a web service on Fargate. The web service calls a private API through an internal ALB. The API writes to encrypted, private PostgreSQL on RDS. Each tier has two private tasks, its own target group and a health endpoint. Use synthetic orders for this HTTP lab.

One ECR image contains the web, API and migration entry points. The API authenticates as the limited PostgreSQL role `orders_api` with an RDS IAM token and verified TLS. The one-off migration task receives the RDS-managed admin password through ECS secret injection. It uses the API security group for database access. The web task has no database role. [AWS PostgreSQL IAM authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.DBAccounts.html)

## Test locally

From this project directory, with Terraform 1.17.x:

```sh
terraform -chdir=deployments/dev/us-west-2 init -backend=false -input=false -lockfile=readonly
terraform -chdir=deployments/dev/us-west-2 validate
terraform -chdir=deployments/dev/us-west-2 test -var-file=dev.example.tfvars
```

Four mock plans cover an empty registry, migration before first rollout, a running release and rejection of a tag in place of an image digest. For the application test, install Python 3.12+, PostgreSQL 16 server tools and the application dependencies in a virtual environment:

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r app/requirements.txt
tests/test-local.sh
```

Run the test as a regular user. Set `PG_BINDIR` if `pg_config --bindir` does not locate the server binaries. The test creates a disposable UTF-8 database on a private Unix socket and starts two loopback HTTP services. It runs the migration twice, checks the API role's permissions, writes a sample order, replaces the API process and reads the same order through the running frontend. The fixture supplies the RDS role name for local SQL testing.

Local verification on November 27, 2026 passed backend-disabled initialization, validation and all four Terraform mock plans using Terraform 1.17.2 and the locked AWS provider 6.72.0 from a local mirror. Both integration tests passed against PostgreSQL 16.15, including order readback after API replacement. Container image builds and AWS integration remain unverified.

## AWS lab procedure

Use a bootstrap state bucket and a deployment identity authorized for this lab's networking, ALBs, ECS, ECR, IAM, CloudWatch and RDS resources. Set the AWS CLI region to `us-west-2`. From `deployments/dev/us-west-2`, copy the example backend and variables to ignored `dev.tfbackend` and `dev.tfvars`. Set the bucket, matching account IDs and your operator CIDR. Keep the project's dedicated state key.

1. Leave both image digests unset. Run `terraform init -reconfigure -backend-config=dev.tfbackend` and review `terraform plan -var-file=dev.tfvars -out=dev.tfplan` before applying the saved plan. This provisions the infrastructure, including the database and ALBs.
2. Build and push the image from the deployment directory. Use a fresh release tag and record the digest.

   ```sh
   export AWS_REGION=us-west-2
   repo=$(terraform output -raw repository)
   registry=${repo%%/*}
   tag=demo-v1
   aws ecr get-login-password | docker login --username AWS --password-stdin "$registry"
   docker buildx build --platform linux/amd64 --push -t "$repo:$tag" ../../../app
   aws ecr describe-images --repository-name "${repo#*/}" --image-ids imageTag="$tag" --query 'imageDetails[0].imageDigest' --output text
   ```

3. Set `migration_digest` to that digest in `dev.tfvars`. Keep `service_digest` at its previous value. Review and apply a fresh plan. Run the one-off task and require a successful exit code before promotion.

   ```sh
   cluster=$(terraform output -raw cluster)
   task=$(aws ecs run-task --cluster "$cluster" --launch-type FARGATE --platform-version 1.4.0 \
     --task-definition "$(terraform output -raw migration_task)" \
     --network-configuration "$(terraform output -json migration_network)" \
     --query 'tasks[0].taskArn' --output text)
   test "$task" != None && aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task" &&
     test "$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task" --query 'tasks[0].containers[0].exitCode' --output text)" = 0
   ```

   On failure, inspect the ECS stopped reason and the migration log group before continuing. Migrations run transactionally and can be retried. Keep later schema changes compatible with the serving release.
4. Set `service_digest` to the migrated digest. Review and apply the plan. Both services wait for steady state. Open `terraform output -raw web_url` from the permitted client and create a synthetic order, or use the commands below. Record the returned ID.

   ```sh
   url=$(terraform output -raw web_url)
   curl -fsS "$url/health"
   curl -fsS -H 'Content-Type: application/json' -d '{"item":"sample pen"}' "$url/orders"
   read -r -p "Order ID from the POST: " order_id
   aws ecs update-service --cluster "$cluster" --service api --force-new-deployment
   aws ecs wait services-stable --cluster "$cluster" --services api web
   curl -fsS "$url/orders/$order_id"
   ```

   Confirm that its item survives the replacement, both target groups have healthy targets, and only the public web ALB accepts operator traffic. Tasks have no public IPs. The database allows PostgreSQL connections only from the API security group.

## Cost and teardown

The two ALBs, four serving Fargate tasks, single-AZ RDS instance, ECR storage, NAT gateway, public IPv4, logs, secrets and data transfer can incur charges. The ALBs, RDS and NAT begin incurring charges during infrastructure bootstrap. This dev configuration skips a final database snapshot. Preserve any needed data separately before teardown.

For teardown, clear both digests and apply a reviewed plan to remove the services and task definitions. Empty this project's ECR repository, including untagged images. From its deployment root run `terraform destroy -var-file=dev.tfvars`. Keep the shared backend bucket and deployment identity available until teardown completes.
