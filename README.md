# 🔒 AWS VPC Secure Infrastructure

Infrastructure réseau AWS sécurisée déployée avec Terraform, démontrant l'isolation réseau entre subnet public et subnet privé, le principe du moindre privilège IAM, et les bonnes pratiques de sécurité cloud.

---

## Architecture

```
                        INTERNET
                            │
                     ┌──────▼──────┐
                     │     IGW     │
                     └──────┬──────┘
                            │
          ┌─────────────────▼──────────────────┐
          │         VPC  10.0.0.0/16            │
          │                                     │
          │  ┌──────────────────────────────┐   │
          │  │   Subnet Public 10.0.1.0/24  │   │
          │  │                              │   │
          │  │   ┌─────────────────────┐    │   │
          │  │   │   Bastion Host      │    │   │
          │  │   │   (SSH depuis       │    │   │
          │  │   │    votre IP only)   │    │   │
          │  │   └──────────┬──────────┘    │   │
          │  └──────────────┼───────────────┘   │
          │                 │ SSH only           │
          │  ┌──────────────▼───────────────┐   │
          │  │  Subnet Privé 1 10.0.2.0/24  │   │
          │  │                              │   │
          │  │   ┌─────────────────────┐    │   │
          │  │   │   EC2 App (nginx)   │    │   │
          │  │   │   Pas d'IP publique │    │   │
          │  │   └──────────┬──────────┘    │   │
          │  └──────────────┼───────────────┘   │
          │                 │ MySQL 3306 only    │
          │  ┌──────────────▼───────────────┐   │
          │  │  Subnet Privé 2 10.0.3.0/24  │   │
          │  │                              │   │
          │  │   ┌─────────────────────┐    │   │
          │  │   │   RDS MySQL         │    │   │
          │  │   │   Chiffré, IAM auth │    │   │
          │  │   │   Jamais public     │    │   │
          │  │   └─────────────────────┘    │   │
          │  └──────────────────────────────┘   │
          └─────────────────────────────────────┘
```

---

## Principes de sécurité appliqués

**Isolation réseau**
- Le subnet privé n'a aucune route vers internet
- RDS accessible uniquement depuis l'instance EC2 app
- L'instance app accessible uniquement via le bastion

**Least Privilege**
- SSH restreint à une seule IP (la vôtre)
- Security group RDS : zéro egress, ingress MySQL depuis EC2 uniquement
- IAM role EC2 : uniquement `rds-db:connect` sur cette instance RDS

**Chiffrement**
- EBS chiffré sur les deux instances EC2
- Storage RDS chiffré (gp3)
- IMDSv2 obligatoire sur les instances (protection SSRF)

**Pas de credentials hardcodés**
- Mot de passe RDS généré automatiquement par Terraform (`random_password`)
- Jamais de secrets dans le code source

---

## Structure du projet

```
├── main.tf               # Providers (aws, random) + tags globaux
├── variables.tf          # Toutes les variables paramétrables
├── vpc.tf                # VPC, subnets, IGW, route tables
├── security_groups.tf    # SG bastion / app / rds
├── ec2.tf                # Bastion (public) + App (privée)
├── iam.tf                # Rôle IAM least-privilege pour EC2
├── rds.tf                # RDS MySQL + mot de passe auto-généré
└── outputs.tf            # IPs, endpoint RDS, commandes SSH
```

---

## Stack technique

- **IaC** : Terraform ~> 5.0
- **Cloud** : AWS (eu-west-3 — Paris)
- **Compute** : EC2 t3.micro, Amazon Linux 2023
- **Database** : RDS MySQL 8.0, db.t3.micro
- **Sécurité** : IAM, Security Groups, EBS encryption, IMDSv2

---

## Déploiement

**Prérequis** : AWS CLI configuré, Terraform installé, une key pair EC2 existante.

**1. Configurer vos valeurs dans `variables.tf`**
```hcl
variable "allowed_ssh_cidr" {
  default = "VOTRE_IP/32"       # curl ifconfig.me
}
variable "key_pair_name" {
  default = "NOM_DE_VOTRE_KEY"
}
```

**2. Déployer**
```bash
terraform init
terraform plan
terraform apply
```

**3. Se connecter**
```bash
# Accès au bastion
ssh -i <votre-cle.pem> ec2-user@<bastion_public_ip>

# Accès à l'instance privée via le bastion (SSH jump)
ssh -i <votre-cle.pem> -J ec2-user@<bastion_ip> ec2-user@<app_private_ip>
```

**4. Détruire après démo**
```bash
terraform destroy
```

> ⚠️ Penser à détruire l'infrastructure après les tests pour éviter les frais RDS (~$15/mois).
