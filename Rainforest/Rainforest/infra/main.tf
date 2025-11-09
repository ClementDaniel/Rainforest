terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   # Configure with -backend-config or environment variables
  #   # bucket = "rainforest-tfstate"
  #   # key    = "rainforest-api/terraform.tfstate"
  #   # region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "rainforest-api"
      Environment = var.environment
      ManagedBy   = "Daniel"
    }
  }
}

locals {
  name_prefix = "rainforest-api-${var.environment}"
  common_tags = {
    Project     = "rainforest-api"
    Environment = var.environment
    ManagedBy   = "Daniel"
  }
}