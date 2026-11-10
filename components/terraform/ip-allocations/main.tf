locals {
  # Terraform has no CIDR-overlap function, so each range becomes its first and
  # last address as a number, and numbers can be compared.
  ranges = {
    for name, a in var.allocations : name => {
      first = sum([for i, octet in split(".", cidrhost(a.cidr, 0)) : tonumber(octet) * pow(256, 3 - i)])
      last  = sum([for i, octet in split(".", cidrhost(a.cidr, -1)) : tonumber(octet) * pow(256, 3 - i)])
    }
  }

  pool = {
    first = sum([for i, octet in split(".", cidrhost(var.pool_cidr, 0)) : tonumber(octet) * pow(256, 3 - i)])
    last  = sum([for i, octet in split(".", cidrhost(var.pool_cidr, -1)) : tonumber(octet) * pow(256, 3 - i)])
  }

  # Each account only learns its own ranges.
  local_allocations = { for name, a in var.allocations : name => a if a.account == var.stage }
}

# Checks that need more than one variable cannot live in a variable validation, so
# they hang on this resource. It exists in every plan, so they always run.
resource "terraform_data" "checks" {
  input = var.allocations

  lifecycle {
    precondition {
      condition = alltrue([
        for name, a in local.ranges :
        a.first >= local.pool.first && a.last <= local.pool.last
      ])
      error_message = "Every allocation must fit inside pool_cidr."
    }

    precondition {
      condition = alltrue(flatten([
        for a_name, a in local.ranges : [
          for b_name, b in local.ranges :
          a_name == b_name || a.last < b.first || b.last < a.first
        ]
      ]))
      error_message = "Two allocations overlap. Each project needs its own range."
    }
  }
}

# A project reads its range from here and builds its own VPC with it.
resource "aws_ssm_parameter" "cidr" {
  for_each = local.local_allocations

  name        = "/platform/ip-allocations/${each.key}/cidr"
  description = each.value.description
  type        = "String"
  value       = each.value.cidr
}
