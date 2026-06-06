# AWS Secure AI Workload — Private & Cost-Controlled LLM Inference Platform

---

## Business Context

AI-powered applications introduce two critical enterprise risks:

- Uncontrolled LLM cost explosion due to unpredictable token consumption
- Data exposure risk when model traffic routes through public internet infrastructure

In traditional cloud setups, AI inference workloads are often deployed without proper cost governance or network isolation, leading to:

- unpredictable monthly bills
- limited cost attribution per workload
- expanded attack surface via public egress (NAT gateways)

---

## 🎯 Business Objective

This project implements a secure and cost-controlled AI inference architecture on AWS, designed to:

- Eliminate public internet exposure for AI inference traffic
- Prevent uncontrolled LLM spending ("denial of wallet" protection)
- Enable per-workload cost attribution using tagged Bedrock inference profiles
- Reduce operational overhead through serverless compute

---

## 💡 Key Business Outcomes

### 1. Secure AI Traffic Architecture

All inference requests remain inside the AWS network backbone using PrivateLink.

→ Eliminates:
- public internet routing
- NAT gateway exposure
- external data egress risks

### 2. Predictable AI Cost Governance

LLM usage is protected against abusive or automated traffic.

→ WAF rate limiting prevents:
- token-based cost spikes
- bot-driven API abuse
- unexpected billing surges

### 3. Per-Workload Cost Attribution

Bedrock inference profiles are tagged per workload.

→ Enables:
- cost visibility per application
- FinOps chargeback per AI feature
- separation of experimentation vs production usage

### 4. Reduced Operational Overhead

Serverless compute (ECS Fargate) removes:
- instance management
- OS patching
- idle infrastructure costs

---

## 📊 FinOps & Security KPIs

| KPI | Description | Business Target |
|-----|-------------|-----------------|
| **AI Cost per Workload** | Bedrock spend per inference profile | Fully attributable |
| **Token Abuse Prevention Rate** | Blocked requests via WAF | High (protects budget) |
| **Network Egress Reduction** | % traffic staying within AWS backbone | 100% |
| **Idle Compute Cost** | Cost during no traffic | ~0 (Fargate) |
| **Security Attack Surface** | Public entry points exposed | Minimal (ALB only) |

> **Estimated impact:** Eliminates 100% of public internet egress for AI inference traffic using PrivateLink-based architecture. Prevents uncontrolled LLM cost spikes (denial-of-wallet risk) through WAF rate limiting and request throttling.

---

## 🏗️ Architecture Overview

The system is designed as a zero-egress secure AI inference pipeline:

```
Client
  → WAF           (security + cost protection)
  → ALB           (ingress control)
  → ECS Fargate   (private compute)
  → Bedrock       (AI inference via PrivateLink — no internet routing)
```

- **WAF** protects against abusive traffic and cost spikes
- **ALB** handles public ingress only
- **ECS Fargate** executes inference workloads privately
- **Bedrock** accessed via PrivateLink (no internet routing)
- **CloudWatch + tagging** enable cost observability

---

## 🔐 Security Design Principles

### 1. Zero Trust Network Design

No inbound SSH, no public compute, no direct instance access.

### 2. No Internet Egress from Compute Layer

All AWS service communication stays inside VPC endpoints.

### 3. Least Privilege IAM

Separate execution and task roles to minimize blast radius.

### 4. Cost as a Security Vector

WAF rate limiting protects against "denial-of-wallet" AI attacks.

---

## 💰 FinOps Controls

| Control | Purpose |
|---------|---------|
| WAF rate-based rules | Prevent runaway token consumption |
| Bedrock inference profiles | Cost attribution per workload |
| AWS Budgets | Monthly spend protection |
| Fargate pay-per-use | Eliminate idle compute cost |
| VPC endpoints | Remove NAT/data transfer costs |

---

## 🧠 Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| Fargate over EC2 | Removes operational overhead |
| PrivateLink over NAT Gateway | Eliminates internet exposure |
| WAF rate limiting | Prevents cost abuse (FinOps + security) |
| Inference profiles | Enables AI cost observability |
| ECS Exec over Bastion | Secure debugging without SSH |

---

## 📌 Why this project matters

This architecture demonstrates how to:

- design secure AI workloads on AWS
- control LLM cost explosion risks
- enforce zero-trust cloud networking
- implement FinOps at workload level (not account level)
- build production-ready serverless AI systems
