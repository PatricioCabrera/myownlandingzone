# Bootstrap

Replaces the current organization with one defined here.

| Account | ID | Role |
|---------|----|------|
| `management` | `<management-id>` | Organization, billing, SCPs. Only people sign in; nothing runs here. |
| `identity` | `<identity-id>` | Delegated administrator for Identity Center: users, permission sets, assignments |
| `workloads` | `<workloads-id>` | The current account, invited in step 8. CloudLaunchpad stays where it is. |

The IDs live in `.env`, not in this repo. Copy `.env.example` to `.env`, fill it in, and load it before any `atmos` command:

```bash
set -a; source .env; set +a
```

Steps 4 to 7 ran on 2026-11-09. Steps 2 and 3 are destructive and cannot be undone. No resources in `<workloads-id>` are deleted, but its Identity Center users, permission sets and assignments are.

## 1. Prepare

- Confirm root sign-in and MFA on `<management-id>` and on `<workloads-id>`. After step 2, root is the only way into `<workloads-id>`.
- While `aws sso login` still works, remove the two empty state objects a test plan left behind:

  ```bash
  aws s3 rm s3://tfstate-<workloads-id>-us-east-1-an/myownlandingzone/ --recursive
  ```

- Know what stops working at step 2: the `default` SSO profile and `aws sso login`. CloudLaunchpad's CI keeps working, because GitHub OIDC is plain IAM.
- Choose a root email for `identity` that no AWS account uses yet, such as a `+aws-identity` alias.
- Change the root email of `<workloads-id>` from its `+aws-management` alias to something like `+aws-workloads`, in its account settings, as root. Do it before step 8: once it joins, root is denied there.

## 2. Delete Identity Center in `<workloads-id>`

As root, in the console: **IAM Identity Center > Settings > Management > Delete**.

## 3. Delete the current organization

As root, in the console: **AWS Organizations > Settings > Delete organization**. The account keeps its resources and becomes standalone.

## 4. Create the management state bucket

As root of `<management-id>`, with console credentials:

```bash
aws configure set region us-east-1 --profile management
aws login --profile management
aws sts get-caller-identity --profile management   # must print <management-id>
atmos terraform apply tfstate -s management
```

`tfstate` uses a local backend, because the bucket cannot hold its own state before it exists. Back that file up outside the repo.

Every stack sets `account_id`, and the provider refuses credentials from any other account. State buckets use the account-regional namespace (`<prefix>-<account>-<region>-an`), so S3 also rejects a bucket created from the wrong account.

## 5. Create the organization and the identity account

In `stacks/catalog/organization.yaml`, comment out `workloads` under `accounts` and the `delegated_administrators` block for this first apply. `workloads` joins by invitation in step 8, and delegation needs Identity Center, which does not exist yet.

```bash
export TF_VAR_account_emails='{"identity":"<identity root email>"}'
atmos terraform apply organization -s management
```

This creates the organization, both OUs, the `identity` account and the SCPs. AWS creates `OrganizationAccountAccessRole` in `identity` automatically.

Copy the new account ID from `atmos terraform output organization -s management` into `IDENTITY_ACCOUNT_ID` in `.env`, then reload it.

## 6. Enable Identity Center and federate

As root of `<management-id>`, in the console:

1. Enable IAM Identity Center in `us-east-1`. Terraform cannot do this in a management account.
2. Follow [Entra ID federation](entra-federation.md).

The first identity source change happens here, because nobody can sign in to `identity` yet. Later changes, such as rotating the SCIM token, happen from `identity`.

## 7. Delegate Identity Center to `identity`

1. Grant yourself access to `management` and `identity`, through the `PlatformAdmin` permission set:

   ```bash
   export TF_VAR_owner_user_name='<Entra user principal name>'
   atmos terraform apply identity-center -s management
   ```

2. Restore `delegated_administrators` in `stacks/catalog/organization.yaml`, then:

   ```bash
   atmos terraform apply organization -s management
   ```

   If AWS rejects the registration through the API, register `identity` in the console instead: **IAM Identity Center > Settings > Management > Delegated administrator > Register account**, then delete `delegated_administrators` from the stack.

