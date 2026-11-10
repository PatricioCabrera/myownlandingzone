# prevent_destroy matters here: deleting the organization takes Identity Center
# with it.
resource "aws_organizations_organization" "this" {
  feature_set                   = "ALL"
  aws_service_access_principals = var.trusted_service_principals
  enabled_policy_types          = ["SERVICE_CONTROL_POLICY"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "this" {
  for_each = var.organizational_units

  name      = each.key
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name      = each.key
  email     = var.account_emails[each.key]
  parent_id = aws_organizations_organizational_unit.this[each.value.organizational_unit].id

  # Removing an account from this map must never close it by accident. Closing an
  # AWS account is deliberate and slow to undo, so it stays a manual step.
  close_on_deletion = false

  # This role is the way into the account before Identity Center is assigned.
  role_name = "OrganizationAccountAccessRole"

  lifecycle {
    prevent_destroy = true
    # AWS never returns role_name, and a changed email forces a replacement, so
    # either one would plan to recreate the account.
    ignore_changes = [role_name, email]
  }
}

# Identity Center can only have one delegated administrator, and the service must
# already be enabled in the management account before this registers.
resource "aws_organizations_delegated_administrator" "this" {
  for_each = var.delegated_administrators

  service_principal = each.key
  account_id        = aws_organizations_account.this[each.value].id
}
