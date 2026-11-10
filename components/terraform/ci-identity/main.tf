# Lets GitHub Actions in this repository reach the account without stored keys.
#
# Two roles, because a pull request runs code nobody has reviewed yet:
#   plan  - read-only, assumable from pull requests and from main
#   apply - can change what CI manages, assumable only from a GitHub Environment,
#           which is where the human approval lives
#
# This component is applied by a person, never by CI: a pipeline that manages its
# own role can grant itself anything.

locals {
  issuer = "token.actions.githubusercontent.com"

  oidc_provider_arn = (
    var.create_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : data.aws_iam_openid_connect_provider.github[0].arn
  )

  name = "myownlandingzone-ci"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.issuer}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://${local.issuer}"
}

# Every GitHub repository shares one issuer, so the sub condition is the whole
# security boundary. Exact matches only: no wildcards.
data "aws_iam_policy_document" "trust" {
  for_each = {
    plan  = [for context in var.plan_contexts : "${var.github_sub_prefix}:${context}"]
    apply = ["${var.github_sub_prefix}:environment:${var.apply_environment}"]
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:sub"
      values   = each.value
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "${local.name}-plan"
  description          = "Read-only role for terraform plan in GitHub Actions"
  assume_role_policy   = data.aws_iam_policy_document.trust["plan"].json
  max_session_duration = 3600
}

# Plan runs with -lock=false, so it never writes, not even a lock file.
resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role" "apply" {
  name                 = "${local.name}-apply"
  description          = "Applies the components CI manages, behind a GitHub Environment approval"
  assume_role_policy   = data.aws_iam_policy_document.trust["apply"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_read_only" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# One statement per component CI applies. A new component in CI means a new
# statement here, reviewed and applied by a person first.
data "aws_iam_policy_document" "apply" {
  statement {
    sid       = "State"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/${var.state_prefix}/*"]
  }

  statement {
    sid = "IpAllocations"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/platform/*"]
  }

  statement {
    sid = "BudgetAlertsTopic"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = ["arn:aws:sns:${var.aws_region}:${var.account_id}:budget-alerts"]
  }

  statement {
    sid = "Budget"
    actions = [
      "budgets:CreateBudget",
      "budgets:ModifyBudget",
      "budgets:DeleteBudget",
      "budgets:TagResource",
      "budgets:UntagResource",
    ]
    resources = ["arn:aws:budgets::${var.account_id}:budget/*"]
  }

  statement {
    sid = "AnomalyDetection"
    actions = [
      "ce:CreateAnomalyMonitor",
      "ce:UpdateAnomalyMonitor",
      "ce:DeleteAnomalyMonitor",
      "ce:CreateAnomalySubscription",
      "ce:UpdateAnomalySubscription",
      "ce:DeleteAnomalySubscription",
      "ce:TagResource",
      "ce:UntagResource",
    ]
    resources = [
      "arn:aws:ce::${var.account_id}:anomalymonitor/*",
      "arn:aws:ce::${var.account_id}:anomalysubscription/*",
    ]
  }
}

resource "aws_iam_role_policy" "apply" {
  name   = "apply-ci-components"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}
