variable "aws_region" {
    description = "AWS region to deploy resources"
    type        = string
    default     = "eu-west-1"
}

variable "environment" {
    description = "Environment name (dev, staging, production)"
    type        = string
    default     = "production"
}

variable "project_name" {
    description = "Project name used for naming resources"
    type        = string
    default     = "terraform-cicd"
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
    default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "CIDR block for the public subnet"
    type        = string
    default     = "10.0.1.0/24"
}

variable "instance_type" {
    description = "EC2 instance type"
    type        = string
    default     = "t3.micro"
}

variable "ami_id" {
    description = "Ubuntu 22.04 LTS AMI ID for eu-west-1"
    type        = string
    default     = "ami-0905a3c97561e0b69"
}

variable "ssh_key_name" {
    description = "Name of the aws key pair for SSH access"
    type        = string
    default     = "prod-key"
}

variable "allowed_ssh_cidr" {
    description = "CIDR block for SSH access"
    type        = string
    default     = "0.0.0.0/0"
    # No default — you must provide this. Never hardcode IPs in code.
}
