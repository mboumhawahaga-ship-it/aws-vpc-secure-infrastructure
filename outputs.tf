# ==========================================
# OUTPUTS — valeurs utiles après terraform apply
# ==========================================

output "alb_url" {
  description = "URL de l'ALB — coller dans un navigateur pour valider le 200"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nom du service ECS"
  value       = aws_ecs_service.app.name
}

output "log_group_name" {
  description = "Log group CloudWatch des conteneurs"
  value       = aws_cloudwatch_log_group.app.name
}

output "ecr_image_uri" {
  description = "URI de l'image de test dans le registre ECR privé"
  value       = local.nginx_image_uri
}

# Commande prête à l'emploi pour se connecter au conteneur
# sans SSH. Remplacer <TASK_ID> par l'ID obtenu via :
#   aws ecs list-tasks --cluster <cluster> --service-name <service>
output "ecs_exec_command" {
  description = "Commande ECS Exec pour debug (remplacer <TASK_ID>)"
  value       = "aws ecs execute-command --cluster ${aws_ecs_cluster.main.name} --task <TASK_ID> --container app --interactive --command /bin/sh --region ${var.aws_region}"
}

output "inference_profile_arn" {
  description = "ARN de l'inference profile Bedrock (à utiliser dans le task role)"
  value       = aws_bedrock_inference_profile.app.arn
}
