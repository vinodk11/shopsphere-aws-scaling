variable "project_name" {
  description = "Project name identifier"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where target groups are created"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the existing Application Load Balancer HTTP Listener"
  type        = string
}

variable "stage8_target_group_arn" {
  description = "ARN of the existing Stage 8 (Blue) Target Group"
  type        = string
}

variable "blue_weight" {
  description = "Traffic weight for Stage 8 (Blue) Target Group (0 - 100)"
  type        = number
  default     = 100
}

variable "green_weight" {
  description = "Traffic weight for Stage 9 (Green) Target Group (0 - 100)"
  type        = number
  default     = 0
}

variable "enable_blue_green_weighted" {
  description = "Enable the weighted Blue/Green listener rule"
  type        = bool
  default     = true
}

variable "enable_product_path_routing" {
  description = "Enable routing /api/products* to Stage 9 Product Service"
  type        = bool
  default     = false
}

variable "enable_order_path_routing" {
  description = "Enable routing /api/orders* to Stage 9 Order Service"
  type        = bool
  default     = false
}

variable "custom_header_name" {
  description = "Custom header name for CloudFront origin verification"
  type        = string
  default     = ""
}

variable "custom_header_value" {
  description = "Custom header value for CloudFront origin verification"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Standard tags to assign to resources"
  type        = map(string)
  default     = {}
}
