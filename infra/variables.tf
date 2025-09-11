variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "my_ip" {
  description = "Your current public IP: curl ifconfig.me"
  type        = string
  default     = "124.148.74.251/32"
}

variable "key_name" {
  default = "ec2-deploy-key"
}