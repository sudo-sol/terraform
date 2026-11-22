locals {
  allowed_tls_domains = local.inspection_enabled ? sort(distinct([
    for domain in var.firewall.allowed_tls_domains : lower(domain)
  ])) : []
}

resource "aws_networkfirewall_rule_group" "egress" {
  count = local.inspection_enabled ? 1 : 0

  name     = "${var.name}-tls-egress"
  capacity = 100
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = [var.vpc_cidrs.spoke_a, var.vpc_cidrs.spoke_b]
        }
      }
    }

    rules_source {
      rules_string = join("\n", [
        for index, domain in local.allowed_tls_domains :
        "pass tls $HOME_NET any -> $EXTERNAL_NET 443 (tls.sni; content:\"${domain}\"; startswith; endswith; nocase; flow:to_server,established; sid:${1000001 + index}; rev:1;)"
      ])
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "egress" {
  count = local.inspection_enabled ? 1 : 0

  name = "${var.name}-egress"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    # Wait for application data (including segmented TLS ClientHello/SNI)
    # before rejecting unmatched client traffic; preserve server responses.
    stateful_default_actions = [
      "aws:drop_established_app_layer_to_server",
      "aws:alert_established_app_layer_to_server",
    ]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.egress[0].arn
      priority     = 100
    }
  }
}

resource "aws_networkfirewall_firewall" "egress" {
  count = local.inspection_enabled ? 1 : 0

  name                     = "${var.name}-egress"
  vpc_id                   = aws_vpc.this["egress"].id
  firewall_policy_arn      = aws_networkfirewall_firewall_policy.egress[0].arn
  delete_protection        = false
  subnet_change_protection = false

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }
}

resource "aws_cloudwatch_log_group" "firewall" {
  for_each = local.inspection_enabled ? toset(["FLOW", "ALERT"]) : toset([])

  name              = "/aws/network-firewall/${var.name}/${lower(each.key)}"
  retention_in_days = var.firewall.log_retention_days
}

resource "aws_networkfirewall_logging_configuration" "egress" {
  count = local.inspection_enabled ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.egress[0].arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = aws_cloudwatch_log_group.firewall
      content {
        log_destination      = { logGroup = log_destination_config.value.name }
        log_destination_type = "CloudWatchLogs"
        log_type             = log_destination_config.key
      }
    }
  }
}
