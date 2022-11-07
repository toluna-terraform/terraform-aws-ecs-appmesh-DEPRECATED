output  "ecs_cluster_info" {
  value = aws_ecs_cluster.ecs_cluster
}

output "ecs_service_info" {
  value = aws_ecs_service.main
}

output "ecs_task_execution_role" {
  value = aws_iam_role.ecs_task_execution_role
}