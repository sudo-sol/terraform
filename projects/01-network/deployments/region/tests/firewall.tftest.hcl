mock_provider "aws" {}

variables {
  name               = "firewall-test"
  availability_zones = ["us-east-1a", "us-east-1b"]
  vpc_cidrs          = jsondecode(file("prod.example.tfvars.json")).network.vpc_cidrs
  private_zone_name  = "example.test"
  firewall           = { allowed_tls_domains = ["example.com"] }
}

run "segmented_tls_policy" {
  command = plan
  module { source = "../../stack" }

  assert {
    condition = aws_networkfirewall_firewall_policy.egress[0].firewall_policy[0].stateful_default_actions == toset([
      "aws:drop_established_app_layer_to_server",
      "aws:alert_established_app_layer_to_server",
    ])
    error_message = "TLS SNI filtering must wait for application data and preserve server responses."
  }
  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.egress[0].rule_group[0].rules_source[0].rules_string, "pass tls $HOME_NET any -> $EXTERNAL_NET 443") && strcontains(aws_networkfirewall_rule_group.egress[0].rule_group[0].rules_source[0].rules_string, "content:\"example.com\"; startswith; endswith;")
    error_message = "The application-aware default must retain the exact-domain TLS port-443 allow rule."
  }
}

run "no_firewall_in_dev" {
  command = plan
  module { source = "../../stack" }
  variables { firewall = null }
  assert {
    condition     = length(aws_networkfirewall_firewall_policy.egress) == 0 && length(aws_networkfirewall_firewall.egress) == 0
    error_message = "Disabling inspection must omit the firewall and its policy."
  }
}
