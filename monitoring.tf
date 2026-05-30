# ==========================================
# CLOUDWATCH LOG GROUP
#
# Reçoit les logs des conteneurs Fargate.
# Le nom "/ecs/<project>" est référencé dans
# la task definition (ecs.tf) via local.log_group_name.
# retention_in_days = 30 : compromis coût/observabilité.
# ==========================================

resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group_name
  retention_in_days = 30
}

# ==========================================
# AWS BUDGET
#
# Alerte email quand les dépenses réelles du
# mois atteignent 80% du seuil (var.budget_limit_usd).
# Ex : seuil = 50 USD → alerte à 40 USD.
#
# Ne bloque rien : c'est une alerte, pas un coupe-circuit.
# Le WAF rate-limit est la vraie protection coût côté Bedrock.
# ==========================================

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

# ==========================================
# BEDROCK APPLICATION INFERENCE PROFILE
#
# Un inference profile est un "alias taggable"
# vers un modèle Bedrock. Sans lui, les appels
# Bedrock apparaissent dans Cost Explorer comme
# une ligne générique "Amazon Bedrock".
#
# Avec lui : chaque appel est taggé Project +
# Environment → Cost Explorer peut ventiler le
# coût par workload, par env, par inférence.
#
# copy_from : pointe vers le modèle fondation.
# Le tag CostCenter est un cost allocation tag
# à activer dans Billing > Cost Allocation Tags.
# ==========================================

resource "aws_bedrock_inference_profile" "app" {
  name = "${var.project_name}-inference-profile"

  model_source {
    copy_from = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}"
  }

  tags = {
    CostCenter = var.project_name
  }
}
