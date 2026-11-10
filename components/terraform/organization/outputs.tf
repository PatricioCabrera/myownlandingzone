output "organization_id" {
  description = "Organization ID"
  value       = aws_organizations_organization.this.id
}

output "organizational_unit_ids" {
  description = "Organizational unit IDs, keyed by name"
  value       = { for name, unit in aws_organizations_organizational_unit.this : name => unit.id }
}

output "delegated_administrators" {
  description = "Delegated administrator account ID, keyed by service principal"
  value       = { for service, admin in aws_organizations_delegated_administrator.this : service => admin.account_id }
}

output "account_ids" {
  description = "Member account IDs, keyed by name"
  value       = { for name, account in aws_organizations_account.this : name => account.id }
}
