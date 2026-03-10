# ECS Multi-Service Infrastructure (Terraform + OIDC)

Production-style Infrastructure as Code (IaC) project deploying two
containerized microservices on Amazon ECS Fargate, fronted by an
Application Load Balancer (ALB).

Infrastructure is fully managed using Terraform and deployed securely
via GitHub Actions with OIDC --- no static AWS credentials.

------------------------------------------------------------------------

# Architecture Overview

<img width="2815" height="1075" alt="mermaid-diagram" src="https://github.com/user-attachments/assets/ba410e11-dc90-4191-9b44-a7672af80c09" />

Supporting Services: 
- Amazon ECR (2 repositories)
- Amazon CloudWatch Logs
- IAM (Execution Role + Task Role)
- Custom VPC (public subnets + Internet Gateway)

------------------------------------------------------------------------

# What This Repository Provisions

## Networking

-   Custom VPC
-   2 Public Subnets (Multi-AZ)
-   Internet Gateway
-   Route Tables
-   Security Groups

## Compute

-   ECS Cluster (Fargate)
-   2 ECS Services:
    -   Flask → S3 file uploader
    -   Flask → SQS message producer

## Load Balancing

-   Application Load Balancer
-   Path-based routing:
    -   /s3/\*
    -   /sqs/\*
-   Target Groups (per service)

## Storage & Messaging

-   S3 Bucket (file uploads)
-   SQS Queue (message ingestion)

## Container Registry

-   2 Amazon ECR repositories (one per service)

## Observability

-   CloudWatch Log Groups (per service)
-   Structured container logging

## Security & IAM

-   ECS Task Execution Role
-   ECS Task Role (least privilege)
-   GitHub Actions OIDC IAM Role (Terraform + deployment)

------------------------------------------------------------------------

# CI/CD Workflows

## Continuous Integration (Pull Requests)

Triggered on PRs to main: - terraform fmt -check - terraform validate

## Continuous Deployment (Manual Trigger)

GitHub → Actions → Terraform Deploy

Workflow: - Uses OIDC to assume AWS IAM role - Runs terraform init -
Runs terraform apply - No AWS access keys stored in GitHub

------------------------------------------------------------------------

# Local Deployment

From the terraform/ directory:

terraform init terraform plan terraform apply

Destroy infrastructure:

terraform destroy

Note: If destroy fails, empty the S3 bucket and remove ECR images first.

------------------------------------------------------------------------

# Security Design

-   OIDC authentication (no static credentials)
-   Least-privilege IAM policies
    -   S3 service → s3:PutObject only
    -   SQS service → sqs:SendMessage only
-   Isolated VPC networking
-   ALB path-based exposure control

------------------------------------------------------------------------

# Cost Considerations

Primary cost drivers: - ECS Fargate compute - ALB hourly charges -
CloudWatch logs

Designed for demo/portfolio scale.

------------------------------------------------------------------------

# Project Status

-   Phase 1: Architecture design ✅
-   Phase 2: Infrastructure provisioning ✅
-   Phase 3: Microservices deployment ✅
-   Phase 4: CI/CD with GitHub Actions + OIDC ✅
-   Phase 5: Documentation complete ✅

------------------------------------------------------------------------

# DevOps Concepts Demonstrated

-   Infrastructure as Code (Terraform)
-   Container orchestration (ECS Fargate)
-   Path-based routing
-   Secure CI/CD using OIDC
-   IAM least privilege design
-   Multi-service architecture

------------------------------------------------------------------------
