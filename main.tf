terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.48.0"
    }
  }
}

provider "aws" {
  region                   = "us-east-1"
  shared_config_files      = ["/Users/dislexicmofo/.aws/conf"]
  shared_credentials_files = ["/Users/dislexicmofo/.aws/credentials"]
  profile                  = "provisioner"
  default_tags {
    tags = {
      project     = "thiswiththat"
      environment = "production"
    }
  }
}

resource "aws_ecr_repository" "aws_ecr_repository" {
  name                 = "thiswiththat"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_kms_key" "aws_kms_key" {
  description             = "thiswiththat"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "aws_cloudwatch_log_group" {
  name = "thiswiththat"
}

resource "aws_ecs_cluster" "aws_ecs_cluster" {
  name = "thiswiththat"

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.aws_kms_key.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.aws_cloudwatch_log_group.name
      }
    }
  }
}

resource "aws_ecs_task_definition" "service" {
  family = "service"
  container_definitions = jsonencode([
    {
      name      = "thiswiththat-api"
      image     = "service-first"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_iam_role" "ecs_service_role" {
  name = "ecs_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "service_policy"
  role = aws_iam_role.ecs_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_ecs_service" "thiswiththat" {
  name            = "thiswiththat"
  cluster         = aws_ecs_cluster.aws_ecs_cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 3
  iam_role        = aws_iam_role.ecs_service_role.arn
  depends_on      = [aws_iam_role_policy.ecs_service_policy]

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.test.id
    container_name   = "mongo"
    container_port   = 8080
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}
