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

variable "permission_sets" {
  description = "Permission sets to manage, keyed by name"
  type = map(object({
    session_duration    = string
    managed_policy_arns = list(string)
  }))
}

variable "owner_user_name" {
  description = "Identity Center user name, as provisioned from Entra ID. Set through TF_VAR_owner_user_name so it stays out of the repo."
  type        = string
}

variable "assignments" {
  description = "Account names per permission set for the owner. Accounts that do not exist yet are skipped."
  type        = map(list(string))
}
