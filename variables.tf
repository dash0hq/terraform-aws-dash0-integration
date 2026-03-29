# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.

variable "dash0_api_url" {
  type        = string
  description = "The Dash0 API base URL."
  default     = "https://api.dash0.com"
}

variable "dash0_api_key" {
  type        = string
  sensitive   = true
  description = "The Dash0 API key (auth token) used to authenticate with the Dash0 API."
}

variable "dash0_external_id" {
  type        = string
  description = "The Dash0 organization technical ID, used as the STS AssumeRole external ID."
}

variable "dash0_dataset" {
  type        = string
  description = "The Dash0 dataset slug to associate with this integration."
  default     = "default"
}

variable "dash0_aws_account_id" {
  type        = string
  description = "The Dash0 AWS account ID that will assume the IAM roles (used in the trust policy)."
  default     = "115813213817"
}

variable "enable_resources_instrumentation" {
  type        = bool
  description = "Whether to create an additional IAM role for resources instrumentation (e.g., Lambda auto-instrumentation)."
  default     = false
}

variable "iam_role_name_prefix" {
  type        = string
  description = "Prefix for the IAM role names created by this module."
  default     = "dash0"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}