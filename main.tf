provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

terraform {
  backend "s3" {}
}

locals {
  temp_file_lambda = "${var.temp_file_lambda == "" ? "${path.module}/StartEC2Instances.py.tpl" : var.temp_file_lambda }"
}

///////////////////////
//        iam        //
///////////////////////
module "iam_role" {
  source = "git::https:/github.com/thanhbn87/terraform-aws-iam-role.git?ref=tags/0.1.2"

  name        = "${var.name}"
  namespace   = "${var.namespace}"
  project_env = "${var.project_env}"
  project_env_short = "${var.project_env_short}"

  temp_file_assumerole       = "${var.temp_file_assumerole}"
  temp_file_policy           = "${var.temp_file_policy}"
  identifiers                = ["lambda.amazonaws.com"]
  inline_policy_name         = "${var.inline_policy_name}"

  tags = "${var.tags}" 
}

///////////////////////
//      template     //
///////////////////////
data "template_file" "lambda_function" {
  template = "${file(local.temp_file_lambda)}"
  vars {
    region    = "${var.aws_region}"
    resources = "${jsonencode(var.lambda_resources)}"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/${var.file_name}.zip"

  source {
    content  = "${data.template_file.lambda_function.rendered}"
    filename = "${var.file_name}"
  }
}

///////////////////////
//      lambda       //
///////////////////////
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = "{var.cloudwatch_log_retention_days}"
}
 
resource "aws_lambda_function" "this" {
  function_name    = "${var.function_name}"
  filename         = "${data.archive_file.lambda_zip.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  
  role    = "${module.iam_role.arn}"
  handler = "${var.handler}"
  runtime = "${var.runtime}"

  depends_on = ["aws_cloudwatch_log_group.lambda","data.archive_file.lambda_zip"]
}
