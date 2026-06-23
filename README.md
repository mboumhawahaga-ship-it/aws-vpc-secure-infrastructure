# Secure Private Bedrock Platform on AWS

## Overview

This project provides a production-ready, security-first infrastructure for deploying containerized GenAI applications on AWS.

The architecture enables private access to Amazon Bedrock from ECS Fargate workloads without exposing containers to the public internet.

All communication with AWS services occurs exclusively through AWS PrivateLink VPC Endpoints, eliminating outbound internet access and significantly reducing the attack surface.

The platform is designed for organizations requiring secure, compliant, and cost-aware GenAI deployments.

---

## Business Problem

Most GenAI workloads deployed in the cloud rely on public internet connectivity, NAT Gateways, and permissive outbound access.

This creates several challenges:

* Increased attack surface.
* Difficult compliance and audit requirements.
* Higher networking costs.
* Limited control over AI workload exposure.
* Risk of uncontrolled AI consumption ("denial of wallet").

This architecture addresses these concerns by implementing a fully private, serverless, and security-hardened GenAI platform.

---

## Key Features

* Fully private ECS Fargate workloads.
* Zero outbound internet connectivity.
* Private Amazon Bedrock access through AWS PrivateLink.
* Multi-AZ deployment architecture.
* AWS WAF protection with OWASP managed rules.
* Rate limiting to protect against denial-of-wallet attacks.
* ECS Exec debugging without SSH or bastion hosts.
* Cost governance through AWS Budgets.
* Bedrock cost attribution using Application Inference Profiles.
* Automatic deployment rollback using ECS circuit breakers.

---

## Architecture

Request flow:

```
Internet
    ↓
AWS WAF
    ↓
Application Load Balancer
    ↓
Private ECS Fargate Tasks
    ↓
AWS PrivateLink VPC Endpoints
    ↓
Amazon Bedrock
```

Containers never access the public internet.

All AWS service communication uses private VPC endpoints.

---

## AWS Services

* Amazon VPC
* Amazon ECS Fargate
* Amazon ECR
* Elastic Load Balancer
* AWS WAF
* Amazon Bedrock
* AWS PrivateLink
* Amazon CloudWatch
* AWS IAM
* AWS Systems Manager
* AWS Budgets
* AWS STS

---

## Security Controls

### Network Security

* Multi-AZ VPC architecture.
* Private application subnets.
* No public IP addresses on workloads.
* No NAT Gateway.
* No outbound internet routes.
* All AWS traffic routed through PrivateLink.

### Identity & Access Management

* Least-privilege IAM roles.
* Separate execution and task roles.
* STS trust restrictions using `aws:SourceArn` and `aws:SourceAccount`.
* Endpoint policies restricted to ECS roles only.

### Threat Protection

* AWS WAF managed rules.
* OWASP Core Rule Set.
* Known Bad Inputs protection.
* Rate limiting (100 requests / 5 minutes / IP).

### Observability

* Container Insights enabled.
* Centralized CloudWatch logging.
* WAF metrics and sampled requests.
* Budget alerts and cost monitoring.

---

## FinOps Capabilities

| Capability | Status |
|---|---|
| Budget Governance | ✓ |
| Bedrock Cost Attribution | ✓ |
| Denial-of-Wallet Protection | ✓ |
| Serverless Compute | ✓ |
| NAT Gateway Elimination | ✓ |
| Autoscaling | Planned |
| Rightsizing | Planned |

---

## Estimated Business Impact

Conservative estimates based on AWS pricing and FinOps practices:

* Elimination of NAT Gateways reduces networking costs by approximately $45–$60/month per environment.
* Private networking significantly reduces exposure to internet-based threats.
* WAF rate limiting helps prevent uncontrolled AI consumption and unexpected LLM spending.
* Bedrock cost attribution improves AI cost visibility across teams and workloads.
* Zero-trust networking simplifies compliance for regulated workloads.

---

## Example Cost Optimization

Traditional architecture:

* NAT Gateway × 2 (Multi-AZ): ~$65/month
* Public outbound access required.

This architecture:

* No NAT Gateway required.
* Private AWS service connectivity only.

Estimated savings:

* Approximately $50/month per environment.

---

## Estimated Monthly Cost

### Development Environment

Estimated monthly cost: **$70–$75/month**

| Component | Cost |
|---|---|
| VPC Interface Endpoints × 5 (× 2 AZ) | ~$36 |
| Application Load Balancer | ~$18 |
| ECS Fargate (256 CPU / 512 MB, 24/7) | ~$9 |
| AWS WAF | ~$6 |
| Amazon Bedrock (low usage) | ~$1–5 |
| CloudWatch Logs | ~$1 |

### Production Environment

Estimated monthly cost: **$120–$200/month**

Primary cost driver: Amazon Bedrock token consumption.

| Component | Cost |
|---|---|
| Amazon Bedrock (moderate usage) | ~$20–100 |
| Application Load Balancer | ~$25 |
| VPC Interface Endpoints × 5 (× 2 AZ) | ~$36 |
| ECS Fargate × 2 (512 CPU / 1 GB) | ~$25 |
| AWS WAF | ~$10 |
| CloudWatch Logs + metrics | ~$5 |

---

## Technical Highlights

* Zero Trust networking principles.
* Fully private GenAI inference architecture.
* Serverless container platform.
* AWS PrivateLink integration.
* Multi-AZ high availability.
* Security-by-design approach.
* Infrastructure as Code with Terraform.
* Cost-aware GenAI architecture.

---

## Getting Started

```bash
# Deploy
cd terraform
terraform init
terraform apply \
  -var="budget_alert_email=your@email.com"
```

After deployment:

```bash
# Validate
curl http://$(terraform output -raw alb_url)

# Debug container without SSH
aws ecs execute-command \
  --cluster <cluster-name> \
  --task <task-id> \
  --container app \
  --interactive \
  --command /bin/sh
```

---

## Future Improvements

* ECS Service Auto Scaling.
* Scale-to-zero capabilities.
* CI/CD pipeline with GitHub Actions and OIDC.
* Bedrock Guardrails integration.
* Private API authentication.
* Knowledge Bases for Amazon Bedrock.
* Multi-account landing zone support.
* Continuous security scanning.

---

## License

MIT
