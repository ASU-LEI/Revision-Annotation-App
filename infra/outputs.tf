output "ecr_repository_url" {
  value = data.aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = data.aws_ecs_cluster.shared.cluster_name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "ecs_task_definition_family" {
  value = aws_ecs_task_definition.app.family
}

output "load_balancer_url" {
  value = local.domain_enabled ? "https://${local.backend_domain_name}" : "http://${data.aws_lb.shared.dns_name}"
}

output "application_domain_name" {
  value = local.domain_enabled ? local.backend_domain_name : null
}
