variable "account_id" {
  description = "The 12-digit AWS account ID used by both providers and the bootstrap identity policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "account_name" {
  description = "Optional human-readable AWS account label, used for the AccountName tag."
  type        = string
  default     = null
}

variable "state_bucket_names" {
  description = "Names of the dev and prod state buckets."
  type = object({
    dev  = string
    prod = string
  })

  validation {
    condition = alltrue([
      for name in [var.state_bucket_names.dev, var.state_bucket_names.prod] :
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", name))
    ]) && var.state_bucket_names.dev != var.state_bucket_names.prod
    error_message = "Supply two distinct lowercase S3 bucket names of 3–63 characters."
  }
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
