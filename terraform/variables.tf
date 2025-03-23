variable "region" {
  type    = string
  default = "us-east-2"
}

variable "email" {
  type        = string
  default     = "johnduran.placeholder@gmail.com"
  description = "Email for subscription to SNS Topic"
}
