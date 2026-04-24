# ==========================================
# SECURITY GROUP - BASTION (subnet public)
# Seul point d'entrée SSH depuis internet
# Restreint à votre IP uniquement
# ==========================================

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "Bastion host - SSH restreint a une IP specifique"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH depuis votre IP uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "SSH vers les instances privees uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_1_cidr]
  }

  tags = { Name = "${var.project_name}-sg-bastion" }
}

# ==========================================
# SECURITY GROUP - EC2 APPLICATIF (subnet privé)
# Accessible uniquement depuis le bastion (SSH)
# et depuis internet via HTTP (port 80)
# ==========================================

resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg-app"
  description = "Instance applicative privee - SSH depuis bastion uniquement"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH depuis le bastion uniquement"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "HTTP depuis le subnet public uniquement"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidr]
  }

  egress {
    description     = "MySQL vers RDS uniquement"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  egress {
    description = "HTTPS sortant pour updates via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP sortant pour updates via NAT"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-app" }
}

# ==========================================
# SECURITY GROUP - RDS (subnet privé)
# Accessible uniquement depuis l'instance EC2 app
# Aucun accès depuis internet, jamais
# ==========================================

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "RDS MySQL - accessible uniquement depuis l'instance app"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-sg-rds" }
}

# Règle séparée pour éviter la référence circulaire entre sg_app et sg_rds
resource "aws_security_group_rule" "rds_ingress_from_app" {
  type                     = "ingress"
  description              = "MySQL depuis l'instance app uniquement"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.app.id
}

# Pas d'egress sur RDS : la base de données ne doit initier aucune connexion sortante
