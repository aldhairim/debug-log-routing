resource "aws_s3_bucket" "athena_logs" {
  bucket = var.athena_logs_bucket
}

resource "aws_s3_bucket" "loki_oss" {
  bucket = var.loki_oss_bucket
}

resource "aws_s3_bucket" "athena_query_results" {
  bucket = var.athena_query_results_bucket
}
