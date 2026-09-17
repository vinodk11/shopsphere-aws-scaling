# ==============================================================================
# ECR Module - Stage 9 Microservices Container Registries
# Creates hardened, immutable, scan-on-push ECR repositories for each service
# ==============================================================================

locals {
  services = ["product", "order", "user"]
}

resource "aws_ecr_repository" "microservices" {
  for_each             = toset(local.services)
  name                 = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-${each.key}"
      Service     = each.key
      Stage       = "Stage-9"
      Environment = var.environment
    }
  )
}

# Lifecycle policy: Retain last 30 immutable release tags, prune untagged images after 1 day
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain maximum 30 immutable release images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "build"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
