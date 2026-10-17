# ================= Golden path: optional database (create_database = true) =================
#
#   task SG ──5432──► DB SG ──► RDS PostgreSQL (private subnets, encrypted, backups)
#   Password: RDS khud banata hai aur Secrets Manager mein rakhta hai (KMS encrypted, rotation managed)
#   Task start par execution role secret padhkar container mein DB_PASSWORD bana deta hai

locals {
  db_count = var.create_database ? 1 : 0
  db_name  = replace(var.name, "-", "_") # uconia-api → uconia_api (Postgres naam mein '-' nahi chalta)
}

resource "aws_db_subnet_group" "this" {
  count      = local.db_count
  name       = "${var.name}-db"
  subnet_ids = var.private_subnet_ids # 2 AZ; internet se koi raasta nahi
}

resource "aws_security_group" "db" {
  count       = local.db_count
  name        = "${var.name}-db"
  description = "${var.name} database: 5432 only from ${var.name} tasks"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db" }
}

# ⭐ SG chaining: DB sirf ISI service ke task SG se baat karega, IP se nahi
resource "aws_vpc_security_group_ingress_rule" "db_from_task" {
  count                        = local.db_count
  security_group_id            = aws_security_group.db[0].id
  description                  = "Postgres from ${var.name} tasks only"
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "this" {
  count      = local.db_count
  identifier = "${var.name}-db"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true # encryption at rest (KMS)

  db_name  = local.db_name
  username = "app_admin"

  # ⭐ Password hum kabhi dekhte/likhte nahi: RDS khud banata hai, Secrets Manager mein rakhta hai, rotate karta hai
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [aws_security_group.db[0].id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period = 1 # prod: 7+ din aur point-in-time recovery

  # Lab settings: destroy aasaan ho. Prod mein deletion_protection = true, final snapshot lena
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true
}

# Execution role ko SIRF is DB ka secret padhne ki permission (task start ke waqt)
resource "aws_iam_role_policy" "execution_db_secret" {
  count = local.db_count
  name  = "read-${var.name}-db-secret"
  role  = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.this[0].master_user_secret[0].secret_arn
    }]
  })
}
