data "aws_ssoadmin_instances" "this" {}

# Reading accounts from the organization, not from the organization component's
# state, lets this component plan before the workloads account exists. The
# assignment appears on the first apply after the account does.
data "aws_organizations_organization" "this" {}

data "aws_identitystore_user" "owner" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.owner_user_name
    }
  }
}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  account_ids = {
    for account in data.aws_organizations_organization.this.accounts :
    account.name => account.id if account.status == "ACTIVE"
  }

  managed_policy_attachments = merge([
    for name, set in var.permission_sets : {
      for arn in set.managed_policy_arns : "${name}/${arn}" => {
        permission_set = name
        arn            = arn
      }
    }
  ]...)

  # One entry per (permission set, account) that actually exists.
  account_assignments = merge([
    for set, accounts in var.assignments : {
      for account in accounts : "${set}/${account}" => {
        permission_set = set
        account_id     = local.account_ids[account]
      } if contains(keys(local.account_ids), account)
    }
  ]...)
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = var.permission_sets

  name             = each.key
  instance_arn     = local.instance_arn
  session_duration = each.value.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.managed_policy_attachments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  managed_policy_arn = each.value.arn
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.account_assignments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_id       = data.aws_identitystore_user.owner.user_id
  principal_type     = "USER"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}
