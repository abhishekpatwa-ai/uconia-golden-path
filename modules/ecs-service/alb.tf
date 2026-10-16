# ================= Golden path: har service ka apna target group + shared ALB par ek rule =================
#
#   ALB listener :80 ──rule (priority N, path /api/*)──► is service ka target group ──► tasks :8080

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg" # max 32 characters
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate task ka instance ID nahi hota, sirf ENI ka IP

  deregistration_delay = 30

  health_check {
    path                = var.health_check_path # golden rule: /health
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  priority     = var.listener_priority # har service ka alag; chhota number pehle check

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = [var.path_pattern]
    }
  }
}
