output "ecr_repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn # service repo ki pipeline ye role leti hai
}

output "log_group" {
  value = aws_cloudwatch_log_group.this.name
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "db_endpoint" {
  value = var.create_database ? aws_db_instance.this[0].address : null
}

output "db_secret_arn" {
  value = var.create_database ? aws_db_instance.this[0].master_user_secret[0].secret_arn : null # password yahan, value nahi
}

output "task_security_group_id" {
  value = aws_security_group.task.id
}
