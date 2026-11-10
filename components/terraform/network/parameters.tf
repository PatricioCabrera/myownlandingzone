# Projects read the network from here, so they depend on a parameter name and not
# on this repo's Terraform state. Standard parameters are free.
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/platform/network/vpc_id"
  type  = "String"
  value = aws_vpc.this.id
}

resource "aws_ssm_parameter" "subnet_id" {
  for_each = aws_subnet.this

  name  = "/platform/network/subnets/${each.key}/id"
  type  = "String"
  value = each.value.id
}