3. Replace `~/.aws/config` with SSO profiles for the new access portal:

   ```ini
   [sso-session platform]
   sso_start_url = <access portal URL>
   sso_region = us-east-1
   sso_registration_scopes = sso:account:access

   [profile management]
   sso_session = platform
   sso_account_id = <management-id>
   sso_role_name = PlatformAdmin
   region = us-east-1

   [profile identity]
   sso_session = platform
   sso_account_id = <identity-id>
   sso_role_name = PlatformAdmin
   region = us-east-1

   [profile workloads]
   sso_session = platform
   sso_account_id = <workloads-id>
   sso_role_name = AdministratorAccess
   region = us-east-1
   ```

4. From `identity`, create its state bucket and the everyday permission sets:

   ```bash
   aws sso login --sso-session platform
   atmos terraform apply tfstate -s identity
   atmos terraform apply identity-center -s identity
   ```

One `aws sso login` covers every profile: it signs in to the access portal, not to an account. Each stack sets `AWS_PROFILE` in its `env`, so Atmos picks the account, and `allowed_account_ids` stops the run if the profile points elsewhere.

`AdministratorAccess` stays unprovisioned until step 8, because nothing assigns it yet outside `workloads`.

From here on, use root on `<management-id>` only to recover access. Its profile is `management-root`.

## 8. Bring `<workloads-id>` in

1. As root in `<workloads-id>`, create `OrganizationAccountAccessRole`. AWS does not create it for invited accounts, and SCPs at the root take effect the moment the account joins. From then on `baseline` denies the root user, so this role must exist before step 3.

   ```bash
   aws configure set region us-east-1 --profile legacy-root
   aws login --profile legacy-root
   aws iam create-role --profile legacy-root --role-name OrganizationAccountAccessRole \
     --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::<management-id>:root"},"Action":"sts:AssumeRole"}]}'
   aws iam attach-role-policy --profile legacy-root --role-name OrganizationAccountAccessRole \
     --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
   ```

2. Send the invitation:

   ```bash
   aws organizations invite-account-to-organization --target Id=<workloads-id>,Type=ACCOUNT --profile management
   ```

3. Accept it as root in `<workloads-id>`. This is the last thing root can do there.
4. Restore `workloads` under `accounts`, add its root email to `TF_VAR_account_emails`, and add this block to `components/terraform/organization/main.tf`:

   ```hcl
   import {
     to = aws_organizations_account.this["workloads"]
     id = "<workloads-id>"
   }
   ```

5. Apply, then delete the import block. This moves the account into `Workloads`.

   ```bash
   atmos terraform apply organization -s management
   ```

6. Grant everyday access to it, from `identity`:

   ```bash
   atmos terraform apply identity-center -s identity
   ```

7. Rename it, since root is now denied there. Skip this if it was renamed before joining (done for `<workloads-id>` on 2026-11-09):

   ```bash
   aws account put-account-name --account-id <workloads-id> --account-name workloads --profile management
   ```

## 9. Check it

A new management account starts with Cost Explorer off, and member accounts cannot use Budgets or Cost Anomaly Detection until the payer turns it on. CloudLaunchpad's plan fails on both until then. As root of `<management-id>`, in the console:

1. **Account > IAM user and role access to Billing information > Activate**, so `PlatformAdmin` can open Billing.
2. **Billing and Cost Management > Cost Explorer > Launch Cost Explorer**. Data can take 24 hours.
3. **Cost Management preferences**: confirm linked account access is on.
4. **Cost allocation tags**: activate `Project` and `ManagedBy` here. Tags activated in `<workloads-id>` before it joined no longer apply.


- [ ] The access portal shows all three accounts
- [ ] `aws sts get-caller-identity --profile workloads` returns `<workloads-id>`
- [ ] CloudLaunchpad's CI still authenticates
- [ ] Root in `<workloads-id>` is denied, and `OrganizationAccountAccessRole` works from `management`
- [ ] Billing shows `<management-id>` as payer, and CloudLaunchpad's budget still alerts

## Afterwards

- `atmos terraform apply ip-allocations -s workloads`
- `atmos terraform apply budget -s workloads`, with `TF_VAR_notification_email` set. The first apply adopts the budget, anomaly monitor and SNS topic CloudLaunchpad created; delete `components/terraform/budget/imports.tf` after it, then merge CloudLaunchpad's `removed` block. Never destroy CloudLaunchpad between the two.
- CloudLaunchpad keeps its `networking` module and reads its range from `/platform/ip-allocations/cloudlaunchpad/cidr`.
