variable "account_id" {
  description = "AWS account used for this sandbox."
  type        = string
}

variable "state_bucket_names" {
  description = "Names of the dev and prod state buckets."
  type = object({
    dev  = string
    prod = string
  })
}

variable "tags" {
  description = "Additional tags for the bootstrap resources."
  type        = map(string)
  default     = {}
}

variable "github_oidc_subjects" {
  description = "GitHub OIDC subjects per role: dev supports branch patterns; prod uses exact subjects."
  type = object({
    dev  = list(string)
    prod = list(string)
  })
}
