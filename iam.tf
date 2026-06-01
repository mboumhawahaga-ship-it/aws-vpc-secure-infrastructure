# ==========================================
# IAM — EXECUTION ROLE
#
# Utilisé par ECS lui-même (pas par l'app)
# pour démarrer la tâche :
#   - pull de l'image depuis ECR privé
#   - création du dépôt pull-through cache
#     au premier pull
#   - écriture des logs dans CloudWatch
#
# Si un attaquant compromet le conteneur,
# il obtient le TASK ROLE (ci-dessous),
# pas celui-ci.
# ==========================================

resource "aws_iam_role" "ecs_execution_role" {
  name        = "${var.project_name}-ecs-execution-role"
  description = "ECS execution role - pull ECR image + write logs"

  # aws:SourceArn + aws:SourceAccount : restreint l'AssumeRole aux
  # tâches ECS de CE compte uniquement. Sans ça, n'importe quelle
  # task definition du compte peut assumer ce rôle.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
        }
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# Managed policy AWS : permissions standard pour l'execution role ECS.
# Couvre : pull ECR, écriture CloudWatch Logs, lecture Secrets Manager
# (non utilisé ici, mais inclus dans la policy officielle).
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permissions supplémentaires pour le pull-through cache.
# Sans elles, ECS peut pull depuis un dépôt existant mais pas
# créer le dépôt miroir au premier pull d'une nouvelle image.
resource "aws_iam_role_policy" "ecs_execution_pull_through" {
  name = "ecr-pull-through-cache"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:BatchImportUpstreamImage",
        "ecr:CreateRepository"
      ]
      Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/ecr-public/*"
    }]
  })
}

# ==========================================
# IAM — TASK ROLE
#
# Utilisé par l'APPLICATION dans le conteneur.
# Principe de moindre privilège : l'app ne peut
# faire que ce dont elle a besoin.
#
# Phase test (nginx) : permissions SSM pour
# ECS Exec (debug sans SSH).
# Phase prod : ajouter bedrock:InvokeModel
# sur l'inference profile (dans monitoring.tf).
# ==========================================

resource "aws_iam_role" "ecs_task_role" {
  name        = "${var.project_name}-ecs-task-role"
  description = "ECS task role - app permissions (SSM exec + Bedrock)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
        }
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# ECS Exec : permet de se connecter à un conteneur en cours
# d'exécution via "aws ecs execute-command" sans SSH ni bastion.
# Les quatre actions ssmmessages sont toutes requises ;
# elles ne supportent pas de restriction par ressource.
resource "aws_iam_role_policy" "ecs_task_ssm_exec" {
  name = "ecs-exec-ssm"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}
