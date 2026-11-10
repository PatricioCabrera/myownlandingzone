locals {
  scp_documents = {
    for file in fileset("${path.module}/policies", "*.json.tftpl") :
    trimsuffix(file, ".json.tftpl") => templatefile("${path.module}/policies/${file}", {
      allowed_regions = jsonencode(var.allowed_regions)
      bedrock_regions = jsonencode(var.bedrock_regions)
    })
  }

  # One entry per (OU, policy) pair, because for_each needs a flat map.
  scp_attachments = merge([
    for unit, policies in var.scp_attachments : {
      for policy in policies : "${unit}/${policy}" => {
        unit   = unit
        policy = policy
      }
    }
  ]...)
}

resource "aws_organizations_policy" "this" {
  for_each = local.scp_documents

  name    = each.key
  type    = "SERVICE_CONTROL_POLICY"
  content = each.value

  # No attribute links these, but SCPs cannot exist until the organization enables
  # the policy type, so the dependency has to be stated.
  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = local.scp_attachments

  policy_id = aws_organizations_policy.this[each.value.policy].id
  target_id = (
    each.value.unit == "Root"
    ? aws_organizations_organization.this.roots[0].id
    : aws_organizations_organizational_unit.this[each.value.unit].id
  )
}
