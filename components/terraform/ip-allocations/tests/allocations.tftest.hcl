# Runs offline: the AWS provider is mocked, so these only test the validation logic.
mock_provider "aws" {}

variables {
  stage      = "workloads"
  aws_region = "us-east-1"
  account_id = "111111111111"
  pool_cidr  = "10.0.0.0/16"
}

run "accepts_ranges_that_do_not_overlap" {
  command = plan

  variables {
    allocations = {
      cloudlaunchpad = { cidr = "10.0.0.0/21", account = "workloads", description = "CloudLaunchpad VPC" }
      other          = { cidr = "10.0.8.0/22", account = "management", description = "Another account" }
    }
  }

  assert {
    condition     = output.published == { cloudlaunchpad = "10.0.0.0/21" }
    error_message = "Only this account's allocation should be published."
  }
}

run "rejects_overlapping_ranges" {
  command = plan

  variables {
    allocations = {
      a = { cidr = "10.0.0.0/21", account = "workloads", description = "a" }
      b = { cidr = "10.0.4.0/24", account = "workloads", description = "b" }
    }
  }

  expect_failures = [terraform_data.checks]
}

run "rejects_ranges_outside_the_pool" {
  command = plan

  variables {
    allocations = {
      a = { cidr = "192.168.0.0/24", account = "workloads", description = "a" }
    }
  }

  expect_failures = [terraform_data.checks]
}

run "rejects_a_host_address" {
  command = plan

  variables {
    allocations = {
      a = { cidr = "10.0.0.5/24", account = "workloads", description = "a" }
    }
  }

  expect_failures = [var.allocations]
}
