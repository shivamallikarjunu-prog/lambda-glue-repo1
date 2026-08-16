#!/usr/bin/env bash
set -euo pipefail

# Fix OIDC Trust Policy for Existing GitHub Actions Role
# This script updates an existing role with the correct OIDC trust policy

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-344326804965}"
GITHUB_REPO="${GITHUB_REPO:-shivamallikarjunu-prog/lambda-glue-repo1}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
ROLE_NAME="${ROLE_NAME:-git-role}"

echo "================================"
echo "Fixing OIDC Trust Policy"
echo "================================"
echo "Account ID: $AWS_ACCOUNT_ID"
echo "GitHub Repo: $GITHUB_REPO"
echo "Branch: $GITHUB_BRANCH"
echo "Role Name: $ROLE_NAME"
echo ""

# Step 1: Ensure OIDC Provider exists
echo "Step 1: Checking OIDC Provider..."
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1; then
  echo "✓ OIDC Provider already exists"
else
  echo "✗ Creating OIDC Provider..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97c6bdb9c4b7637fa9a2 \
    --tags 'Key=Purpose,Value=GitHubOIDC' 'Key=Repository,Value='$GITHUB_REPO
  echo "✓ OIDC Provider created successfully"
fi

# Step 2: Create the correct trust policy
echo ""
echo "Step 2: Creating correct trust policy..."
cat > /tmp/github-oidc-trust-policy.json <<EOF
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}"
        }
      }
    }
  ]
}
EOF

# Step 3: Update the role's trust policy
echo "Step 3: Updating role trust policy..."
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "✓ Role exists: $ROLE_NAME"
  
  # Update the trust policy
  aws iam update-assume-role-policy-document \
    --role-name "$ROLE_NAME" \
    --policy-document file:///tmp/github-oidc-trust-policy.json
  
  echo "✓ Trust policy updated successfully"
else
  echo "✗ Role does not exist: $ROLE_NAME"
  echo "Creating role with correct trust policy..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/github-oidc-trust-policy.json \
    --tags 'Key=Purpose,Value=GitHubOIDC' 'Key=Repository,Value='$GITHUB_REPO
  echo "✓ Role created successfully"
fi

# Step 4: Ensure role has necessary permissions
echo ""
echo "Step 4: Setting inline policy for CloudFormation deployment..."
aws iam put-role-inline-policy \
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
          "iam:GetRole",
          "iam:CreateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy",
          "logs:*",
          "ec2:*"
        ],
        "Resource": "*"
      }
    ]
  }'
echo "✓ Inline policy updated"

# Step 5: Verify the setup
echo ""
echo "Step 5: Verifying setup..."
echo "Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "Trust policy (should reference your repo and branch):"
aws iam get-role --role-name "$ROLE_NAME" | jq '.Role.AssumeRolePolicyDocument'

echo ""
echo "================================"
echo "✓ OIDC Trust Policy Setup Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Set AWS_ROLE_TO_ASSUME secret in GitHub to: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "2. Trigger the workflow again"
echo ""
