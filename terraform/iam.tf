data "aws_iam_user" "alloy" {
  user_name = var.iam_user
}

resource "aws_iam_policy" "debug_log_routing" {
  name        = "debug-log-routing"
  description = "S3 write for Alloy (Athena logs), S3 read/write for Loki OSS chunks, Athena query access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AthenaLogsWrite"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "arn:aws:s3:::${var.athena_logs_bucket}/*"
      },
      {
        Sid      = "AthenaLogsBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::${var.athena_logs_bucket}"
      },
      {
        Sid      = "LokiOssObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.loki_oss_bucket}/*"
      },
      {
        Sid      = "LokiOssBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::${var.loki_oss_bucket}"
      },
      {
        Sid    = "AthenaQueryResults"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.athena_query_results_bucket}",
          "arn:aws:s3:::${var.athena_query_results_bucket}/*"
        ]
      },
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListWorkGroups",
          "athena:GetWorkGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:CreatePartition"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "debug_log_routing" {
  user       = data.aws_iam_user.alloy.user_name
  policy_arn = aws_iam_policy.debug_log_routing.arn
}
