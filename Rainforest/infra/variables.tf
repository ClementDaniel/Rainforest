variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (preprod or prod)"
  type        = string
  validation {
    condition     = contains(["preprod", "prod"], var.environment)
    error_message = "Environment must be preprod or prod"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_cpu" {
  description = "CPU units for container"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for container in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

# variable "github_org" {
#   description = "GitHub organization name"
#   type        = string
# }

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "deployment_configuration" {
  description = "Deployment configuration for ECS"
  type        = string
  default     = "RollingUpdate"
  validation {
    condition     = contains(["RollingUpdate"], var.deployment_configuration)
    error_message = "Deployment configuration must be RollingUpdate"
  }

}