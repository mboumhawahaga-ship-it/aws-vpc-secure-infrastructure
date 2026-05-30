# ==========================================
# LOCAL — nom du log group CloudWatch
#
# Défini ici pour être utilisé dans la task
# definition. Le log group lui-même est créé
# dans monitoring.tf avec le même nom.
# ==========================================

locals {
  log_group_name = "/ecs/${var.project_name}"
}

# ==========================================
# ECS CLUSTER
#
# Un cluster est juste un espace logique qui
# regroupe des services et des tâches.
# Container Insights = métriques CloudWatch
# enrichies (CPU/mémoire par tâche, etc.).
# ==========================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ==========================================
# TASK DEFINITION
#
# Le "blueprint" d'un conteneur : image, CPU,
# mémoire, ports, logs, rôles IAM.
# Chaque déploiement crée une nouvelle révision
# (la précédente est conservée, jamais écrasée).
#
# network_mode = "awsvpc" : obligatoire pour
# Fargate — chaque tâche reçoit sa propre
# interface réseau (ENI) et sa propre IP privée.
# ==========================================

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = local.nginx_image_uri
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    # awslogs : driver natif CloudWatch Logs.
    # stream-prefix crée des chemins lisibles :
    # /ecs/<project>/ecs/app/<task-id>
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = local.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ==========================================
# ECS SERVICE
#
# Un service maintient N tâches en vie en
# permanence et les redémarre si elles tombent.
# Multi-AZ : les tâches sont réparties sur
# private_1 (AZ a) et private_2 (AZ b).
#
# assign_public_ip = false : les tâches sont
# dans les subnets privés, aucune IP publique.
#
# enable_execute_command = true : active ECS Exec
# pour déboguer via SSM sans SSH ni bastion.
# Usage : aws ecs execute-command --cluster ... \
#   --task <id> --container app --interactive \
#   --command "/bin/sh"
#
# IMPORTANT : le bloc load_balancer sera ajouté
# dans alb.tf (étape 5) une fois le target group
# défini. Sans lui, les tâches démarrent mais
# ne reçoivent pas encore de trafic de l'ALB.
# ==========================================

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.fargate.id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
