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

    # DB ki details: secret NAHI hain, isliye plain environment variables
    environment = var.create_database ? [
      { name = "DB_HOST", value = aws_db_instance.this[0].address },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = local.db_name },
    ] : []

    # ⭐ Secret: value task definition mein kabhi nahi likhi jaati, sirf secret ka ARN.
    # Task start par EXECUTION ROLE Secrets Manager se padhkar env variable bana deta hai.
    secrets = var.create_database ? [
      { name = "DB_USER", valueFrom = "${aws_db_instance.this[0].master_user_secret[0].secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${aws_db_instance.this[0].master_user_secret[0].secret_arn}:password::" },
    ] : []

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
    subnets          = var.private_subnet_ids       # 2 AZ
    security_groups  = [aws_security_group.task.id] # is service ka apna SG: 8080 sirf ALB se (security.tf)
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
