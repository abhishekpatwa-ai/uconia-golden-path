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
