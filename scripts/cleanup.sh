#!/bin/bash
set -e

REGION="ap-southeast-2"
BUCKET="infra-terraform-state-20250910"
SECRET_NAME="ec2-ssh-private-key"
ROLE_NAME="GitHubActionsTerraformRole"
OIDC_PROVIDER_URL="token.actions.githubusercontent.com"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_URL}"

echo "Starting cleanup of Terraform backend resources in account $ACCOUNT_ID, region $REGION..."

#  Detach IAM policies from role 
echo "Detaching policies from role $ROLE_NAME..."
ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text || true)
if [ -n "$ATTACHED_POLICIES" ]; then
  for POLICY in $ATTACHED_POLICIES; do
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY"
  done
fi

#  Delete IAM role 
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam delete-role --role-name "$ROLE_NAME"
  echo " Deleted IAM role $ROLE_NAME"
else
  echo "Role $ROLE_NAME not found, skipping."
fi

#  Delete OIDC provider 
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1; then
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN"
  echo " Deleted OIDC provider $OIDC_PROVIDER_URL"
else
  echo "OIDC provider not found, skipping."
fi

#  Empty and delete S3 bucket 
if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "Emptying S3 bucket $BUCKET..."
  aws s3 rm s3://$BUCKET --recursive
  echo "Deleting S3 bucket $BUCKET..."
  aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION"
  echo "Deleted S3 bucket $BUCKET"
else
  echo "S3 bucket $BUCKET not found, skipping."
fi

# Check if secret exists and is scheduled for deletion
if aws secretsmanager describe-secret --secret-id $SECRET_NAME 2>/dev/null; then
    echo "Secret exists, checking status..."
    STATUS=$(aws secretsmanager describe-secret --secret-id $SECRET_NAME --query "DeletedDate" --output text)
    
    if [ "$STATUS" != "None" ]; then
        echo "Secret is scheduled for deletion, force deleting..."
        aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery
        sleep 5
    fi
fi

echo "Cleanup completed successfully."