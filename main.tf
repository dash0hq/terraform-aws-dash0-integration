# SPDX-FileCopyrightText: Copyright 2026 Dash0 Inc.

data "aws_caller_identity" "current" {}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  source_state_id = "${local.account_id}-${var.dash0_external_id}"
  api_endpoint    = "${var.dash0_api_url}/public/aws/iac-integration"
}

# -----------------------------------------------------------------------------
# Read-Only IAM Role
# Allows Dash0 to discover and monitor AWS resources.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "dash0_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.dash0_aws_account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.dash0_external_id]
    }
  }
}

resource "aws_iam_role" "dash0_read_only" {
  name               = "${var.iam_role_name_prefix}-read-only"
  assume_role_policy = data.aws_iam_policy_document.dash0_trust_policy.json
  tags               = var.tags
}

# ViewOnlyAccess managed policy (matches CloudFormation template)
resource "aws_iam_role_policy_attachment" "dash0_view_only" {
  role       = aws_iam_role.dash0_read_only.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# Additional read-only policies for resource discovery and monitoring
data "aws_iam_policy_document" "dash0_read_only_custom" {
  statement {
    effect = "Allow"
    actions = [
      "resource-explorer-2:Search",
      "resource-explorer-2:GetView",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "eks:ListClusters",
      "eks:DescribeCluster",
      "eks:ListNodegroups",
      "eks:DescribeNodegroup",
      "eks:ListFargateProfiles",
      "eks:DescribeFargateProfile",
      "eks:ListAddons",
      "eks:DescribeAddon",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "appsync:ListGraphqlApis",
      "appsync:GetGraphqlApi",
      "appsync:GetSchemaCreationStatus",
      "appsync:GetIntrospectionSchema",
      "appsync:ListDataSources",
      "appsync:ListResolvers",
      "appsync:ListFunctions",
      "appsync:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "xray:GetTraceSegmentDestination",
      "xray:GetIndexingRules",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "dash0_read_only_custom" {
  name   = "Dash0ReadOnly"
  role   = aws_iam_role.dash0_read_only.id
  policy = data.aws_iam_policy_document.dash0_read_only_custom.json
}

# -----------------------------------------------------------------------------
# Resources Instrumentation IAM Role (optional)
# Allows Dash0 to instrument AWS resources such as Lambda functions.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "dash0_instrumentation_policy" {
  count = var.enable_resources_instrumentation ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionConfiguration",
    ]
    resources = ["arn:aws:lambda:*:*:function:*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcAttribute",
      "lambda:GetLayerVersion",
      "lambda:GetLayerVersionPolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "dash0_instrumentation" {
  count = var.enable_resources_instrumentation ? 1 : 0

  name               = "${var.iam_role_name_prefix}-instrumentation"
  assume_role_policy = data.aws_iam_policy_document.dash0_trust_policy.json
  tags               = var.tags
}

resource "aws_iam_policy" "dash0_instrumentation" {
  count = var.enable_resources_instrumentation ? 1 : 0

  name   = "Dash0LambdaInstrumentation"
  policy = data.aws_iam_policy_document.dash0_instrumentation_policy[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "dash0_instrumentation" {
  count = var.enable_resources_instrumentation ? 1 : 0

  role       = aws_iam_role.dash0_instrumentation[0].name
  policy_arn = aws_iam_policy.dash0_instrumentation[0].arn
}

# -----------------------------------------------------------------------------
# Register integration with Dash0 API
# -----------------------------------------------------------------------------
locals {
  create_payload = jsonencode({
    action                          = "create_or_update"
    source                          = "terraform"
    sourceStateId                   = local.source_state_id
    roleArn                         = aws_iam_role.dash0_read_only.arn
    resourcesInstrumentationRoleArn = var.enable_resources_instrumentation ? aws_iam_role.dash0_instrumentation[0].arn : null
    externalId                      = var.dash0_external_id
    dataset                         = var.dash0_dataset
  })

  delete_payload = jsonencode({
    action        = "delete"
    source        = "terraform"
    sourceStateId = local.source_state_id
    externalId    = var.dash0_external_id
  })
}

resource "null_resource" "dash0_integration" {
  triggers = {
    api_endpoint   = local.api_endpoint
    api_key        = var.dash0_api_key
    payload        = local.create_payload
    delete_payload = local.delete_payload
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sf -X POST "${local.api_endpoint}" \
        -H "Authorization: Bearer ${var.dash0_api_key}" \
        -H "Content-Type: application/json" \
        -d '${local.create_payload}'
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -sf -X POST "${self.triggers.api_endpoint}" \
        -H "Authorization: Bearer ${self.triggers.api_key}" \
        -H "Content-Type: application/json" \
        -d '${self.triggers.delete_payload}'
    EOT
  }

  depends_on = [
    aws_iam_role_policy_attachment.dash0_view_only,
    aws_iam_role_policy.dash0_read_only_custom,
    aws_iam_role_policy_attachment.dash0_instrumentation,
  ]
}