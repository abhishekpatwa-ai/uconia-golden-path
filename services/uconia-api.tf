# ================= Service: uconia-api =================
# Nayi service jodni ho? Ye file copy karo, naam/path/priority badlo. Bas.

module "uconia_api" {
  source = "../modules/ecs-service"

  # --- Service ki apni values ---
  name              = "uconia-api"
  github_repo       = "abhishekpatwa-ai/uconia-api" # sirf is repo ki main branch deploy kar sakti hai
  github_owner_id   = 336658880                     # api.github.com/users/abhishekpatwa-ai → "id"
  github_repo_id    = 1422089262                    # api.github.com/repos/abhishekpatwa-ai/uconia-api → "id"
  path_pattern      = "/api/*"
  listener_priority = 100
  create_database   = true # apna RDS PostgreSQL + Secrets Manager password

  # --- Platform values (sab services ke liye same) ---
  cluster_name       = local.platform.cluster_name
  vpc_id             = local.platform.vpc_id
  private_subnet_ids = local.platform.private_subnet_ids
  alb_sg_id          = local.platform.alb_sg_id
  listener_arn       = local.platform.listener_arn
  oidc_provider_arn  = local.platform.oidc_provider_arn
}
