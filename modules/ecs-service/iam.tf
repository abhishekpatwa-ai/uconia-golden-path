# ================= Golden path: is service ke 3 roles =================
#
#   execution role → ECS agent: image pull, logs, secrets padhna (task START karte waqt)
#   task role      → app ka code: runtime par AWS calls (abhi khaali = least privilege)
#   deploy role    → service ki GitHub repo (OIDC): sirf ISI service ko deploy kar sake

locals {
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.region
  github_owner     = split("/", var.github_repo)[0] # abhishekpatwa-ai
  github_repo_name = split("/", var.github_repo)[1] # uconia-api
}

# ---------- Trust: ECS tasks ye roles pehen sakte hain ----------
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------- 1. Execution role ----------
resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # ECR pull + CloudWatch Logs
}

# ---------- 2. Task role (app ki AWS identity) ----------
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# ---------- 3. Deploy role: sirf is service ki GitHub repo ki main branch ----------
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # GitHub ka naya 'sub' format naam ke saath numeric IDs bhejta hai:
    #   repo:abhishekpatwa-ai@336658880/uconia-api@1422089262:ref:refs/heads/main
    # IDs kabhi nahi badalte: koi repo delete karke SAME NAAM se nayi bana le, to bhi deploy nahi kar paayega.
    # Purana format (sirf naam) bhi allow hai, taaki dono tarah ke tokens chalein.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github_owner}@${var.github_owner_id}/${local.github_repo_name}@${var.github_repo_id}:ref:refs/heads/main",
        "repo:${var.github_repo}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.name}-github-deploy" # golden pipeline isi naam se role dhoondhti hai
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "deploy" {
  # ECR login (kisi repo tak restrict nahi hota)
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Sirf APNI repo mein push + scan result padhna
  statement {
    sid = "EcrPushAndScan"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:StartImageScan", # scan na chala ho to pipeline khud shuru kare
    ]
    resources = [aws_ecr_repository.this.arn]
  }

  # Naya task definition revision (resource-level restriction support nahi)
  statement {
    sid       = "EcsTaskDefinition"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  # Sirf APNI service update
  statement {
    sid       = "EcsDeployOwnService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = ["arn:aws:ecs:${local.region}:${local.account_id}:service/${var.cluster_name}/${var.name}"]
  }

  # Sirf APNE 2 roles, sirf ECS ko
  statement {
    sid       = "PassOwnRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-${var.name}"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
