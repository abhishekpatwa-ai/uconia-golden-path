# ================= Golden path: is service ka APNA task security group =================
#
#   ALB SG ──8080──► task SG (sirf is service ke tasks)
#   task SG ──5432──► is service ka DB SG (database.tf)
#
# Shared app SG ki jagah har service ka apna SG, taaki DB "sirf isi service se" allow ho sake.

resource "aws_security_group" "task" {
  name        = "${var.name}-task"
  description = "${var.name} tasks: app port only from the ALB"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-task" }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "App port from the shared ALB only"
  referenced_security_group_id = var.alb_sg_id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "task_all_out" {
  security_group_id = aws_security_group.task.id
  description       = "Outbound: ECR, CloudWatch, Secrets Manager (via NAT), and the database"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
