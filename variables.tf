variable "project" {
  description = "Name to be used on all the resources as identifier"
  type        = string
}

variable "environment" {
  description = "The environment, and also used as a identifier"
  type        = string
  validation {
    condition     = try(length(regex("dev|prd|hml", var.environment)) > 0,false)
    error_message = "Define envrionment as one that follows: dev, hml or prd."
  }
}

variable "region" {
  description = "Region AWS where deploy occurs"
  type        = string
  default     = "us-east-1"
}

variable "application" {
  type = string
  description = "Name application"
}

########################################

variable "security_group_id" {
  type = string
  description = "Security group to be added for ECS instances"
}

variable "private_subnet_ids" {
  type = list(string)
  description = "List of private subnets to be attached on ECS instances"
}

variable "instance_type" {
  type = string
  description = "Instance type to be used as recomended"
  default = "t3.medium"
  # default = "t4g.medium" # Bem mais barato
}

