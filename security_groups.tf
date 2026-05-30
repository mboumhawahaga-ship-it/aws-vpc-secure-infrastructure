# ==========================================
# SECURITY GROUP — ALB
# Reçoit le trafic HTTP/HTTPS depuis internet.
# Seul composant exposé publiquement.
# ==========================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "ALB - HTTP/HTTPS depuis internet"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-sg-alb" }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  description       = "HTTP public"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  description       = "HTTPS public"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# L'ALB transfère le trafic vers les tâches Fargate sur le port 80 (nginx).
resource "aws_security_group_rule" "alb_egress_to_fargate" {
  type                     = "egress"
  description              = "To Fargate tasks (container port)"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.fargate.id
}

# ==========================================
# SECURITY GROUP — FARGATE
# Tâches privées dans les subnets privés.
# Accepte uniquement le trafic de l'ALB.
# Sort uniquement vers les VPC endpoints (HTTPS).
# ==========================================

resource "aws_security_group" "fargate" {
  name        = "${var.project_name}-sg-fargate"
  description = "Fargate tasks - ingress ALB, egress VPC endpoints"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-sg-fargate" }
}

resource "aws_security_group_rule" "fargate_ingress_from_alb" {
  type                     = "ingress"
  description              = "From ALB"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fargate.id
  source_security_group_id = aws_security_group.alb.id
}

# Tout le trafic sortant des tâches passe par les VPC endpoints (port 443).
# Couvre : ECR (pull image), Bedrock, CloudWatch Logs, SSM (ECS Exec).
resource "aws_security_group_rule" "fargate_egress_to_endpoints" {
  type                     = "egress"
  description              = "HTTPS vers VPC endpoints (ECR, Bedrock, logs, SSM)"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fargate.id
  source_security_group_id = aws_security_group.endpoints.id
}

# ==========================================
# SECURITY GROUP — VPC ENDPOINTS
# Autorise uniquement les tâches Fargate
# à contacter les services AWS via PrivateLink.
# ==========================================

resource "aws_security_group" "endpoints" {
  name        = "${var.project_name}-sg-endpoints"
  description = "VPC endpoints - ingress 443 depuis Fargate uniquement"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-sg-endpoints" }
}

resource "aws_security_group_rule" "endpoints_ingress_from_fargate" {
  type                     = "ingress"
  description              = "HTTPS from Fargate tasks only"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints.id
  source_security_group_id = aws_security_group.fargate.id
}
