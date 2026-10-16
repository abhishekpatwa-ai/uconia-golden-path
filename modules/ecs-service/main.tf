# ================= Golden path: ECR + logs + task definition + ECS service + autoscaling =================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ---------- 1. ECR repo: is service ki images ----------
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE" # tag = commit SHA, kabhi overwrite nahi
  force_delete         = true        # lab: destroy par images bhi delete

  image_scanning_configuration {
    scan_on_push = true # pipeline is scan ka result check karke CRITICAL par rukti hai
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

# ---------- 2. Logs ----------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = 7
}

# ---------- 3. Task definition: SIRF PEHLI BAAR ke liye placeholder ----------
# Asli image pipeline deploy karti hai (aur ye "command" hata deti hai).
# Tab tak ek chhota python server /health par 200 deta hai, taaki service healthy rahe.
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "app" # pipeline isi naam ke container ki image badalti hai
    image     = "public.ecr.aws/docker/library/python:3.12-alpine"
    essential = true
    command = ["sh", "-c",
      "mkdir -p /srv/api/info && echo ok > /srv/health && echo '${var.name}: placeholder, waiting for first pipeline deploy' > /srv/api/info/index.html && python -m http.server ${var.container_port} --directory /srv"
    ]
    portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "app"
      }
    }
  }])
}

# ---------- 4. ECS service ----------
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.min_tasks
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids # 2 AZ
    security_groups  = [var.app_sg_id]        # 8080 sirf ALB se
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100 # deploy ke dauraan purane tasks chalte rahein
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true # naye tasks fail → purane revision par wapas
  }

  wait_for_steady_state = true

  # ⭐ Ownership: Terraform service ka dhaancha banata hai, image version pipeline chalati hai.
  # task_definition ignore na karein to har terraform apply pipeline ka deploy ulta kar dega.
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  # Target group pehle ALB rule se juda ho, tabhi ECS use use kar sakta hai
  depends_on = [aws_lb_listener_rule.this]
}

# ---------- 5. Autoscaling (CPU 60% target) ----------
resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_tasks
  max_capacity       = var.max_tasks
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-60"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60
    scale_out_cooldown = 60
    scale_in_cooldown  = 120
  }
}
