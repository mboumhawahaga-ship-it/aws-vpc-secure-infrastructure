output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.main.id
}

output "bastion_public_ip" {
  description = "IP publique du bastion - utiliser pour SSH"
  value       = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  description = "IP privée de l'instance applicative"
  value       = aws_instance.app.private_ip
}

output "rds_endpoint" {
  description = "Endpoint RDS (accessible uniquement depuis le subnet privé)"
  value       = aws_db_instance.mysql.endpoint
}

output "ssh_bastion_command" {
  description = "Commande SSH pour accéder au bastion"
  value       = "ssh -i <votre-cle.pem> ec2-user@${aws_instance.bastion.public_ip}"
}

output "ssh_app_via_bastion_command" {
  description = "Commande SSH pour accéder à l'instance privée via le bastion"
  value       = "ssh -i <votre-cle.pem> -J ec2-user@${aws_instance.bastion.public_ip} ec2-user@${aws_instance.app.private_ip}"
}
