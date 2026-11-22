mock_provider "aws" {}

run "dev_sample" {
  command = plan
  variables {
    account_id = "123456789012"
    target     = "dev"
    network    = jsondecode(file("dev.example.tfvars.json")).network
  }
}

run "prod_sample" {
  command = plan
  variables {
    account_id = "123456789012"
    target     = "prod"
    network    = jsondecode(file("prod.example.tfvars.json")).network
  }
}
