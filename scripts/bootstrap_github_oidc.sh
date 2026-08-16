#!/usr/bin/env bash
set -euo pipefail

# OIDC Role Configuration for GitHub Actions
# This script validates the existing OIDC role and trust policy
# Role ARN: arn:aws:iam::039473174687:role/GITAWSrole

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-039473174687}"
AWS_REGION="${AWS_REGION:-us-east-1}"
GITHUB_REPO="${GITHUB_REPO:-shivamallikarjunu-prog/lambda-glue-repo1}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
ROLE_NAME="${ROLE_NAME:-GITAWSrole}"

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  echo "Set AWS_ACCOUNT_ID before running this script."
  exit 1
fi

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1 || \
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97c6bdb9c4b7637fa9a2

cat > /tmp/github-actions-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}"
        }
      }
    }
  ]
}
EOF

aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1 || \
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/github-actions-trust-policy.json

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name GitHubActionsDeployPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "cloudformation:*",
          "s3:*",
          "lambda:*",
          "glue:*",
          "iam:PassRole",
          "logs:*"
        ],
        "Resource": "*"
      }
    ]
  }'

echo "Role ARN: ${ROLE_ARN}"
echo "Set this as the GitHub secret AWS_ROLE_TO_ASSUME"
