# Secure AI Platform on AWS — ECS Fargate + Bedrock Reference Architecture

**A production-grade network and security foundation for running GenAI workloads on AWS, with zero internet egress from application containers.**

---

## Business Context

Organizations adopting GenAI internally face a security problem that standard AWS deployments don't address by default: LLM inference traffic crosses the public internet unless explicitly contained.

A container calling Bedrock without network controls sends requests over HTTPS to `bedrock-runtime.region.amazonaws.com` — which resolves to a public endpoint. For regulated industries (finance, healthcare, legal) or organizations processing internal data, this is either a compliance gap or a hard blocker for GenAI adoption.

Beyond the data path, GenAI workloads introduce a cost exposure that standard web architectures don't have: every request hitting the inference endpoint generates token costs. A misconfigured endpoint or an abusive client doesn't just cause downtime — it generates an unbounded AWS bill.

This project builds the network and security foundation that makes Bedrock workloads safe to run internally: private egress only, least-privilege IAM, WAF-gated ingress, and cost observability per workload.

---

## Use Cases

### Enterprise — Regulated Data Processing

An internal tool (contract analysis, HR document summarization, audit log review) processes sensitive documents via Bedrock. Security policy requires that document content never transits the public internet. With this architecture, the Fargate container calls `bedrock-runtime` exclusively through a VPC Interface Endpoint — traffic stays on the AWS backbone from container to model. Legal and InfoSec can sign off on the data path.

### Data Team — Controlled LLM Access

A data science team wants to experiment with Bedrock models without opening internet access from their processing containers. The ECR pull-through cache and PrivateLink endpoints mean containers can pull images, call Bedrock, write logs, and connect to ECS Exec — all without a NAT Gateway or any public IP. The team gets API access; the network stays closed.

### Product Team — Internal AI Feature with Cost Guardrails

A product team ships an internal feature backed by Bedrock. Without rate limiting, a bug in the client or a scripted user could trigger thousands of inference calls in minutes. The WAF rate limit (100 requests per IP per 5 minutes) caps the blast radius of any single client. The Bedrock Inference Profile tags every call with the project and environment, making the cost visible in Cost Explorer before it becomes a surprise on the bill.

---

## Architecture Overview

```
Internet
    │
    ▼
  [WAF] — OWASP CRS + Known Bad Inputs + rate limit 100 req/5min
    │
    ▼
[ALB] — public subnets AZ-a + AZ-b (10.0.1.0/24, 10.0.4.0/24)
    │
    ▼
[Fargate tasks] — private subnets AZ-a + AZ-b (10.0.2.0/24, 10.0.3.0/24)
    │                         NO internet route, NO NAT Gateway
    ▼
[VPC Interface Endpoints] — PrivateLink only
    ├── bedrock-runtime  (LLM inference)
    ├── ecr.api + ecr.dkr  (image pull via pull-through cache)
    ├── logs  (CloudWatch)
    └── ssmmessages  (ECS Exec / debug)

[VPC Gateway Endpoint] — S3 (ECR image layers, free)
```

Public subnets contain only the ALB. Fargate tasks run in private subnets with no route to the internet — the private route table has no default route. All AWS API calls go through PrivateLink.

---

## Security Design

### Network Isolation

Private subnets have no internet gateway route and no NAT Gateway. Outbound traffic from Fargate is limited to port 443 toward the VPC endpoints security group — nothing else. This is enforced at the security group level, not just by the absence of a route.

