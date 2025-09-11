#!/usr/bin/env bash
KEY_NAME=$1

AWS_OUTPUT=$(aws ec2 describe-key-pairs --key-names "$KEY_NAME" --output json 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo '{"exists":"true"}'
else
  if echo "$AWS_OUTPUT" | grep -q "InvalidKeyPair.NotFound"; then
    echo '{"exists":"false"}'
  else
    echo "Error checking keypair: $AWS_OUTPUT" >&2
    echo '{"exists":"false"}'
  fi
fi