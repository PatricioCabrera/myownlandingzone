# Projects read the network from here, so they depend on a parameter name and not
# on this repo's Terraform state. Standard parameters are free.
resource "aws_ssm_parameter" "vpc_id" {
  #checkov:skip=CKV2_AWS_34:An ID is not a secret. SecureString would make every reader need kms:Decrypt.
  name  = "/platform/network/vpc_id"
  type  = "String"
  value = aws_vpc.this.id
}

resource "aws_ssm_parameter" "subnet_id" {
  #checkov:skip=CKV2_AWS_34:An ID is not a secret. SecureString would make every reader need kms:Decrypt.
  for_each = aws_subnet.this

  name  = "/platform/network/subnets/${each.key}/id"
  type  = "String"
  value = each.value.id
}
