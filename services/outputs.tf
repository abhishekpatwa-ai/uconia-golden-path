output "uconia_api" {
  value = {
    ecr_repository_url = module.uconia_api.ecr_repository_url
    deploy_role_arn    = module.uconia_api.deploy_role_arn
    url                = "${data.terraform_remote_state.alb.outputs.alb_url}/api/info"
    db_endpoint        = module.uconia_api.db_endpoint
    db_secret_arn      = module.uconia_api.db_secret_arn
  }
}
