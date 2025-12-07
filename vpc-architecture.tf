# Notre VPC - Le réseau virtuel principal
resource "aws_vpc" "mon_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Mon-VPC-Certification"
  }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.mon_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-3a"

    tags = {
        Name = "Subnet-Public"
    }
    
    }

resource "aws_subnet" "private_1" {
    vpc_id = aws_vpc.mon_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-3a"
    tags = {
        Name = "Subnet-Private-1"
    }
}

# Deuxième subnet privé pour RDS (haute disponibilité)
resource "aws_subnet" "private_2" {
    vpc_id = aws_vpc.mon_vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-west-3b"
    tags = {
        Name = "Subnet-Private-2"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.mon_vpc.id
    tags = {
      Name = "Internet-gateway"
    }
  
}
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.mon_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id 
    }
    tags = {
        Name = "Route- Table-Public"
    }
}

    resource "aws_route_table_association" "public_assoc" {
        subnet_id = aws_subnet.public.id
        route_table_id = aws_route_table.public_rt.id
    }
   

resource "aws_security_group" "security_group" {
    name = "allow_ssh_http"
    description = "Allow SSH and HTTP inbound traffic"
    vpc_id = aws_vpc.mon_vpc.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
}

ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
        egress {
            from_port = 0
            to_port = 0
            protocol = "-1" 
            cidr_blocks = ["0.0.0.0/0"]
        }
    
        tags = {
            Name = "Security-Group"
        }
    }

    # ==========================================
# IAM - Rôles et politiques pour l'authentification RDS
# ==========================================

# Rôle IAM pour l'instance EC2
resource "aws_iam_role" "ec2_rds_role" {
    name = "ec2-rds-iam-auth-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })

    tags = {
        Name = "EC2-RDS-IAM-Role"
    }
}

# Politique IAM pour l'authentification à la base de données
resource "aws_iam_policy" "rds_iam_auth_policy" {
    name        = "rds-iam-authentication-policy"
    description = "Politique pour permettre l'authentification IAM à RDS"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "rds-db:connect"
                ]
                Resource = "arn:aws:rds-db:eu-west-3:*:dbuser:*/*"
            }
        ]
    })
}

# Attacher la politique au rôle
resource "aws_iam_role_policy_attachment" "ec2_rds_policy_attachment" {
    role       = aws_iam_role.ec2_rds_role.name
    policy_arn = aws_iam_policy.rds_iam_auth_policy.arn
}

# Instance profile pour attacher le rôle à l'EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = "ec2-rds-instance-profile"
    role = aws_iam_role.ec2_rds_role.name
}

# ==========================================
# INSTANCE EC2 - Serveur Web
# ==========================================

    resource "aws_instance" "mon_serveur_web" {
        ami = "ami-00ac45f3035ff009e"
        instance_type = "t2.micro"
        subnet_id = aws_subnet.public.id

        vpc_security_group_ids = [aws_security_group.security_group.id]
        associate_public_ip_address = true

        # Attacher le profil IAM pour l'authentification RDS
        iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
 user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y nginx
              echo "<h1>Mon premier serveur avec Terraform!</h1>" > /var/www/html/index.html
              systemctl start nginx
              EOF

        tags = {
            Name = "mon-serveur-web"
        }

    }

    # ==========================================
# CONFIGURATION RDS (BASE DE DONNÉES)
# ==========================================

# DB Subnet Group - Groupe de subnets pour la base de données
resource "aws_db_subnet_group" "rds_subnet_group" {
    name       = "rds-subnet-group"
    subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

    tags = {
        Name = "RDS-Subnet-Group"
    }
}

# Security Group pour RDS - Autoriser seulement le serveur web
resource "aws_security_group" "rds_sg" {
    name        = "rds_security_group"
    description = "Security group pour RDS MySQL"
    vpc_id      = aws_vpc.mon_vpc.id

    ingress {
        from_port       = 3306
        to_port         = 3306
        protocol        = "tcp"
        security_groups = [aws_security_group.security_group.id]
        description     = "Autoriser MySQL depuis le serveur web"
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "RDS-Security-Group"
    }
}

# Instance RDS MySQL avec authentification IAM
resource "aws_db_instance" "mysql_db" {
    identifier     = "ma-base-mysql"
    engine         = "mysql"
    engine_version = "8.0.35"
    instance_class = "db.t3.micro"

    allocated_storage     = 20
    storage_type          = "gp2"
    storage_encrypted     = true

    db_name  = "mabasededonnees"
    username = "admin"
    password = "MotDePasse123!"  # À changer en production avec AWS Secrets Manager

    db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids = [aws_security_group.rds_sg.id]

    # ACTIVATION DE L'AUTHENTIFICATION IAM
    iam_database_authentication_enabled = true

    publicly_accessible = false
    skip_final_snapshot = true

    backup_retention_period = 7
    backup_window          = "03:00-04:00"
    maintenance_window     = "mon:04:00-mon:05:00"

    tags = {
        Name = "MySQL-Database"
    }
}

# ==========================================
# OUTPUTS - Informations utiles
# ==========================================

# Afficher l'adresse IP publique du serveur
output "ip_publique_serveur" {
  value       = aws_instance.mon_serveur_web.public_ip
  description = "Adresse IP publique du serveur web"
}

# Endpoint de la base de données
output "rds_endpoint" {
  value       = aws_db_instance.mysql_db.endpoint
  description = "Endpoint de connexion à la base de données MySQL"
}

# Nom de la base de données
output "rds_database_name" {
  value       = aws_db_instance.mysql_db.db_name
  description = "Nom de la base de données"
}