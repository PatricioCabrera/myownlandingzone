# Platform model

## Layers

| Layer | Owns | Changes |
|-------|------|---------|
| Organization | Accounts, OUs, SCPs | Rarely |
| Identity | Human access from the `identity` account, CI roles per project | Per project |
| State | Buckets and paths | Once per account, then per project |
| Network | VPCs and subnets | Rarely |
| Projects | Their own infrastructure | Constantly |

## Stacks

A stack is one deployment target: where a component runs and with which values. Here that is one stack per account, because that is all this repo needs today. Nothing in Atmos requires it. The name can combine account, environment or project, such as `apps-qa-fidu`.

## State

One bucket per account, one prefix per project. Buckets live in the account-regional namespace, so their names never collide with another account's. A role is granted its project's prefix, so a project can add stacks without a permission change.

Stacks in this repo use Terraform workspaces, selected by Atmos:

```
myownlandingzone/organization/management/terraform.tfstate
└── workspace_key_prefix ───┘ └─ stack ─┘
```

`tfstate` creates the bucket and keeps its own state locally, because it cannot store state in a bucket that does not exist yet. State and CI identity share this repo as separate components with separate state: they change together, so splitting repos would only add coordinated PRs.

## Permissions

The account is the blast radius. Workloads run in a member account, and SCPs set a ceiling nothing inside that account can remove, including roles CI creates later.

That replaces a shared permissions boundary here. A boundary earns its place when several teams share an account; with one project owner per account it would repeat what the SCPs and the role's own policy already say.

The tradeoff: a CI role that can create IAM roles can reach admin inside its account. SCPs still apply, the account is disposable, and every permission change goes through a reviewed PR.

SCPs do not apply to the management account, so it is protected differently: no OIDC provider and no CI role ever exist there. Only people sign in to it. A role in `workloads` cannot reach it, because nothing in management trusts that role. This repo's CI can plan and report, but `organization` and `identity-center` are applied by a person.

## Identity

Identity Center belongs to the management account, but its administration is delegated to `identity`. Users come from Entra ID through SCIM, and permission sets and assignments live in this repo.

AWS keeps four things in management: enabling Identity Center, deleting it, registering the delegated administrator, and any permission set provisioned to management. So the `management` stack holds a single permission set, `PlatformAdmin`, and everything else is applied from `identity`.

## Network

The platform decides address space; a project decides its own network. `ip-allocations` reserves a range per project, rejects overlaps, and publishes it to `/platform/ip-allocations/<project>/cidr` in that project's account. The project reads it and builds its VPC there, so it never waits on the platform for a subnet change.

`network` exists for the platform's own infrastructure. Its VPC takes the `platform-network` range.

There is no NAT Gateway, Transit Gateway or interface endpoint, because each would break the budget on its own. The `cost` SCP denies NAT Gateways in every member account. With a hub, the split would stay the same: a project creates its attachment, and the platform decides which route tables it joins.

## CI identity (not built yet)

Per project, in the account it deploys to:

| Role | Trusted subject | Permissions |
|------|-----------------|-------------|
| `<project>-plan` | Pull requests | Read, plus its state prefix |
| `<project>-apply` | The `production` environment | What the project deploys |

Code that has not been reviewed never gets the apply role.

## Permission changes (not built yet)

1. Pike reports what a project's Terraform needs, and CI compares it with the apply role.
2. If something is missing, or an apply fails with `AccessDenied`, a CI job gives an agent the evidence.
3. The agent opens a PR here. It holds no AWS credentials and cannot merge.
4. A person reviews and merges; the normal pipeline applies.

CI logs and PR text are untrusted input to that agent, which is why it cannot act on anything itself. SCPs bound what even a bad merge can grant.

## AI

Bedrock is a regional API in every account, not something deployed once. Three things are easy to confuse:

| Thing | Where it lives |
|-------|----------------|
| Inference | The account of the role calling it, which also pays for it |
| Agent runtimes | The account of the project they belong to |
| Agent Registry | One central account, as a catalog pointing at runtimes elsewhere |

The permissions agent gets its own role, `ci-agent`, limited to invoking one inference profile. For now it sits in `workloads`; a `shared-services` account is the natural home once one exists.

Cross-Region inference fails if an SCP blocks any destination Region, so `bedrock_regions` must list them all. Global inference profiles are not allowed by this policy.
