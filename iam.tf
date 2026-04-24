# ==========================================
# IAM - Least Privilege pour EC2
# Permissions minimales : lire le secret RDS + auth IAM RDS
# ==========================================

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2_app_role" {
  name        = "${var.project_name}-ec2-role"
  description = "Rôle EC2 - accès minimal RDS IAM auth + lecture secret"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.project_name}-ec2-role" }
}

# Permission 1 : authentification IAM à RDS uniquement
resource "aws_iam_policy" "rds_iam_auth" {
  name        = "${var.project_name}-rds-iam-auth"
  description = "Autoriser uniquement la connexion IAM à cette instance RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.mysql.resource_id}/${var.db_username}"
    }]
  })
}

# Permission 2 : lire le mot de passe RDS depuis le state Terraform
# En production : remplacer par Secrets Manager
resource "aws_iam_policy" "read_rds_secret" {
  name        = "${var.project_name}-read-rds-secret"
  description = "Placeholder - en production utiliser Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = "secretsmanager:*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_rds_auth" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.rds_iam_auth.arn
}

resource "aws_iam_role_policy_attachment" "attach_read_secret" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.read_rds_secret.arn
}

resource "aws_iam_instance_profile" "ec2_app_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_app_role.name
}
