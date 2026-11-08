# Bootstrap user policy

`tf-bootstrap.json` is an example permissions policy for the identity that runs bootstrap locally. It covers browser login, the two state buckets, the GitHub OIDC provider and these roles:

- `role-terraform-github-actions-dev`
- `role-terraform-github-actions-prod`

## Customize and attach

1. Replace every `123456789012` account ID with your AWS account ID.
2. Replace the example bucket names with the exact names in your local `terraform.tfvars`.
3. If you change the role names in `stack/github-roles.tf`, update their ARNs in this policy too.
4. Using an existing authorized administrator, create a customer-managed policy from this JSON and attach it to the IAM group or role used by your local bootstrap identity.

For the IAM-user login path, create the user with console access and MFA and add it to that group. The included sign-in permissions support same-computer browser login in the two example regions:

```bash
aws login --profile terraform-bootstrap --region us-west-2
aws sts get-caller-identity --profile terraform-bootstrap
```

If you already use an SSO or assumed-role profile, retain your authentication method and ensure its permissions cover the resources in this policy. Bootstrap does not create the identity it needs for its first run.

## What the policy permits

Bucket creation is limited to the two names and their regions. `us-west-2` requires that location constraint; an S3 create request for `us-east-1` omits it. Bucket read actions include configuration that the AWS provider inspects during refresh. Changing regions requires updating these conditions and the sign-in ARNs as needed.

IAM permissions cover only GitHub's OIDC provider in your account and the two named deployment roles. The roles' own backend permissions are defined separately in `stack/github-roles.tf`. No companion permissions boundary is required; this policy does not make role creation conditional on one.

The bootstrap identity does not receive direct state-object read/write/delete permission through this policy. Its state stays local. Emptying a populated versioned bucket during teardown needs separate object-deletion permission.

Editing the JSON does not update a policy in AWS automatically. After later edits, update the policy attached to your bootstrap identity before running Terraform.

References: [AWS CLI browser login](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html), [S3 actions](https://docs.aws.amazon.com/service-authorization/latest/reference/list_s3.html), [IAM actions](https://docs.aws.amazon.com/service-authorization/latest/reference/list_iam.html).
