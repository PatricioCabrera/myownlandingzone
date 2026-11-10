# Cost guardrails for one whole account. They belong to the platform, not to a
# project: a project that is destroyed after every session would take them with it.

data "aws_iam_policy_document" "allow_services" {
  statement {
    sid    = "1"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com", "costalerts.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    # Without it, any account's Budgets or Cost Anomaly Detection could publish here.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# Accepted finding: messages carry only spend figures and SNS holds them just
# until delivery. Encrypting needs a customer managed key (~$1/month) with a key
# policy for both publishing services.
#trivy:ignore:AWS-0095
resource "aws_sns_topic" "alerts" {
  name = "budget-alerts"
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.allow_services.json
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_budgets_budget" "monthly" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = tostring(var.limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.alert_thresholds

    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
    }
  }
}

# AWS allows one SERVICE-dimension monitor per account, which is why it lives
# here and not in any project.
resource "aws_ce_anomaly_monitor" "services" {
  name              = "account-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

# IMMEDIATE because Cost Anomaly Detection delivers to SNS only at that frequency.
resource "aws_ce_anomaly_subscription" "services" {
  name             = var.anomaly_subscription_name
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }
}
