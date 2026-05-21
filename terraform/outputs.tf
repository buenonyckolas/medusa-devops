# ============================================================
# Outputs — values useful after apply (e.g. for CI/CD, DNS setup)
# ============================================================

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (used to create Route 53 alias records)"
  value       = aws_lb.main.zone_id
}

output "ecr_medusa_url" {
  description = "ECR repository URL for the Medusa backend image"
  value       = aws_ecr_repository.medusa.repository_url
}

output "ecr_nginx_url" {
  description = "ECR repository URL for the Nginx image"
  value       = aws_ecr_repository.nginx.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the Medusa ECS service"
  value       = aws_ecs_service.medusa.name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port)"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_db_name" {
  description = "Name of the PostgreSQL database"
  value       = aws_db_instance.postgres.db_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}
