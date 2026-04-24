# ==========================================
# BASTION HOST (subnet public)
# Seul point d'entrée SSH - pas d'app ici
# IP publique nécessaire pour l'accès SSH admin
# ==========================================

resource "aws_instance" "bastion" {
  ami                         = var.ec2_ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name
  monitoring                  = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 obligatoire - bloque les attaques SSRF
  }

  tags = { Name = "${var.project_name}-bastion" }
}

# ==========================================
# INSTANCE APPLICATIVE (subnet privé)
# Aucune IP publique - accessible uniquement via bastion
# Contient l'application web (nginx)
# ==========================================

resource "aws_instance" "app" {
  ami                         = var.ec2_ami
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.private_1.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false
  key_name                    = var.key_pair_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_app_profile.name
  monitoring                  = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true # EBS chiffré
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 obligatoire
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>${var.project_name} - Instance privée opérationnelle</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = { Name = "${var.project_name}-app" }
}
