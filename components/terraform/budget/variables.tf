variable "aws_region" {
  description = "Region for the SNS topic. Budgets and Cost Anomaly Detection are global."
  type        = string
}

variable "account_id" {
  description = "The only AWS account this stack may run against. The provider refuses any other."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Set account_id in the stack to a 12-digit AWS account ID."
  }
}

variable "notification_email" {
  description = "Receives every budget and anomaly alert. Set through TF_VAR_notification_email so the address stays out of the repo."
  type        = string
  sensitive   = true
}

variable "budget_name" {
  description = "Name of the monthly cost budget. AWS replaces a budget when its name changes."
  type        = string
  default     = "account-monthly"
}

variable "anomaly_subscription_name" {
  description = "Name of the anomaly alert subscription. AWS replaces a subscription when its name changes."
  type        = string
  default     = "account-services-immediate"
}

variable "limit_usd" {
  description = "Monthly spend ceiling for the whole account, in USD"
  type        = number
}

variable "alert_thresholds" {
  description = "Percentages of limit_usd that send an alert once actual spend crosses them"
  type        = set(number)
  default     = [50, 80, 100]
}

variable "anomaly_threshold_usd" {
  description = "Minimum total impact, in USD, for a cost anomaly to send an alert"
  type        = number
  default     = 100
}
