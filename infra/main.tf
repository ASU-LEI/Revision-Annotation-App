terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_vpc" "shared" {
  id = var.existing_vpc_id
}

data "aws_subnet" "private" {
  for_each = toset(var.existing_private_subnet_ids)

  id = each.value
}

data "aws_ecs_cluster" "shared" {
  cluster_name = var.existing_ecs_cluster_name
}

data "aws_security_group" "ecs" {
  id = var.ecs_security_group_id
}

data "aws_lb" "shared" {
  arn = var.existing_alb_arn
}

locals {
  container_image     = var.container_image != "" ? var.container_image : "${data.aws_ecr_repository.app.repository_url}:latest"
  service_name        = "${var.project_name}-service"
  container_name      = "${var.project_name}-app"
  container_port      = 8000
  backend_domain_name = trimspace(coalesce(var.backend_domain_name, ""))
  hosted_zone_name    = trimspace(coalesce(var.hosted_zone_name, ""))
  domain_enabled      = local.backend_domain_name != ""
  hosted_zone_id      = try(data.aws_route53_zone.shared[0].zone_id, "")
}

data "aws_route53_zone" "shared" {
  count = local.domain_enabled && local.hosted_zone_name != "" ? 1 : 0

  name         = local.hosted_zone_name
  private_zone = false
}

data "aws_ecr_repository" "app" {
  name = var.project_name
}

data "aws_lb_listener" "https" {
  count = local.domain_enabled ? 1 : 0

  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb_target_group" "app" {
  name        = substr(replace(var.project_name, "_", "-"), 0, 32)
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.shared.id

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_acm_certificate" "app" {
  count = local.domain_enabled ? 1 : 0

  domain_name       = local.backend_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = local.hosted_zone_name != "" && local.hosted_zone_id != ""
      error_message = "hosted_zone_name must identify an existing public Route53 hosted zone when backend_domain_name is configured."
    }
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = local.domain_enabled ? {
    for option in aws_acm_certificate.app[0].domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  zone_id         = local.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app" {
  count = local.domain_enabled ? 1 : 0

  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

resource "aws_lb_listener_certificate" "app" {
  count = local.domain_enabled ? 1 : 0

  listener_arn    = data.aws_lb_listener.https[0].arn
  certificate_arn = aws_acm_certificate_validation.app[0].certificate_arn
}

resource "aws_route53_record" "app" {
  count = local.domain_enabled ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = local.backend_domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.shared.dns_name
    zone_id                = data.aws_lb.shared.zone_id
    evaluate_target_health = false
  }
}

resource "aws_lb_listener_rule" "https" {
  count = local.domain_enabled ? 1 : 0

  listener_arn = data.aws_lb_listener.https[0].arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    host_header {
      values = [local.backend_domain_name]
    }
  }

  condition {
    path_pattern {
      values = var.alb_path_patterns
    }
  }

  depends_on = [aws_lb_listener_certificate.app]
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = aws_iam_role.execution.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = local.container_image
      essential = true

      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PORT", value = tostring(local.container_port) }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${local.container_port}${var.health_check_path}')\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name             = local.service_name
  cluster          = data.aws_ecs_cluster.shared.id
  task_definition  = aws_ecs_task_definition.app.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = [for subnet in data.aws_subnet.private : subnet.id]
    security_groups  = [data.aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  depends_on = [
    aws_lb_listener_rule.https
  ]
}
