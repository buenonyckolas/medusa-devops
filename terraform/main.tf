terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in S3 — bucket must be created manually before first apply
  backend "s3" {
    bucket         = "medusa-terraform-state-bnyck"
    key            = "medusa/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "medusa-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "medusa-ecommerce"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
