#!/bin/bash
# Pre-terraform cleanup for Secrets Manager
SECRET_NAME="ec2-ssh-private-key"

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