# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.

output "read_only_role_arn" {
  description = "The ARN of the Dash0 read-only IAM role."
  value       = aws_iam_role.dash0_read_only.arn
}

output "instrumentation_role_arn" {
  description = "The ARN of the Dash0 resources instrumentation IAM role (null if not enabled)."
  value       = var.enable_resources_instrumentation ? aws_iam_role.dash0_instrumentation[0].arn : null
}

output "aws_account_id" {
  description = "The AWS account ID where the integration was created."
  value       = local.account_id
}