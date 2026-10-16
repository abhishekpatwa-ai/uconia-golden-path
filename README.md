# uconia-golden-path

The paved road for every Uconia service: one Terraform module for the service's AWS resources, and one reusable pipeline to build and deploy it. Runs on top of [uconia-infra](https://github.com/abhishekpatwa-ai/uconia-infra).

| Path | What |
|---|---|
| `modules/ecs-service/` | One service's resources: ECR repo, task definition, ECS service, autoscaling, target group, ALB rule, execution/task roles, GitHub deploy role |
| `services/` | One file per service, calling the module (e.g. `uconia-api.tf`); `platform.tf` reads uconia-infra's outputs |
| `.github/workflows/ecs-deploy.yml` | Golden pipeline: OIDC login → build → push to ECR → scan gate → new task definition revision → rolling deploy |

## Naming convention

The service name is the link between Terraform and the pipeline. For `uconia-api`, Terraform creates the ECR repo, task definition family and ECS service all named `uconia-api`, plus the role `uconia-api-github-deploy`. The pipeline finds them in AWS by the same name. It never reads these Terraform files.

## Add a new service

1. Create the service repo with a Dockerfile, a `/health` endpoint, and a 5-line `.github/workflows/deploy.yml` (copy it from [uconia-api](https://github.com/abhishekpatwa-ai/uconia-api)).
2. Copy `services/uconia-api.tf`, change `name`, `github_repo`, the GitHub IDs, `path_pattern` and `listener_priority`.
3. `terraform apply` in `services/`, then push to the service repo's `main` branch.

## Ownership

Terraform owns the infrastructure. The pipeline owns the image version: the ECS service ignores `task_definition` changes, so `terraform apply` never rolls back a deployment.
