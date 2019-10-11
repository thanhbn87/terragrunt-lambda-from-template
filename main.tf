provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

terraform {
  backend "s3" {}
}

data "aws_iam_role" "lambda" {
  count = "${var.iam_role_name == "" ? 0 : 1}"
  name  = "${var.iam_role_name}"
}

locals {
  temp_file_lambda = "${var.temp_file_lambda == "" ? "${path.module}/StartEC2Instances.py.tpl" : var.temp_file_lambda }"
  iam_role_enabled = "${var.iam_role_name == "" ? true : false }"
  iam_role_arn     = "${var.iam_role_name == "" ? module.iam_role.arn : element(concat(data.aws_iam_role.lambda.*.arn,list("")),0) }"
  num_sg_tags      = "${length(keys(var.security_group_tags))}"
}

///////////////////////
//        iam        //
///////////////////////
module "iam_role" {
  source = "git::https:/github.com/thanhbn87/terraform-aws-iam-role.git?ref=tags/0.1.3"

  enabled     = "${local.iam_role_enabled}"
  name        = "lambda"
  namespace   = "${var.namespace}"
  project_env = "${var.project_env}"
  project_env_short = "${var.project_env_short}"

  temp_file_assumerole       = "${var.temp_file_assumerole}"
  temp_file_policy           = "${var.temp_file_policy}"
  identifiers                = ["lambda.amazonaws.com"]
  inline_policy_name         = "${var.inline_policy_name}"

  tags = "${var.tags}" 
}

////////////////////////////////////////
//      template and data sources     //
////////////////////////////////////////
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

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    encrypt        = true
    bucket         = "${var.tfstate_bucket}"
    key            = "${var.tfstate_key_vpc}"
    region         = "${var.tfstate_region}"
    profile        = "${var.tfstate_profile}"
    role_arn       = "${var.tfstate_arn}"
  }
}

data "aws_security_groups" "lambda" {
  count = "${local.num_sg_tags > 0 ? 1 : 0}"
  tags  = "${merge(var.security_group_tags,map("Env", "${var.project_env}"))}"

  filter {
    name   = "vpc-id"
    values = ["${data.terraform_remote_state.vpc.vpc_id}"]
  }
}

///////////////////////
//      lambda       //
///////////////////////
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = "${var.cloudwatch_log_retention_days}"
}
 
resource "aws_lambda_function" "this" {
  function_name    = "${var.function_name}"
  description      = "${var.description}"
  filename         = "${data.archive_file.lambda_zip.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  
  role        = "${local.iam_role_arn}"
  handler     = "${var.handler}"
  runtime     = "${var.runtime}"
  timeout     = "${var.timeout}"
  memory_size = "${var.lambda_memory_size}"
  environment = {
    variables = "${var.environment_variables}"
  }

  depends_on = ["aws_cloudwatch_log_group.lambda","data.archive_file.lambda_zip"]
}

///////////////////////
//     lambda_vpc    //
///////////////////////
locals {
  subnet_ids         = [ "${split(",", length(var.subnet_ids) > 0 ? join(",", var.subnet_ids) : join(",", data.terraform_remote_state.vpc.private_subnets) )}" ]
  security_group_ids = [ "${split(",", length(var.security_group_ids) > 0 ? join(",", var.security_group_ids) : join(",", flatten(coalescelist(data.aws_security_groups.lambda.*.ids,list()))) )}" ]
}

resource "aws_lambda_function" "lambda_vpc" {
  count            = "${var.lambda_vpc ? 1 : 0}"
  function_name    = "${var.function_name}"
  description      = "${var.description}"
  filename         = "${data.archive_file.lambda_zip.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"

  role        = "${local.iam_role_arn}"
  handler     = "${var.handler}"
  runtime     = "${var.runtime}"
  timeout     = "${var.timeout}"
  memory_size = "${var.lambda_memory_size}"

  environment = {
    variables = "${var.environment_variables}"
  }

  vpc_config {
    subnet_ids         = ["${local.subnet_ids}"]
    security_group_ids = ["${local.security_group_ids}"]
  }

  depends_on = ["aws_cloudwatch_log_group.lambda","data.archive_file.lambda_zip"]

}

///////////////////////
//      schedule     //
///////////////////////
resource "aws_lambda_permission" "cloudwatch_trigger" {
  count         = "${var.scheduled_lambda ? 1 : 0}"
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${join("", concat(aws_lambda_function.this.*.arn, aws_lambda_function.lambda_vpc.*.arn))}"
  principal     = "events.amazonaws.com"
  source_arn    = "${element(concat(aws_cloudwatch_event_rule.lambda.*.arn,list("")),0)}"
}

resource "aws_cloudwatch_event_rule" "lambda" {
  count               = "${var.scheduled_lambda ? 1 : 0}"
  name                = "${var.schedule_name}"
  description         = "${var.schedule_description}"
  schedule_expression = "${var.schedule_expression}"
}

resource "aws_cloudwatch_event_target" "lambda" {
  count     = "${var.scheduled_lambda ? 1 : 0}"
  target_id = "${var.function_name}"
  rule      = "${element(concat(aws_cloudwatch_event_rule.lambda.*.name,list("")),0)}"
  arn       = "${join("", concat(aws_lambda_function.this.*.arn, aws_lambda_function.lambda_vpc.*.arn))}"
}
