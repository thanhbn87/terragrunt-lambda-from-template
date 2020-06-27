#
# Variables
#
variable "namespace" { default = "" }
variable "name" { default = "role" }
variable "project_env" { default = "Production" }
variable "project_env_short" { default = "prd" }

variable "aws_region" { default = "us-east-1" }
variable "aws_profile" { default = "default" }
variable "temp_file_assumerole" { default = "" }
variable "temp_file_policy" { default = "" }
variable "inline_policy_name" { default = "" }

variable "iam_role_name" { default = "" }
variable "temp_file_lambda" { default = "" }
variable "lambda_resources" { default = [] }
variable "file_name" { default = "lambda_function" }
variable "function_name" { default = "lambda_function" }
variable "description" { default = "Lambda Function" }
variable "handler" { default = "lambda_function.lambda_handler" }
variable "runtime" { default = "python3.7" }
variable "timeout" { default = "10" }
variable "lambda_memory_size" { default = "128" }

variable "lambda_vpc" { default = false }
variable "tfstate_bucket" { default = "example-tfstate-bucket" }
variable "tfstate_region" { default = "us-west-2" }
variable "tfstate_profile" { default = "default" }
variable "tfstate_arn" { default = "" }
variable "tfstate_key_vpc" { default = "demo/vpc/terraform.tfstate" }
variable "security_group_tags" { default = {} }
variable "subnet_ids" { default = [] }
variable "security_group_ids" { default = [] }

variable "scheduled_lambda" { default = false }
variable "schedule_name" { default = "Lambda" }
variable "schedule_description" { default = "Lambda Schedule" }
variable "schedule_expression" { default = "cron(33 3 ? * MON-FRI *)" }

variable "cloudwatch_log_retention_days" { default = "14" }

variable tags {
  default = {}
}
