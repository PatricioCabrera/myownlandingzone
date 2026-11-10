# Entra ID federation

Makes Entra ID the identity source for IAM Identity Center. These steps are manual: this repo manages permission sets and assignments, not the identity source.

SAML was configured on 2026-11-09; provisioning is in progress.

## Before starting

- Confirm root sign-in and MFA work on the management account. It is the way back if federation breaks.
- Enable Identity Center in the management account. This is a fresh instance, so it has no users yet.
- The first run happens from management, because nobody can sign in to `identity` yet. Later changes, such as rotating the SCIM token, happen from `identity` once it is the delegated administrator. AWS does not list the identity source among the tasks a delegated administrator cannot do, but I have not confirmed it in practice.
- Check your Entra licence. Sources agree that SAML SSO and per-user provisioning work on Free; group provisioning appears to need P1. This setup assigns a user directly, so it should not need groups.

## Steps

1. In Entra, add the **AWS IAM Identity Center** gallery application.
2. In Identity Center, go to **Settings > Identity source > Change identity source > External identity provider**. Download the service provider metadata.
3. In the Entra app, configure SAML with that metadata and download the federation metadata XML.
4. Upload that XML to Identity Center and confirm the change.
5. In Identity Center, enable automatic provisioning. Copy the SCIM endpoint and the access token. The token is shown once.
6. In **Entra ID > Enterprise apps > AWS IAM Identity Center (successor to AWS single sign-on) > Provisioning**, select **+ New configuration** and enter:

   | Entra field | Identity Center value |
   |-------------|-----------------------|
   | Tenant URL | SCIM endpoint |
   | Secret Token | Access token |

   Test the connection, set a notification email for failures, and set the scope to **Sync only assigned users and groups**.
7. Assign the user who will sign in to AWS to the app, then use **Provision on demand** instead of waiting for the next cycle. That user needs a first name, last name and display name in Entra, or Identity Center rejects it.

No user runs the sync. Entra's provisioning service calls the SCIM endpoint with the token, which belongs to Identity Center, not to a person. Assigning a user to the app only decides who gets copied into Identity Center.

Do not assign the Entra global administrator. One stolen account would then reach both the directory and AWS.

## Things that can lock you out

- **Username:** `TF_VAR_owner_user_name` must match the username provisioned from Entra, or the `identity-center` apply fails to find the user.
- **MFA:** Entra enforces it, not Identity Center. Enable it there before relying on this path.
- **SCIM token:** it expires after a year, and provisioning stops until it is rotated. Create the new token in Identity Center, switch Entra to it, then delete the old one.

## Done when

You sign in through the access portal with your Entra user, and `identity-center` applies cleanly.
