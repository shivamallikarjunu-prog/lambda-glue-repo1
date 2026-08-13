import sys

from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext

args = getResolvedOptions(sys.argv, ["JOB_NAME", "input_s3_path", "output_s3_path"])

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session

input_path = args["input_s3_path"]
output_path = args["output_s3_path"]

df = spark.read.option("header", "true").option("inferSchema", "true").csv(input_path)
required_columns = ["id", "name", "city", "state", "country"]
missing_columns = [column for column in required_columns if column not in df.columns]

if missing_columns:
    raise ValueError(f"Missing required columns: {missing_columns}")

df = df.select(*required_columns)
df = df.na.drop(subset=required_columns)

# Partition the data by city, state and country.
df.write.mode("overwrite").partitionBy("city", "state", "country").parquet(output_path + "/partitioned-data/")

# Produce three summary files in S3.
city_summary = df.groupBy("city").count().orderBy("city")
state_summary = df.groupBy("state").count().orderBy("state")
country_summary = df.groupBy("country").count().orderBy("country")

city_summary.write.mode("overwrite").csv(output_path + "/city_summary/")
state_summary.write.mode("overwrite").csv(output_path + "/state_summary/")
country_summary.write.mode("overwrite").csv(output_path + "/country_summary/")
