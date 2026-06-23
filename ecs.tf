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
# La configuration réseau couvre les deux AZ
# (private_1 AZ-a, private_2 AZ-b). Avec
# desired_count = 1, ECS place la tâche dans
# un seul AZ ; le scheduler peut redémarrer
# dans l'autre AZ en cas de défaillance.
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
# depends_on sur le listener : ECS ne peut enregistrer
# les tâches dans le target group que si le listener
# existe déjà. Sans ça, le premier apply peut échouer.
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

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]
}
