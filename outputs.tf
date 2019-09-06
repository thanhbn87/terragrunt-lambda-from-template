output "arn" {
  description = "The arn of the lambda function"
  value       = "${lambda_function.this.arn}"
}
