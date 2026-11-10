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

variable "allowed_regions" {
  description = "Regions that member accounts may use"
  type        = list(string)
}

variable "bedrock_regions" {
  description = "Regions Bedrock inference may reach. A cross-Region inference profile fails if an SCP blocks any of its destination Regions, so this must list all of them."
  type        = list(string)
}

variable "trusted_service_principals" {
  description = "AWS services with trusted access to the organization. Removing sso.amazonaws.com breaks Identity Center."
  type        = list(string)
  default     = ["sso.amazonaws.com"]
}

variable "organizational_units" {
  description = "Organizational units directly under the root"
  type        = set(string)
}

variable "accounts" {
  description = "Member accounts to create, keyed by account name"
  type = map(object({
    organizational_unit = string
  }))
}

variable "account_emails" {
  description = "Root email per account in var.accounts. Set through TF_VAR_account_emails so addresses stay out of the repo."
  type        = map(string)
  sensitive   = true
}

variable "delegated_administrators" {
  description = "Member account that administers each AWS service, keyed by service principal. Keeps day-to-day administration out of the management account."
  type        = map(string)
  default     = {}
}

variable "scp_attachments" {
  description = "Policy names from policies/ to attach, keyed by organizational unit name, or \"Root\" for every member account"
  type        = map(list(string))
}
