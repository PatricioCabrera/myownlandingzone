output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Subnet IDs, keyed by name"
  value       = { for name, subnet in aws_subnet.this : name => subnet.id }
}
