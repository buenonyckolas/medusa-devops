# ============================================================
# RDS — PostgreSQL
# ============================================================

# Subnet group places the RDS instance inside our private subnets
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for Medusa PostgreSQL RDS instance"
  subnet_ids  = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# Parameter group allows custom PostgreSQL configuration
resource "aws_db_parameter_group" "postgres" {
  name        = "${var.project_name}-postgres15"
  family      = "postgres15"
  description = "Custom parameter group for Medusa PostgreSQL 15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    # Log queries that take longer than 1 second (value is in milliseconds)
    value = "1000"
  }

  tags = { Name = "${var.project_name}-postgres15-params" }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_instance_class

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2 # Enable storage autoscaling up to 2×
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # Only reachable from within the VPC

  # Configuration
  parameter_group_name = aws_db_parameter_group.postgres.name

  # High availability
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00" # UTC — runs during low-traffic hours
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Disable deletion protection in non-production environments;
  # set to true for production to prevent accidental data loss
  deletion_protection = var.environment == "production" ? true : false

  # Skip final snapshot only in non-production environments
  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-final-snapshot" : null

  tags = { Name = "${var.project_name}-postgres" }
}
