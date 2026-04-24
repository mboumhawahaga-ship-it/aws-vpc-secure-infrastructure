# ==========================================
# MOT DE PASSE RDS - Généré automatiquement
# Jamais hardcodé dans le code
# ==========================================

resource "random_password" "rds_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}?"
}

# ==========================================
# RDS - MySQL sécurisé
# Privé, chiffré, IAM auth, pas d'accès public
# ==========================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "mysql" {
  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.rds_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  iam_database_authentication_enabled = true
  publicly_accessible                 = false

  backup_retention_period    = 7
  backup_window              = "03:00-04:00"
  maintenance_window         = "mon:04:00-mon:05:00"
  auto_minor_version_upgrade = true
  deletion_protection        = false
  skip_final_snapshot        = true

  tags = { Name = "${var.project_name}-mysql" }
}
