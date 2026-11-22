variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type = list(object({
    name : string
    images_to_keep : number
    scan_on_push : bool
  }))
}

## Tagging Parameters
variable "environment" {
  type = string
}

variable "project_version" {
  type = string
}

variable "project_name" {
  type = string
}

variable "managed_by" {
  type = string
}
