# Atmos passes stage to every component, so it is declared even where unused.
# tflint-ignore: terraform_unused_declarations
variable "stage" {
  description = "Stack name, set by Atmos"
  type        = string
}

variable "aws_region" {
  description = "Region for the AWS provider. IAM is global."
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

variable "github_sub_prefix" {
  description = "Start of the OIDC sub claim for the repository, as returned by GET /repos/{owner}/{repo}/actions/oidc/customization/sub. Repositories created after July 2026 carry immutable owner and repository IDs in it."
  type        = string

  validation {
    condition     = can(regex("^repo:[^:*?]+$", var.github_sub_prefix))
    error_message = "github_sub_prefix must look like repo:owner@id/name@id, with no wildcards."
  }
}

variable "plan_contexts" {
  description = "Workflow contexts allowed to assume the read-only plan role, as sub claim suffixes"
  type        = list(string)
  default     = ["pull_request", "ref:refs/heads/main"]
}

variable "apply_environment" {
  description = "GitHub Environment whose jobs may assume the apply role. Its required reviewers are the approval gate."
  type        = string
}

variable "state_bucket" {
  description = "Bucket holding this account's Terraform state"
  type        = string
}

variable "state_prefix" {
  description = "Key prefix the apply role may write state under"
  type        = string
  default     = "myownlandingzone"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. An account holds one per issuer URL, so leave false where another project already owns it."
  type        = bool
  default     = false
}
