output "load_balancer_dns" {
  description = "DNS names for the demo application load balancers."
  value       = { for name, cluster in module.ecs : name => cluster.alb_dns_name }
}
