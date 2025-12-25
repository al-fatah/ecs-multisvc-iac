# ECS Multi-Service Infrastructure (IaC)

This repository provisions the **AWS infrastructure** for a portfolio project deploying **two containerized microservices** on **ECS Fargate**, fronted by an **Application Load Balancer (ALB)**.

The infrastructure is managed using **Terraform** and deployed via **GitHub Actions with OIDC** (no static AWS credentials).

---

## Architecture Overview

Internet  
→ Application Load Balancer (ALB)  
→ `/s3/*` → ECS Service (Flask S3 Service) → S3 Bucket  
→ `/sqs/*` → ECS Service (Flask SQS Service) → SQS Queue  

Supporting services:
- Amazon ECR (2 repositories)
- Amazon CloudWatch Logs
- IAM (Execution Role + Task Role)
- Custom VPC with public subnets + Internet Gateway

---

## What This Repo Provisions

### Networking
- Custom VPC
- 2 public subnets (multi-AZ)
- Internet Gateway
- Route tables

### Compute
- ECS Cluster (Fargate)
- 2 ECS Services:
  - Flask → S3 uploader
  - Flask → SQS message producer

### Load Balancing
- Application Load Balancer
- Path-based routing:
  - `/s3/*`
  - `/sqs/*`

### Storage & Messaging
- S3 bucket (file uploads)
- SQS queue (message ingestion)

### Container Registry
- 2 ECR repositories (one per service)

### Observability
- CloudWatch Log Groups (per service)

### Security & IAM
- ECS Task Execution Role
- ECS Task Role (least privilege)
- GitHub Actions OIDC IAM Role (Terraform + App deploy)

---

## Repository Structure

ecs-multisvc-iac/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── github-oidc.tf
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml
│       └── terraform-deploy.yml
└── README.md

---

## Terraform Workflows

### CI (Pull Requests)
Triggered on PRs to `main`:
- `terraform fmt -check`
- `terraform validate`

### CD (Manual)
Triggered via **GitHub Actions → “Terraform Deploy”**:
- Uses **OIDC** to assume an AWS IAM role
- Runs `terraform apply`
- No AWS access keys stored in GitHub

---

## How to Deploy

From the terraform directory:

terraform init  
terraform plan  
terraform apply  

Or via GitHub Actions:
1. Open Actions
2. Select Terraform Deploy
3. Run workflow

---

## Security Design

- GitHub Actions authenticates via OIDC
- No static AWS credentials
- Task roles follow least-privilege
  - S3: PutObject only
  - SQS: SendMessage only

---

## Cost & Cleanup

terraform destroy

(Optional: remove ECR images and empty S3 bucket first)

---

## Status

- Phase 2: Infrastructure provisioning ✅
- Phase 4: CI/CD with GitHub Actions + OIDC ✅
- Phase 5: Portfolio documentation ✅

---

### One-line summary

Terraform-managed AWS infrastructure deploying two ECS Fargate services behind an ALB, secured with GitHub Actions OIDC and least-privilege IAM.
