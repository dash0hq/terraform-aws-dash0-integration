# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.

# Basic example: read-only AWS integration with Dash0

provider "aws" {
  region = "eu-west-1"
}

module "dash0_aws_integration" {
  source = "dash0hq/dash0-integration/aws"

  dash0_api_key     = var.dash0_api_key
  dash0_external_id = var.dash0_external_id
  dash0_dataset     = "default"
}

variable "dash0_api_key" {
  type      = string
  sensitive = true
}

variable "dash0_external_id" {
  type = string
}

output "read_only_role_arn" {
  value = module.dash0_aws_integration.read_only_role_arn
}