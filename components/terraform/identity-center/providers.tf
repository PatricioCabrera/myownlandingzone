provider "aws" {
  region = var.aws_region

  # Stops the run before touching any resource if the credentials belong to another account.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project   = "myownlandingzone"
      ManagedBy = "Terraform"
    }
  }
}
