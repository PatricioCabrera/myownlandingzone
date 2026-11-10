# Atmos passes stage to every component, so it is declared even where unused.
# tflint-ignore: terraform_unused_declarations
variable "stage" {
  description = "Stack name, set by Atmos"
  type        = string
}

variable "aws_region" {
  description = "Region for the AWS provider"
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

variable "bucket_name" {
  description = "State bucket for this account. Projects use one prefix each inside it."
  type        = string
}

variable "noncurrent_version_days" {
  description = "Days to keep old state versions"
  type        = number
  default     = 90
}
