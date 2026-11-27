mock_provider "aws" {}

override_resource {
  target          = module.network.module.vpc.aws_subnet.private["private-1"]
  override_during = plan
  values          = { id = "subnet-0123456789abcdef0" }
}
override_resource {
  target          = module.network.module.vpc.aws_subnet.private["private-2"]
  override_during = plan
  values          = { id = "subnet-0123456789abcdef1" }
}

run "maintenance_capacity" {
  command = plan
  assert {
    condition     = aws_eks_node_group.workers.scaling_config[0].desired_size == 3 && length(aws_eks_node_group.workers.subnet_ids) == 2 && aws_eks_node_group.workers.update_config[0].max_unavailable == 1
    error_message = "Two replicas need a third worker for a single-node drain across the two-subnet group."
  }
  assert {
    condition     = aws_eks_cluster.workers.vpc_config[0].endpoint_private_access && aws_eks_cluster.workers.vpc_config[0].public_access_cidrs == toset([var.operator_cidr])
    error_message = "Workers need private API access and public access must use the operator CIDR."
  }
}

run "reject_open_api" {
  command = plan
  variables { operator_cidr = "0.0.0.0/0" }
  expect_failures = [var.operator_cidr]
}
