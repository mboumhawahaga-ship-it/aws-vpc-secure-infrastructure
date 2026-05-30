# ==========================================
# VPC ENDPOINTS — Interface (PrivateLink)
# Permettent aux tâches Fargate d'atteindre
# les services AWS sans passer par internet.
# ==========================================

locals {
  interface_endpoints = {
    bedrock_runtime = "com.amazonaws.${var.aws_region}.bedrock-runtime"
    ecr_api         = "com.amazonaws.${var.aws_region}.ecr.api"
    ecr_dkr         = "com.amazonaws.${var.aws_region}.ecr.dkr"
    logs            = "com.amazonaws.${var.aws_region}.logs"
    ssmmessages     = "com.amazonaws.${var.aws_region}.ssmmessages"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-endpoint-${each.key}" }
}

# ==========================================
# VPC ENDPOINT — Gateway S3 (gratuit)
# Utilisé pour télécharger les couches
# d'images Docker depuis ECR (stockées sur S3).
# Sans lui, le pull d'image échoue même avec
# les endpoints ECR correctement configurés.
# ==========================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.project_name}-endpoint-s3" }
}
