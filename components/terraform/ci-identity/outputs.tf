output "plan_role_name" {
  description = "Role the plan and drift jobs assume"
  value       = aws_iam_role.plan.name
}

output "apply_role_name" {
  description = "Role the apply job assumes, from the GitHub Environment only"
  value       = aws_iam_role.apply.name
}
