# ==========================================
# WAF — WEB ACL
#
# Filtre le trafic AVANT qu'il atteigne l'ALB.
# scope = "REGIONAL" : pour un ALB (par opposition
# à "CLOUDFRONT" pour une distribution CloudFront).
#
# default_action = allow : tout ce qui ne matche
# pas une règle de blocage passe. Les règles
# ci-dessous bloquent ; le reste est autorisé.
# ==========================================

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # ----------------------------------------
  # Règle 1 — AWS Managed : Core Rule Set
  # Protège contre les attaques OWASP Top 10 :
  # injections SQL, XSS, traversée de chemins,
  # taille anormale des requêtes, etc.
  # priority = 10 : évaluée en premier.
  # ----------------------------------------
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  # ----------------------------------------
  # Règle 2 — AWS Managed : Known Bad Inputs
  # Bloque les patterns d'exploitation connus :
  # Log4Shell (CVE-2021-44228), SSRF, Spring4Shell,
  # JavaDeserializationExploits, etc.
  # priority = 20 : évaluée après la règle 10.
  # ----------------------------------------
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-known-bad"
      sampled_requests_enabled   = true
    }
  }

  # ----------------------------------------
  # Règle 3 — Rate-based rule
  # Bloque une IP qui dépasse 100 requêtes
  # sur une fenêtre glissante de 5 minutes.
  #
  # Double rôle :
  #   Sécurité : brute force, scraping, DDoS L7.
  #   Coût : chaque requête peut déclencher un
  #   appel Bedrock (tokens facturés). Un bot qui
  #   martèle l'endpoint = "denial of wallet".
  #   Cette règle coupe le robinet avant que la
  #   facture explose.
  #
  # 100 req/5min = ~1 req/3s par IP.
  # Ajuster si l'app légitime a besoin de plus.
  # ----------------------------------------
  rule {
    name     = "RateLimitPerIP"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }
}

# ==========================================
# ASSOCIATION WAF <-> ALB
#
# Sans cette ressource, la Web ACL existe mais
# ne filtre rien. L'association branche le WAF
# sur l'ARN de l'ALB : tout le trafic entrant
# passe d'abord par le WAF avant d'atteindre
# le listener HTTP.
# ==========================================

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
