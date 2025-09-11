#!/bin/bash
# run_certbot.sh
# Re-run certbot on EC2 via AWS SSM

# Get instance ID of running instance with the specific tag
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=infra-challenge-webserver" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
  echo "Error: No running EC2 instance found with tag 'infra-challenge-webserver'"
  exit 1
fi

echo "Found running instance: $INSTANCE_ID"

# Send SSM command to run certbot
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --comment "Re-run certbot" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "certbot --nginx -d infra.xeniumsolution.space --non-interactive --agree-tos -m marco.w.liew@gmail.com --redirect"
  ]'

echo "Certbot command sent successfully to instance $INSTANCE_ID"