variable "state_bucket_names" {
  description = "State bucket names for dev in us-west-2 and prod in us-east-1."
  type = object({
    dev  = string
    prod = string
  })
}

variable "github_oidc_subjects" {
  description = "GitHub OIDC subjects per role: dev supports branch patterns; prod uses exact subjects."
  type = object({
    dev  = list(string)
    prod = list(string)
  })
}
