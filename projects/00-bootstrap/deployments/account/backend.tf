terraform {
  # Bootstrap state stays local. Back up terraform.tfstate privately after each apply.
  backend "local" {
    path = "terraform.tfstate"
  }
}
