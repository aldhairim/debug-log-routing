output "athena_logs_bucket" {
  value = aws_s3_bucket.athena_logs.id
}

output "loki_oss_bucket" {
  value = aws_s3_bucket.loki_oss.id
}

output "athena_query_results_bucket" {
  value = aws_s3_bucket.athena_query_results.id
}

output "athena_table_s3_location" {
  value = "s3://${var.athena_logs_bucket}/logs/debug"
}

output "athena_workgroup" {
  value = aws_athena_workgroup.debug_log_routing.name
}
