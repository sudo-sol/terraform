# EKS worker maintenance

This dev lab runs two HTTP replicas on separate EC2 workers. EKS manages three on-demand AL2023 nodes in private subnets across two Availability Zones. The third worker provides spare capacity during a drain. A readiness probe routes requests to ready pods and a PodDisruptionBudget requires one available replica during voluntary eviction.

## Test locally

From this project directory, with Terraform 1.17.x and kubeconform installed:

```sh
terraform -chdir=deployments/dev/us-west-2 init -backend=false -input=false -lockfile=readonly
terraform -chdir=deployments/dev/us-west-2 validate
terraform -chdir=deployments/dev/us-west-2 test -var-file=dev.example.tfvars
kubeconform -strict -kubernetes-version 1.35.0 -summary workload/demo.yaml
```

The two mock plans check the node group and API endpoint with sample subnet IDs and operator CIDR. The manifest check validates the Deployment, Service and PodDisruptionBudget against Kubernetes 1.35 schemas. Initial setup downloads the locked provider and public schemas.

Local verification on November 27, 2026 used Terraform 1.17.2 and the locked AWS provider 6.72.0 in a local mirror. Backend-disabled initialization, validation, both mock plans and all three Kubernetes 1.35 manifest schemas passed. The EC2 drain and request loop remain live acceptance checks.

## AWS lab procedure

For a future account-backed run, use a bootstrap S3 bucket and an identity authorized to manage this lab's VPC, IAM roles, EKS cluster and node group. From `deployments/dev/us-west-2`, copy the two dev examples to ignored `dev.tfbackend` and `dev.tfvars`. Set the bucket, matching account IDs and your public IPv4 CIDR. The sample uses Kubernetes 1.35. Confirm regional standard support before deployment. [EKS version calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)

Initialize with `terraform init -reconfigure -backend-config=dev.tfbackend`, review `terraform plan -var-file=dev.tfvars -out=dev.tfplan`, then apply the reviewed plan in your own account. Use the creating identity and an appropriately versioned kubectl. From that deployment directory:

```sh
export KUBECONFIG="$PWD/demo.kubeconfig"
aws eks update-kubeconfig --region us-west-2 --name "$(terraform output -raw cluster_name)"
kubectl apply -f ../../../workload/demo.yaml
kubectl rollout status deployment/worker-demo
kubectl get pods -l app=worker-demo -o wide
```

From another terminal using the same kubeconfig, record request results during the drain. The API server's Service proxy continues addressing the Service as pods move.

```sh
while true; do
  if kubectl --request-timeout=5s get --raw /api/v1/namespaces/default/services/http:worker-demo:http/proxy/ >/dev/null; then
    date '+%T OK'
  else
    date '+%T FAILED'
  fi
  sleep 1
done
```

In the first terminal, select an occupied worker. Drain only this disposable lab node. The command evicts pods and discards their local emptyDir data.

```sh
node=$(kubectl get pods -l app=worker-demo -o jsonpath='{.items[0].spec.nodeName}')
kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=10m
kubectl rollout status deployment/worker-demo --timeout=5m
kubectl get pods -l app=worker-demo -o wide
kubectl uncordon "$node"
```

Verify that two replicas are ready on other workers and inspect the request log for failures. Uncordon the node even if drain verification fails. Stop the probe, delete the workload with `kubectl delete -f ../../../workload/demo.yaml`, then run `terraform destroy -var-file=dev.tfvars` in the deployment root. The EKS control plane, three EC2 instances and disks, NAT gateway, IPv4 address and data transfer incur costs while provisioned. The single NAT gateway is a dev trade-off.
