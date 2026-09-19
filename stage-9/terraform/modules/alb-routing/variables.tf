variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "stage8_target_group_arn" {
  type = string
}

variable "blue_weight" {
  type    = number
  default = 100
  validation {
    condition     = var.blue_weight >= 0 && var.blue_weight <= 100
    error_message = "blue_weight must be between 0 and 100."
  }
}

variable "green_weight" {
  type    = number
  default = 0
  validation {
    condition     = var.green_weight >= 0 && var.green_weight <= 100
    error_message = "green_weight must be between 0 and 100."
  }
}

variable "enable_blue_green_weighted" {
  type    = bool
  default = true
}

variable "enable_product_path_routing" {
  type    = bool
  default = false
}

variable "enable_order_path_routing" {
  type    = bool
  default = false
}

variable "enable_user_path_routing" {
  type    = bool
  default = false
}

variable "custom_header_name" {
  type    = string
  default = ""
}

variable "custom_header_value" {
  type      = string
  default   = ""
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
