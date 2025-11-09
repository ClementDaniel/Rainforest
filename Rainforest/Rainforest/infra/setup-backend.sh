#!/bin/bash
set -e

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="${TF_STATE_BUCKET:-rainforest-tfstate}"
LOCK_TABLE="rainforest-terraform-locks"

# Create S3 bucket if not exists
if ! aws s3 ls "s3://${STATE_BUCKET}" >/dev/null 2>&1; then
  CREATE_ARGS=(--bucket "${STATE_BUCKET}" --region "${AWS_REGION}")
  [[ "${AWS_REGION}" != "us-east-1" ]] && CREATE_ARGS+=(--create-bucket-configuration LocationConstraint="${AWS_REGION}")
  aws s3api create-bucket "${CREATE_ARGS[@]}"
fi

# Secure S3 bucket
aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled \
  --region "${AWS_REGION}"

aws s3api put-bucket-encryption \
  --bucket "${STATE_BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region "${AWS_REGION}"

aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' \
  --region "${AWS_REGION}"

aws s3api put-bucket-policy \
  --bucket "${STATE_BUCKET}" \
  --policy "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "EnforcedTLS",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": [
      "arn:aws:s3:::${STATE_BUCKET}",
      "arn:aws:s3:::${STATE_BUCKET}/*"
    ],
    "Condition": {"Bool": {"aws:SecureTransport": "false"}}
  }]
}
EOF
)" \
  --region "${AWS_REGION}"

# Create DynamoDB table if not exists
if ! aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}"
  aws dynamodb wait table-exists --table-name "${LOCK_TABLE}" --region "${AWS_REGION}"
fi

aws dynamodb update-continuous-backups \
  --table-name "${LOCK_TABLE}" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region "${AWS_REGION}"

echo "S3 bucket: ${STATE_BUCKET}"
echo "DynamoDB table: ${LOCK_TABLE}"
