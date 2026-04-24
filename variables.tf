variable "aws_region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "CIDR block du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR du subnet public (bastion)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR du subnet privé 1 (EC2 applicatif)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR du subnet privé 2 (RDS)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "allowed_ssh_cidr" {
  description = "Votre IP publique uniquement pour SSH sur le bastion (ex: 203.0.113.10/32)"
  type        = string
  # Remplacer par : curl ifconfig.me
  default     = "REMPLACER_PAR_VOTRE_IP/32"
}

variable "ec2_ami" {
  description = "AMI Amazon Linux 2023 - eu-west-3"
  type        = string
  default     = "ami-00ac45f3035ff009e"
}

variable "ec2_instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "db_name" {
  description = "Nom de la base de données"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Nom d'utilisateur admin RDS"
  type        = string
  default     = "dbadmin"
}

variable "project_name" {
  description = "Nom du projet pour le tagging"
  type        = string
  default     = "vpc-secure-infra"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "key_pair_name" {
  description = "Nom de la key pair AWS pour accès SSH (créer via AWS Console > EC2 > Key Pairs)"
  type        = string
  default     = "REMPLACER_PAR_VOTRE_KEY_PAIR"
}
