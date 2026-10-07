variable "aws_region" {
  description = "AWS region for the ECS deployment."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Short name used in AWS resource names, as the ECR repository name, and as the Project tag value for cost allocation."
  type        = string
  default     = "revision-annotation-app"
}

variable "environment" {
  description = "Environment value applied to the Environment tag on AWS resources."
  type        = string
  default     = "lean"
}

variable "backend_domain_name" {
  description = "Optional public hostname for the application, such as revision-annotation-app.lei-tech.org."
  type        = string
  default     = null
  nullable    = true
}

variable "hosted_zone_name" {
  description = "Name of the existing public Route53 hosted zone for backend_domain_name, such as lei-tech.org."
  type        = string
  default     = null
  nullable    = true
}

variable "existing_vpc_id" {
  description = "ID of the shared VPC used by the deployment."
  type        = string
}

variable "existing_private_subnet_ids" {
  description = "Private subnet IDs in the shared VPC for ECS tasks."
  type        = list(string)

  validation {
    condition     = length(var.existing_private_subnet_ids) >= 2
    error_message = "Provide at least two private subnet IDs."
  }
}

variable "existing_ecs_cluster_name" {
  description = "Name of the shared ECS cluster."
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID already configured for ECS task traffic from the shared ALB."
  type        = string
}

variable "existing_alb_arn" {
  description = "ARN of the shared Application Load Balancer."
  type        = string
}

variable "listener_rule_priority" {
  description = "Priority for the application rule on the shared ALB listener. Must be unique across all apps on the listener."
  type        = number

  validation {
    condition     = var.listener_rule_priority >= 1 && var.listener_rule_priority <= 50000
    error_message = "Listener rule priority must be between 1 and 50000."
  }
}

variable "alb_path_patterns" {
  description = "Path patterns routed from the shared ALB listener to this service."
  type        = list(string)
  default     = ["/*"]
}

variable "health_check_path" {
  description = "HTTP path used by the target group and container health checks. The app has no dedicated health route, so / (which serves the static page) is used."
  type        = string
  default     = "/"
}

variable "container_image" {
  description = "Fully-qualified ECR image URI, normally tagged with the Git commit SHA."
  type        = string
  default     = ""
}

variable "fargate_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "ECS service desired task count. The app is stateless (all work happens in the browser), so it can be scaled freely."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention period."
  type        = number
  default     = 30
}
