# ============================================================
# General
# ============================================================

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "medusa"
}

# ============================================================
# VPC / Networking
# ============================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use (must match the number of subnet CIDRs)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ============================================================
# EC2 (ECS container instances)
# ============================================================

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "t3.medium"
}

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "ec2_key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access (leave empty to skip)"
  type        = string
  default     = ""
}

# ============================================================
# RDS (PostgreSQL)
# ============================================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "medusa"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "medusa"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GiB"
  type        = number
  default     = 20
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups (0 disables backups)"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS high availability"
  type        = bool
  default     = false
}

# ============================================================
# ECS
# ============================================================

variable "medusa_cpu" {
  description = "CPU units allocated to the Medusa ECS task (1 vCPU = 1024)"
  type        = number
  default     = 512
}

variable "medusa_memory" {
  description = "Memory (MiB) allocated to the Medusa ECS task"
  type        = number
  default     = 1024
}

variable "medusa_desired_count" {
  description = "Desired number of running Medusa ECS tasks"
  type        = number
  default     = 2
}

variable "medusa_container_port" {
  description = "Port the Medusa container listens on"
  type        = number
  default     = 9000
}

# ============================================================
# Application secrets (injected via Secrets Manager at runtime)
# ============================================================

variable "jwt_secret" {
  description = "JWT secret for Medusa authentication"
  type        = string
  sensitive   = true
}

variable "cookie_secret" {
  description = "Cookie secret for Medusa sessions"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}
