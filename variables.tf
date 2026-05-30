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
  description = "CIDR du subnet public (ALB)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR du subnet privé 1 (Fargate AZ a)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR du subnet privé 2 (Fargate AZ b)"
  type        = string
  default     = "10.0.3.0/24"
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

# ==========================================
# Variables conteneur (ajoutées avec ecs.tf)
# ==========================================

variable "container_cpu" {
  description = "CPU alloué à la tâche Fargate (unités : 1 vCPU = 1024)"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Mémoire allouée à la tâche Fargate (MiB)"
  type        = number
  default     = 512
}

variable "container_port" {
  description = "Port exposé par le conteneur (nginx = 80, app réelle = à ajuster)"
  type        = number
  default     = 80
}

variable "app_desired_count" {
  description = "Nombre de tâches Fargate souhaitées"
  type        = number
  default     = 1
}
