# ==============================================================================
# RDS Module - Stage 2 Managed Amazon RDS PostgreSQL Database
# ==============================================================================

# 1. DB Subnet Group across private subnets
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "ShopSphere RDS database subnet group spanning multiple private AZs"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
      Tier = "Private-Database"
    }
  )
}

# 2. DB Parameter Group (Optimized for PostgreSQL 15)
resource "aws_db_parameter_group" "this" {
  name        = "${var.project_name}-${var.environment}-postgres15-params"
  family      = "postgres15"
  description = "ShopSphere custom parameter group for PostgreSQL 15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-pg-params"
    }
  )
}

# 3. Amazon RDS PostgreSQL Instance
resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true

  # Database credentials
  db_name  = var.db_name
  username = var.db_user
  password = var.db_password
  port     = var.db_port

  # Network & Security
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  # Maintenance & Backup
  backup_retention_period     = var.backup_retention_period
  backup_window               = var.backup_window
  maintenance_window          = var.maintenance_window
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  # Lifecycle & Teardown Protection
  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection
  apply_immediately   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-postgres-db"
      Tier = "Private-Database"
    }
  )
}
