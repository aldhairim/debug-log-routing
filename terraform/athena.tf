resource "aws_glue_catalog_database" "countdown_logs" {
  name = "countdown_logs"
}

resource "aws_glue_catalog_table" "debug_logs" {
  name          = "debug_logs"
  database_name = aws_glue_catalog_database.countdown_logs.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL             = "TRUE"
    has_encrypted_data   = "false"
  }

  storage_descriptor {
    location      = "s3://${var.athena_logs_bucket}/logs/debug"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.IgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format"  = "1"
        "ignore.malformed.json" = "true"
      }
    }

    # Serilog compact JSON fields
    columns { name = "@t";                    type = "string" }
    columns { name = "@mt";                   type = "string" }
    columns { name = "@l";                    type = "string" }
    columns { name = "@tr";                   type = "string" }
    columns { name = "@sp";                   type = "string" }
    columns { name = "level";                 type = "string" }
    columns { name = "deployment_environment"; type = "string" }
    columns { name = "sourcecontext";         type = "string" }
    columns { name = "requestid";             type = "string" }
    columns { name = "requestpath";           type = "string" }
    columns { name = "connectionid";          type = "string" }
    columns { name = "trace_id";              type = "string" }
    columns { name = "span_id";              type = "string" }
    columns { name = "eventid";              type = "struct<Id:int,Name:string>" }
  }

  # Hive-compatible partitioning written by Alloy (year/month/day/hour/minute)
  partition_keys { name = "year";   type = "string" }
  partition_keys { name = "month";  type = "string" }
  partition_keys { name = "day";    type = "string" }
  partition_keys { name = "hour";   type = "string" }
  partition_keys { name = "minute"; type = "string" }
}

resource "aws_athena_workgroup" "debug_log_routing" {
  name = "debug-log-routing"

  configuration {
    result_configuration {
      output_location = "s3://${var.athena_query_results_bucket}/"
    }
  }
}
