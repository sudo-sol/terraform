variable "vpc_name" {
  description = "Name of the VPC to create for the EC2 instance"
  type        = string
}

variable "cidr_block" {
  description = "Specifies the  CIDR block for the VPC."
  type        = string
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
