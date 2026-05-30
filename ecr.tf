# ==========================================
# DATA SOURCE — compte AWS courant
# Utilisé pour construire l'URI de l'image
# dans ecs.tf (ex: 123456789.dkr.ecr.eu-west-3...)
# ==========================================

data "aws_caller_identity" "current" {}

# ==========================================
# ECR PULL-THROUGH CACHE RULE
#
# Problème : ECR Public (public.ecr.aws) n'est
# PAS accessible via les VPC endpoints. Un pull
# direct depuis un VPC sans NAT = CannotPullContainerError.
#
# Solution : cette règle crée un "miroir" dans
# le registre privé. Quand Fargate demande
#   <account>.dkr.ecr.eu-west-3.amazonaws.com/ecr-public/nginx/nginx:stable-alpine
# ECR va chercher l'image sur public.ecr.aws/nginx/nginx:stable-alpine
# la première fois, puis la sert depuis le cache privé.
# Le pull passe alors par les endpoints ecr.api + ecr.dkr déjà en place.
# ==========================================

resource "aws_ecr_pull_through_cache_rule" "ecr_public" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
  # ECR Public est un registre ouvert : aucune credential requise.
}

# ==========================================
# LOCAL : URI de l'image de test nginx
#
# Référencé dans ecs.tf pour la task definition.
# Pour passer à l'app réelle, changer cette valeur.
# Format : <account>.dkr.ecr.<region>.amazonaws.com/<prefix>/<image>:<tag>
# ==========================================

locals {
  nginx_image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecr-public/nginx/nginx:stable-alpine"
}
