############################################
# main.tf — Phase 2 (VPC + ALB + ECS + ECR + S3 + SQS)
############################################

provider "aws" {
  region = var.aws_region
}

locals {
  name = "${var.project_name}-${var.env}"
}

# -------------------------
# Networking (NEW VPC + Public Subnets + IGW)
# Fixes: "VPC has no internet gateway"
# -------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

locals {
  public_subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# -------------------------
# S3 + SQS
# -------------------------
resource "aws_s3_bucket" "uploads" {
  bucket = "${local.name}-uploads"
}

resource "aws_sqs_queue" "messages" {
  name = "${local.name}-messages"
}

# -------------------------
# ECR (2 repos)
# -------------------------
resource "aws_ecr_repository" "s3_service" {
  name                 = "${local.name}-flask-s3-service"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "sqs_service" {
  name                 = "${local.name}-flask-sqs-service"
  image_tag_mutability = "MUTABLE"
}

# -------------------------
# CloudWatch logs
# -------------------------
resource "aws_cloudwatch_log_group" "s3" {
  name              = "/ecs/${local.name}/flask-s3-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "sqs" {
  name              = "/ecs/${local.name}/flask-sqs-service"
  retention_in_days = 7
}

# -------------------------
# ECS Cluster
# -------------------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
}

# -------------------------
# IAM: Execution + Task roles
# -------------------------
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name               = "${local.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "task_role_policy" {
  # S3: allow uploads to this bucket
  statement {
    sid    = "AllowS3PutObject"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      aws_s3_bucket.uploads.arn,
      "${aws_s3_bucket.uploads.arn}/*"
    ]
  }

  # SQS: allow send message to this queue
  statement {
    sid    = "AllowSQSSendMessage"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.messages.arn]
  }
}

resource "aws_iam_role_policy" "task_role_inline" {
  name   = "${local.name}-task-role-inline"
  role   = aws_iam_role.task_role.id
  policy = data.aws_iam_policy_document.task_role_policy.json
}

# -------------------------
# Security Groups
# -------------------------
resource "aws_security_group" "alb" {
  name   = "${local.name}-alb-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name   = "${local.name}-ecs-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# ALB + Target Groups + Listener rules
# Routes:
#   /s3/*  -> flask-s3-service (8080)
#   /sqs/* -> flask-sqs-service (8081)
# -------------------------
resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnets
}

resource "aws_lb_target_group" "s3" {
  name        = "${local.name}-tg-s3"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_target_group" "sqs" {
  name        = "${local.name}-tg-sqs"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "OK - use /s3/health or /sqs/health"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "route_s3" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3.arn
  }

  condition {
    path_pattern {
      values = ["/s3/*"]
    }
  }
}

resource "aws_lb_listener_rule" "route_sqs" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sqs.arn
  }

  condition {
    path_pattern {
      values = ["/sqs/*"]
    }
  }
}

# -------------------------
# ECS Task Definitions
# (Images are variables for now; Phase 3 will use ECR image URIs)
# -------------------------
resource "aws_ecs_task_definition" "s3" {
  family                   = "${local.name}-flask-s3-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name         = "flask-s3-service"
      image        = var.s3_service_image
      portMappings = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "BUCKET_NAME", value = aws_s3_bucket.uploads.bucket },
        # Optional for Phase 3 routing: make app aware it sits behind /s3
        { name = "BASE_PATH", value = "/s3" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.s3.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "sqs" {
  family                   = "${local.name}-flask-sqs-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name         = "flask-sqs-service"
      image        = var.sqs_service_image
      portMappings = [{ containerPort = 8081, hostPort = 8081, protocol = "tcp" }]
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "QUEUE_URL", value = aws_sqs_queue.messages.url },
        # Optional for Phase 3 routing: make app aware it sits behind /sqs
        { name = "BASE_PATH", value = "/sqs" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.sqs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# -------------------------
# ECS Services
# -------------------------
resource "aws_ecs_service" "s3" {
  name            = "${local.name}-svc-s3"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.s3.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.public_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.s3.arn
    container_name   = "flask-s3-service"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "sqs" {
  name            = "${local.name}-svc-sqs"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.sqs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.public_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sqs.arn
    container_name   = "flask-sqs-service"
    container_port   = 8081
  }

  depends_on = [aws_lb_listener.http]
}