Three security groups with explicit `egress = []` (removes AWS's default allow-all egress rule):

| Security group | Ingress | Egress |
|---|---|---|
| ALB | HTTP/80 from `0.0.0.0/0` | HTTP/80 to Fargate SG |
| Fargate | HTTP/80 from ALB SG | HTTPS/443 to Endpoints SG |
| Endpoints | HTTPS/443 from Fargate SG | none |

Each rule references the other security group's ID, not a CIDR. This means rules stay valid if subnets are re-CIDRed and cannot be bypassed by adding a new subnet in the same CIDR range.

### IAM — Execution Role vs Task Role

ECS uses two separate IAM roles with distinct purposes:

**Execution role** (`ecs_execution_role`): used by the ECS control plane to start the task. Permissions: pull image from ECR private registry, write to CloudWatch Logs, create pull-through cache repository on first pull. The application inside the container never uses this role.

**Task role** (`ecs_task_role`): used by the application code inside the container. Current permissions: SSM messages for ECS Exec. Bedrock `InvokeModel` is added here when wiring the inference profile — scoped to the profile ARN, not `bedrock:*`.

Both roles include `aws:SourceArn` and `aws:SourceAccount` conditions on the `sts:AssumeRole` trust policy. Without these conditions, any ECS task in the account — not just tasks from this cluster — could assume these roles. This is a confused deputy mitigation specific to service-linked assume-role.

### VPC Endpoint Policies

Each Interface Endpoint has an explicit resource policy allowing only the execution role and the task role. AWS's default endpoint behavior is `Allow * from *` — any identity in the VPC, including identities in peered VPCs, can use an endpoint without a policy. Scoping endpoints to the two project roles ensures that a compromised resource elsewhere in the VPC cannot use these endpoints to reach Bedrock or ECR.

### WAF

Three rules attached to the ALB, evaluated in order:

1. **AWS Managed Core Rule Set** (priority 10) — OWASP Top 10: SQLi, XSS, path traversal, oversized requests
2. **AWS Managed Known Bad Inputs** (priority 20) — Log4Shell (CVE-2021-44228), SSRF, Spring4Shell, Java deserialization exploits
3. **Rate limit per IP** (priority 30) — blocks any IP exceeding 100 requests in a 5-minute window

The rate limit serves two purposes: abuse prevention and cost protection. Bedrock charges per token. An unthrottled client hitting an inference endpoint generates unbounded costs — "denial of wallet." 100 req/5min (~1 req/3s per IP) is appropriate for an internal tool; adjust for higher-throughput use cases.

### Bedrock Cost Observability

The Inference Profile (`aws_bedrock_inference_profile`) is a taggable alias to the foundation model. Without it, Bedrock costs appear in Cost Explorer as a single undifferentiated line. With it, each inference call carries the `CostCenter` tag, enabling per-project cost breakdown in Cost Explorer. This requires activating the tag as a cost allocation tag in Billing settings — it does not activate automatically.

---

## What I Built

**`network.tf`** — VPC (`10.0.0.0/16`), 2 public subnets (ALB, multi-AZ requirement), 2 private subnets (Fargate, multi-AZ). Private route table has no default route — isolation is enforced at the routing layer, not just security groups.

**`security_groups.tf`** — 3 security groups with `egress = []` and security-group-to-security-group rules. Uses `aws_vpc_security_group_egress_rule` (separate resources) rather than inline `egress` blocks, which conflict with `egress = []`.

**`endpoints.tf`** — 5 Interface endpoints (bedrock-runtime, ecr.api, ecr.dkr, logs, ssmmessages) + 1 Gateway endpoint (S3). All Interface endpoints have scoped resource policies. Private DNS enabled — containers resolve `bedrock-runtime.eu-west-3.amazonaws.com` to the private endpoint IP automatically, no code changes required in the application.

**`ecr.tf`** — ECR pull-through cache rule from `public.ecr.aws`. Solves the `CannotPullContainerError` that occurs when Fargate tries to pull a public image from a VPC without NAT. The first pull fetches from ECR Public (requires the execution role's `ecr:BatchImportUpstreamImage` permission), subsequent pulls serve from the private cache.

**`iam.tf`** — Execution role with `AmazonECSTaskExecutionRolePolicy` + pull-through cache permissions. Task role with SSM exec permissions (4 `ssmmessages:*` actions — all required, none support resource-level restrictions). Both with confused-deputy-safe trust policies using `aws:SourceArn` + `aws:SourceAccount`.

**`ecs.tf`** — ECS cluster with Container Insights. Task definition: `network_mode = awsvpc` (required for Fargate — each task gets its own ENI and private IP), `assign_public_ip = false`. Service with deployment circuit breaker and automatic rollback — if a new task definition fails health checks, ECS reverts to the previous revision without manual intervention.

**`alb.tf`** — Internet-facing ALB across 2 public AZs. Target group type `ip` (required for Fargate — tasks register by IP, not instance). Health check on `/` every 30s. ALB deregisters unhealthy tasks from rotation; ECS circuit breaker restarts them.

**`waf.tf`** — WAF v2 Regional Web ACL with 3 rules, associated to the ALB ARN. Without the `aws_wafv2_web_acl_association` resource, the ACL exists but intercepts nothing.

**`monitoring.tf`** — CloudWatch log group (30-day retention). AWS Budget alert at 80% of monthly threshold (alert only, not a hard stop). Bedrock Application Inference Profile pointing to `anthropic.claude-3-haiku-20240307-v1:0` with `CostCenter` cost allocation tag.

---

## Design Decisions

### Why ECS Fargate, not Lambda

Lambda is the default choice for a stateless inference wrapper. Two constraints ruled it out here. First, Lambda cold starts in a VPC add 200–500ms to the first request after idle — noticeable for synchronous user-facing calls. Second, Fargate's `awsvpc` networking integrates more naturally with the endpoint-only egress model: each task has its own ENI and resolves VPC endpoint private DNS without additional configuration. For streaming inference responses or sessions longer than 15 minutes, Fargate's container model is also a better fit.

### Why no NAT Gateway

NAT Gateway costs approximately $32/month in fixed charges plus $0.045/GB data processed. For an architecture where all egress goes to AWS services (ECR, Bedrock, CloudWatch, SSM), PrivateLink is both cheaper at low data volumes and categorically more restrictive — a NAT Gateway allows egress to any internet destination if a security group permits it; a VPC endpoint cannot reach anything outside AWS.

The constraint: any AWS service without a PrivateLink endpoint is unreachable from the private subnets. This is intentional — it forces explicit opt-in for each service dependency rather than inheriting unrestricted internet access by default.

### Why Bedrock over self-hosted models

Running open-source models (Llama, Mistral) on GPU instances adds operational surface: instance management, model serving infrastructure (vLLM, TorchServe), GPU availability in eu-west-3, patching. Bedrock removes this layer entirely and shifts model updates to AWS. The trade-off is less control over model versioning — acceptable for internal tooling, not for use cases requiring pinned, deterministic model behavior.

### Why eu-west-3 (Paris)

GDPR: data processed in Paris stays within the EU without requiring Standard Contractual Clauses for US data transfers. For workloads processing personal data, this removes a legal review step that would otherwise block deployment.

---

## Deployment

### Prerequisites

- AWS account with Bedrock model access enabled for `anthropic.claude-3-haiku-20240307-v1:0` in eu-west-3 (request via AWS console → Bedrock → Model access)
- Terraform >= 1.5
- AWS credentials with permissions for VPC, ECS, ECR, IAM, WAFv2, Bedrock, Budgets

### Deploy

```bash
terraform init

terraform plan -var="budget_alert_email=you@company.com"

terraform apply -var="budget_alert_email=you@company.com"
```

Terraform provisions resources in dependency order. The ECR pull-through cache rule must exist before the ECS service pulls images. The ALB listener must exist before the ECS service registers targets (`depends_on` in `ecs.tf` enforces this — without it, the first `apply` fails on target group registration).

### Verify

```bash
# ALB DNS name
terraform output alb_dns_name

# ECS task status
aws ecs list-tasks --cluster <project>-cluster

# Connect to container — no SSH, no bastion
aws ecs execute-command \
  --cluster <project>-cluster \
  --task <task-id> \
  --container app \
  --interactive \
  --command "/bin/sh"
```

### Wire Bedrock to the application

Add to `iam.tf`, scoped to the inference profile ARN:

```hcl
resource "aws_iam_role_policy" "ecs_task_bedrock" {
  name = "bedrock-invoke"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "bedrock:InvokeModel"
      Resource = aws_bedrock_inference_profile.app.arn
    }]
  })
}
```

The container calls `bedrock-runtime` using the inference profile ARN. The VPC endpoint resolves the hostname to the private IP — no application code change required.

---

## Risks and Trade-offs

**No TLS at the ALB.** The listener is HTTP/80. A production deployment handling sensitive data requires HTTPS with an ACM certificate and HTTP → HTTPS redirect. Scoped out here to keep the focus on network isolation and IAM design.

**ECS Exec is enabled in production mode.** `enable_execute_command = true` allows any IAM identity with `ecs:ExecuteCommand` to open a shell in the container. Useful for debugging, but in a production environment this should be restricted by IAM condition (`aws:RequestedRegion`, specific cluster ARN) or disabled entirely and re-enabled only during incident response.

**Rate limit at 100 req/5min is coarse.** WAF rate limiting is per-IP, not per-user. A legitimate user behind a corporate NAT shares the limit with everyone on the same IP. For a multi-user product, application-layer throttling per API key is more appropriate — WAF is the last line, not the primary control.

**Endpoint costs are fixed, not traffic-based.** Each Interface Endpoint costs ~$7.20/month (2 AZs × $0.01/hour × 720h). Five endpoints = ~$36/month regardless of traffic. This is favorable compared to a NAT Gateway at low volumes but flips for high-throughput workloads where NAT data transfer costs less than the fixed endpoint baseline.

**Bedrock model access is per-account and per-region.** Access to `anthropic.claude-3-haiku-20240307-v1:0` in eu-west-3 must be requested and approved before Terraform can create the Inference Profile. The `apply` will fail if access is not granted.

---

## Why This Matters

The default path for a Bedrock proof of concept is a Lambda with an API Gateway, open internet egress, and no WAF. That works for a demo. It does not work when security, compliance, or cost controls enter the conversation — which they always do before a GenAI feature reaches production.

This architecture addresses those concerns at the infrastructure level rather than the policy level: traffic cannot leave the VPC, IAM roles cannot be assumed outside their intended scope, inference costs are tagged and rate-limited, and deployments roll back automatically on failure. Each control is implemented in Terraform and reviewable as code.

The foundation is also extensible. Adding VPC Flow Logs, CloudTrail, GuardDuty, or Bedrock Guardrails slots in without restructuring — the network isolation and IAM boundaries are already in place.

Relevant for: Cloud Platform Engineer, DevSecOps Engineer, AI Platform Engineer, Cloud Security Engineer roles.
