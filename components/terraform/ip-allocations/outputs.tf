output "published" {
  description = "Allocations published in this account, keyed by project"
  value       = { for name, a in local.local_allocations : name => a.cidr }
}
