# myownlandingzone

My personal AWS foundation, defined as code: the organization, accounts, guardrails, access, state and networks. It is the layer my other projects stand on.

**Status:** bootstrapped on 2026-11-09: three accounts, SCPs, Identity Center federated with Entra ID. See [Bootstrap](docs/bootstrap.md).

| Account | Purpose |
|---------|---------|
| `management` | Organization, billing, SCPs. Only people sign in. |
| `identity` | Delegated administrator for Identity Center |
| `workloads` | Projects such as CloudLaunchpad |

## What it manages

| Component | Stack | Contents |
|-----------|-------|----------|
| `tfstate` | `management` | The state bucket for this account |
| `organization` | `management` | The organization, OUs, member accounts, SCPs, delegated administrators |
| `identity-center` | `management` | Only the permission set provisioned to `management`, which only `management` can change |
| `identity-center` | `identity` | Everyday permission sets and assignments for every member account |
| `tfstate` | `identity` | The state bucket for that account |
| `budget` | `workloads` | Account-wide monthly budget, Cost Anomaly Detection and their SNS topic |
| `ip-allocations` | `workloads` | CIDR ranges reserved per project, published to SSM |
| `ci-identity` | `workloads` | The roles GitHub Actions assumes: read-only for plans, scoped write for applies |
| `network` | none yet | A VPC for platform or shared infrastructure, when one is needed |

Identity Center itself cannot be created by Terraform in a management account, and the identity source cannot either. Both are console steps in the bootstrap.

## Layout

```
├── atmos.yaml
├── components/terraform/   # plain Terraform root modules
├── stacks/
│   ├── catalog/            # how each component is configured
│   └── deploy/             # one stack per AWS account
└── docs/
```

A component is ordinary Terraform. A stack says where it runs and with which values. Atmos merges those, generates the backend and variables, and selects the workspace.

## Running it

Requires Terraform 1.11+, Atmos, and AWS profiles named `management`, `identity` and `workloads`.

```bash
atmos terraform plan network -s workloads
atmos terraform apply network -s workloads
```

Tests run offline, with the AWS provider mocked:

```bash
cd components/terraform/ip-allocations && terraform test
```

Always go through `atmos`. It selects the workspace from the stack; plain `terraform` uses whichever workspace was left selected.

Local values stay out of the repo:

```bash
export TF_VAR_account_emails='{"workloads":"<root email>"}'
export TF_VAR_owner_user_name='<Entra user principal name>'
```

## Guardrails

SCPs attach to the organization root, so they reach every member account, including future ones. They never apply to the management account.

| Policy | Denies |
|--------|--------|
| `baseline` | Leaving the organization, the root user, IAM users and access keys, changes to the break-glass role |
| `regions` | Regional services outside `us-east-1`; Bedrock inference outside the regions its inference profiles use |
| `cost` | NAT Gateways, and EC2, RDS and ElastiCache above small or micro sizes |

## Documentation

- [Bootstrap](docs/bootstrap.md): from a new account to a working organization
- [Platform model](docs/platform-model.md): stacks, state, permissions, networks, and AI
- [CI/CD](docs/ci.md): what the pipeline checks, how it reaches AWS, and why
- [Entra ID federation](docs/entra-federation.md): the identity source runbook
