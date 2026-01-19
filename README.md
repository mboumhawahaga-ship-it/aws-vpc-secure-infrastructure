# Secure 3-Tier Infrastructure as Code (AWS & Terraform)

## 🎯 Project Overview

This project demonstrates a production-ready cloud infrastructure on AWS, fully automated with Terraform. It follows security best practices (Least Privilege, Network Isolation) and high-availability principles.

## 🏗️ Architecture Features
- **Network Isolation:** 

A custom VPC with Public and Private Subnets across multiple Availability Zones (AZs).
- **Secure Database:** RDS MySQL instance located in private subnets, accessible only from the Web Server.

- **IAM Authentication:** Using IAM Roles for RDS connection instead of hardcoded passwords (Zero-Trust approach).
- **Web Layer:** EC2 instance running Nginx with automated deployment via User Data.

## 🛠️ Tech Stack

- **Provider:** AWS
- **IaC:** Terraform
- **Database:** RDS (MySQL)
- **Security:** IAM Roles, Security Groups, Subnet Isolation

## 🚀 How to deploy

1. Initialize Terraform: `terraform init`
2. Preview changes: `terraform plan`
3. Deploy: `terraform apply`

## ⚡ Gain de Productivité Estimé

Le déploiement manuel d'une infrastructure sécurisée peut prendre des jours. Avec ce module Terraform :

* **Temps de déploiement :** ~5 minutes (au lieu de 4-6 heures manuellement).
* **Fiabilité :** 100% (élimination des erreurs de configuration humaine).
* **Conformité :** Architecture pré-validée pour les standards de sécurité.
