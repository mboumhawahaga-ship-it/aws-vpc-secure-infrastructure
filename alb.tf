# ==========================================
# APPLICATION LOAD BALANCER
#
# Point d'entrée public unique. L'ALB reçoit
# le trafic HTTP depuis internet et le distribue
# aux tâches Fargate dans les subnets privés.
#
# Deux subnets publics (AZ-a + AZ-b) : AWS exige
# au moins 2 AZ pour un ALB internet-facing.
# internal = false : ALB public, exposé sur internet.
# ==========================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]

  # Protection contre la suppression accidentelle via la console.
  # Ne bloque pas terraform destroy.
  enable_deletion_protection = false
}

# ==========================================
# TARGET GROUP
#
# Liste des destinations vers lesquelles l'ALB
# envoie le trafic. Type "ip" obligatoire pour
# Fargate : chaque tâche a sa propre IP dans le
# VPC, pas d'instance EC2 à cibler.
#
# ECS enregistre/désenregistre automatiquement
# les IPs quand les tâches démarrent ou s'arrêtent.
#
# Health check sur / : l'ALB sonde nginx toutes
# les 30s. Si la tâche ne répond plus, l'ALB
# arrête de lui envoyer du trafic et ECS redémarre
# la tâche (circuit breaker activé dans ecs.tf).
# ==========================================

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

# ==========================================
# LISTENER HTTP
#
# Écoute sur le port 80 et transfère tout le
# trafic vers le target group.
# Le WAF (étape 6) s'associera à l'ALB et
# filtrera le trafic avant qu'il atteigne
# ce listener.
# ==========================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
