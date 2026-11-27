locals {
  tags = {
    Environment = var.environment,
    Project     = var.project_name,
    Version     = var.project_version,
    ManagedBy   = var.managed_by
  }
}
