#!/bin/bash
set -e

REGION="ap-southeast-2"
BUCKET="infra-terraform-state-20250910" # UPDATE THIS (must be globally unique)
ROLE_NAME="GitHubActionsTerraformRole"
OIDC_PROVIDER_URL="token.actions.githubusercontent.com"
OIDC_PROVIDER_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/${OIDC_PROVIDER_URL}"
REPO="marcolw/infra_engineer_challenge" # CHANGE THIS (GitHub org/repo)
BRANCH="main"          


aws s3api create-bucket \
  --bucket $BUCKET \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

echo "S3 bucket created for Terraform remote backend."

# Create OIDC provider if not exists
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1; then
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_PROVIDER_URL}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
  echo " OIDC provider created."
else
  echo " OIDC provider already exists."
fi

# Create IAM trust policy for GitHub Actions
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER_URL}:sub": "repo:${REPO}:ref:refs/heads/${BRANCH}"
        }
      }
    }
  ]
}
EOF
)

#  Create IAM role 
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY"

#  Attach policy for Terraform operations (need to update for least privillege)
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo "IAM role $ROLE_NAME created and ready for GitHub Actions."

echo "Update your GitHub Actions workflow to use role: arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/${ROLE_NAME}"