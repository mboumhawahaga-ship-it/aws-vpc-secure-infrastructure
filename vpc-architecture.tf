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

resource "aws_subnet" "private" {
    vpc_id = aws_vpc.mon_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-3b"
    tags = {
        Name = "Subnet-Private" }

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

    resource "aws_instance" "mon_serveur_web" {
        ami = "ami-00ac45f3035ff009e"
        instance_type = "t2.micro"
        subnet_id = aws_subnet.public.id

        vpc_security_group_ids = [aws_security_group.security_group.id]
        associate_public_ip_address = true
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

    # Afficher l'adresse IP publique du serveur
output "ip_publique_serveur" {
  value       = aws_instance.mon_serveur_web.public_ip
  description = "Adresse IP publique du serveur web"
}
