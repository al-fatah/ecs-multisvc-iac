output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "sqs_queue_url" {
  value = aws_sqs_queue.messages.url
}

output "ecr_s3_service_repo_url" {
  value = aws_ecr_repository.s3_service.repository_url
}

output "ecr_sqs_service_repo_url" {
  value = aws_ecr_repository.sqs_service.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_s3_name" {
  value = aws_ecs_service.s3.name
}

output "ecs_service_sqs_name" {
  value = aws_ecs_service.sqs.name
}

output "github_actions_role_arn" {
  value = aws_iam_role.gha_iac.arn
}
