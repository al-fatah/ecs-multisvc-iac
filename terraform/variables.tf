variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "ecs-multisvc"
}

variable "env" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

# For Phase 2 we set these to placeholder images.
# Phase 3 will replace them with real ECR image URIs.
variable "s3_service_image" {
  type        = string
  description = "Container image for flask-s3-service"
  default     = "public.ecr.aws/docker/library/python:3.11-slim"
}

variable "sqs_service_image" {
  type        = string
  description = "Container image for flask-sqs-service"
  default     = "public.ecr.aws/docker/library/python:3.11-slim"
}

variable "github_org" {
  type        = string
  description = "GitHub org/user name"
}

variable "github_repo_iac" {
  type        = string
  description = "IaC repo name (without org)"
}

variable "github_repo_apps" {
  type        = string
  description = "Apps repo name (without org)"
}
