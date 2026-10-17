# ================= Golden path: inputs for one ECS service =================
# हर नई service बस ये values देती है, बाकी सब module बनाता है

# ---------- Service की पहचान ----------
variable "name" {
  description = "Service name, used for ECR repo, ECS service, roles, logs (e.g. uconia-api)"
  type        = string
}

variable "github_owner_id" {
  description = "GitHub owner (user/org) ka numeric ID. GitHub ab OIDC 'sub' mein naam ke saath ID bhi bhejta hai"
  type        = number
}

variable "github_repo_id" {
  description = "GitHub repo ka numeric ID (https://api.github.com/repos/OWNER/REPO se 'id')"
  type        = number
}

variable "github_repo" {
  description = "Service ki GitHub repo (owner/name). Sirf isi repo ki main branch deploy kar paayegi"
  type        = string
}

# ---------- App settings ----------
variable "container_port" {
  description = "Port the app listens on"
  type        = number
  default     = 8080 # .NET images aur hamara app-sg dono 8080
}

variable "health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health" # golden rule: har service ka /health endpoint ho
}

variable "cpu" {
  type    = number
  default = 256 # 0.25 vCPU
}

variable "memory" {
  type    = number
  default = 512 # MB
}

# ---------- Scaling ----------
variable "min_tasks" {
  type    = number
  default = 2 # HA: kam se kam 2 (ek per AZ)
}

variable "max_tasks" {
  type    = number
  default = 4
}

# ---------- ALB routing ----------
variable "path_pattern" {
  description = "Kaun se URL paths is service par jaayein (e.g. /api/*)"
  type        = string
}

variable "listener_priority" {
  description = "ALB rule priority, har service ka alag (chhota number pehle check hota hai)"
  type        = number
}

# ---------- Database (optional) ----------
variable "create_database" {
  description = "true = is service ka apna RDS PostgreSQL + Secrets Manager password"
  type        = bool
  default     = false
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro" # lab ke liye sabse chhota
}

variable "db_multi_az" {
  description = "Prod mein true (standby doosre AZ mein). Lab mein false, cost bachane ke liye"
  type        = bool
  default     = false
}

# ---------- Platform se aane wali values (har service ke liye same) ----------
variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string } # task SG mein port sirf isi ALB SG se khulta hai
variable "listener_arn" { type = string }
variable "oidc_provider_arn" { type = string }