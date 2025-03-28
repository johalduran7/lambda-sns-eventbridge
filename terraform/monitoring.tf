resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_sns_dollar.function_name}" # Use the log group name of your Lambda function
  retention_in_days = 1
}
