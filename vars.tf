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

variable "temp_file_lambda" { default = "" }
variable "lambda_resources" { default = [] }
variable "file_name" { default = "lambda_function" }
variable "function_name" { default = "lambda_function" }
variable "handler" { default = "lambda_function.lambda_handler" }
variable "runtime" { default = "python3.7" }

variable tags {
  default = {}
}