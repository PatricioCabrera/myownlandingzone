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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnets" {
  description = "Subnets keyed by name. az_index picks from the region's availability zones."
  type = map(object({
    cidr     = string
    public   = bool
    az_index = number
  }))
}

variable "flow_log_retention_days" {
  description = "Days to keep VPC flow logs"
  type        = number
  default     = 30
}
