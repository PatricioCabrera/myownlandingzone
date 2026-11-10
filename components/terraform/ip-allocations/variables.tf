variable "stage" {
  description = "Stack name, set by Atmos. Only allocations whose account matches it are published."
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

variable "pool_cidr" {
  description = "Address space every allocation must fit inside"
  type        = string

  validation {
    condition     = can(cidrhost(var.pool_cidr, 0)) && cidrsubnet(var.pool_cidr, 0, 0) == var.pool_cidr
    error_message = "pool_cidr must be a network address in CIDR form, such as 10.0.0.0/16."
  }
}

variable "allocations" {
  description = "CIDR ranges reserved per project, keyed by project name"
  type = map(object({
    cidr        = string
    account     = string
    description = string
  }))

  validation {
    condition     = alltrue([for name, a in var.allocations : can(cidrhost(a.cidr, 0)) && cidrsubnet(a.cidr, 0, 0) == a.cidr])
    error_message = "Every allocation must be a network address in CIDR form, such as 10.0.0.0/21."
  }
}
