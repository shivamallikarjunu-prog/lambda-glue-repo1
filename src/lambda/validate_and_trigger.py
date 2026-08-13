import csv
import io
import os

import boto3
from urllib.parse import unquote_plus

s3_client = boto3.client("s3")
glue_client = boto3.client("glue")

REQUIRED_COLUMNS = ["id", "name", "city", "state", "country"]


def lambda_handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])

        if not key.startswith("incoming/"):
            continue

        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response["Body"].read().decode("utf-8", errors="replace")

        if not content.strip():
            return {"statusCode": 400, "message": "Uploaded file is empty."}

        reader = csv.DictReader(io.StringIO(content))
        if reader.fieldnames is None:
            return {"statusCode": 400, "message": "CSV file has no header row."}

        normalized_headers = [header.strip().lower() for header in reader.fieldnames]
        missing = [column for column in REQUIRED_COLUMNS if column not in normalized_headers]

        if missing:
            return {
                "statusCode": 400,
                "message": f"Missing required columns: {missing}",
                "foundColumns": normalized_headers,
            }

        job_name = os.environ["GLUE_JOB_NAME"]
        glue_client.start_job_run(JobName=job_name)
        return {
            "statusCode": 200,
            "message": "Validation passed and Glue job started.",
            "jobName": job_name,
        }

    return {"statusCode": 200, "message": "No S3 records processed."}
