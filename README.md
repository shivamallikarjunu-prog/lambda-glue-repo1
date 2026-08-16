# Lambda + Glue + S3 deployment repository

This repository contains a minimal AWS data processing pipeline built with:

- S3 bucket for incoming files
- Lambda function that validates uploaded CSV files
- Glue job that partitions data by city, state, and country
- GitHub Actions workflow using OIDC to deploy to AWS via CloudFormation

## Architecture

1. A CSV file lands in the S3 incoming/ prefix.
2. S3 invokes the Lambda trigger.
3. The Lambda validates the CSV header and required columns: id, name, city, state, country.
4. If valid, the Lambda starts the Glue job.
5. The Glue job reads the CSV and partitions the output by city, state, and country.
6. Output is written to processed paths and summary CSV files are generated.

## Repository structure

- [infrastructure/cloudformation.yaml](infrastructure/cloudformation.yaml) — CloudFormation stack for all AWS resources
- [src/lambda/validate_and_trigger.py](src/lambda/validate_and_trigger.py) — validation Lambda logic
- [src/glue/partition_data.py](src/glue/partition_data.py) — Glue ETL script
- [.github/workflows/deploy.yml](.github/workflows/deploy.yml) — GitHub Actions deployment pipeline
- [scripts/bootstrap_github_oidc.sh](scripts/bootstrap_github_oidc.sh) — creates the GitHub OIDC trust and role for AWS deployment

## Required GitHub secrets

Configure the following repository secrets before pushing to main:

- `AWS_ROLE_TO_ASSUME` — Set to: `arn:aws:iam::344326804965:role/git-role`
- `AWS_ACCOUNT_ID` — Set to: `344326804965`

## OIDC Role Configuration

The GitHub Actions workflow assumes the existing IAM role:

- **Role ARN**: `arn:aws:iam::344326804965:role/git-role`
- **Account ID**: `344326804965`
- **Region**: `us-east-1`

The role must have a trust policy configured to allow GitHub Actions to assume it for this repository and branch.

## CloudFormation deployment

The GitHub Actions workflow uses OIDC and runs:

```bash
aws cloudformation deploy \
  --template-file infrastructure/cloudformation.yaml \
  --stack-name data-platform-stack \
  --parameter-overrides \
    BucketNamePrefix=data-platform \
    GitHubRepo=shivamallikarjunu-prog/lambda-glue-repo1 \
    GitHubBranch=main \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset
```

## Example input CSV

```csv
id,name,city,state,country
1,Alice,New York,NY,USA
2,Bob,Chicago,IL,USA
3,Charlie,Toronto,ON,Canada
```

Upload the file to:

```bash
aws s3 cp sample.csv s3://<your-bucket>/incoming/sample.csv
```

The Lambda validates the file and triggers the Glue job automatically.

## Notes

- The repository uses a single S3 bucket for both input and processing output.
- Glue writes partitioned parquet data under the processed path.
- Summary CSV outputs are produced under processed/city_summary, processed/state_summary, and processed/country_summary.
- You may want to add more restrictive IAM permissions and bucket lifecycle rules before production use.
