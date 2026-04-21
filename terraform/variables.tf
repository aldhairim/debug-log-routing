variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "athena_logs_bucket" {
  description = "S3 bucket for raw debug log JSON (Athena approach)"
  type        = string
}

variable "loki_oss_bucket" {
  description = "S3 bucket for Loki OSS chunk storage (Loki OSS approach)"
  type        = string
}

variable "athena_query_results_bucket" {
  description = "S3 bucket for Athena query results"
  type        = string
}

variable "iam_user" {
  description = "IAM username that Alloy and Loki OSS use for S3 access"
  type        = string
}
