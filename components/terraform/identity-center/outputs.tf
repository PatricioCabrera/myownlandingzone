output "permission_set_arns" {
  description = "Permission set ARNs, keyed by name"
  value       = { for name, set in aws_ssoadmin_permission_set.this : name => set.arn }
}
