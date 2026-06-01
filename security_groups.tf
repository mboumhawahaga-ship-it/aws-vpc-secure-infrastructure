# ==========================================
# SECURITY GROUP — ALB
# Reçoit le trafic HTTP depuis internet.
# Seul composant exposé publiquement.
# Pas de règle HTTPS : aucun listener TLS
# n'est configuré (hors périmètre de ce projet).
#
# egress = [] : supprime la règle AWS par défaut
# "allow all outbound". Les règles egress sont gérées
# exclusivement via aws_vpc_security_group_egress_rule
# (compatibles avec egress = [], contrairement à
# aws_security_group_rule).
# ==========================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "ALB - HTTP port 80 depuis internet"
  vpc_id      = aws_vpc.main.id

  egress = []

  tags = { Name = "${var.project_name}-sg-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP public"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_egress_to_fargate" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To Fargate tasks (container port)"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.fargate.id
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

  egress = []

  tags = { Name = "${var.project_name}-sg-fargate" }
}

resource "aws_vpc_security_group_ingress_rule" "fargate_ingress_from_alb" {
  security_group_id            = aws_security_group.fargate.id
  description                  = "From ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# Tout le trafic sortant passe par les VPC endpoints (port 443).
# Couvre : ECR (pull image), Bedrock, CloudWatch Logs, SSM (ECS Exec).
resource "aws_vpc_security_group_egress_rule" "fargate_egress_to_endpoints" {
  security_group_id            = aws_security_group.fargate.id
  description                  = "HTTPS vers VPC endpoints (ECR, Bedrock, logs, SSM)"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.endpoints.id
}

# ==========================================
# SECURITY GROUP — VPC ENDPOINTS
# Autorise uniquement les tâches Fargate
# à contacter les services AWS via PrivateLink.
# Les endpoints n'initient pas de connexions
# sortantes : egress = [] est intentionnel.
# ==========================================

resource "aws_security_group" "endpoints" {
  name        = "${var.project_name}-sg-endpoints"
  description = "VPC endpoints - ingress 443 depuis Fargate uniquement"
  vpc_id      = aws_vpc.main.id

  egress = []

  tags = { Name = "${var.project_name}-sg-endpoints" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_ingress_from_fargate" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from Fargate tasks only"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.fargate.id
}
