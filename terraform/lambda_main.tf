# To trigger asynchronously: $ aws lambda invoke --function-name lambda_sns_dollar --invocation-type Event response.json

# using the same function as the other module. It doesn't really matter
resource "aws_lambda_function" "lambda_sns_dollar" {
  function_name = "lambda_sns_dollar"
  handler       = "lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                                       # Specify the Python runtime version
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 10
  #   dead_letter_config {
  #     target_arn="${aws_sqs_queue.dlq_queue.arn}"
  #   }
  source_code_hash = filebase64sha256("lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "lambda_function.zip" # Path to your ZIP file

  environment {
    variables = {
      url     = "https://script.google.com/macros/s/AKfycbxoDsLKnhaaQ8kcFz7DApoi7E9VEIZEHcqeMZRAVRPGxi1YNdcI0izmHdzxOIGgbbM/exec"
      sns_arn = "${aws_sns_topic.lambda_dollar_notifications.arn}"
    }
  }

  reserved_concurrent_executions = 10
  publish                        = true # whenever I want to publish a new version

}

# cd ./terraform
# zip lambda_function.zip lambda_function.py


# Creating the Dev Alias for my lambda function
resource "aws_lambda_alias" "dev_lambda_alias" {
  name             = "Dev"
  description      = "Development Version where additional changes are going to be added first"
  function_name    = aws_lambda_function.lambda_sns_dollar.arn
  function_version = "$LATEST"

  # routing_config {
  #   additional_version_weights = {
  #     "2" = 0.5
  #   }
  # }
}



resource "aws_lambda_alias" "prod_lambda_alias" {
  name             = "Prod"
  description      = "Actual lambda version to use"
  function_name    = aws_lambda_function.lambda_sns_dollar.arn
  function_version = aws_lambda_function.lambda_sns_dollar.version

  # routing_config {
  #   additional_version_weights = {
  #     "2" = 0.5
  #   }
  # }
}


# Allow and add eventbridge as a trigger for lambda
resource "aws_lambda_permission" "eventbridge_resource_based_policy_permission" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.prod_lambda_alias.arn
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns.crons
}


# Add SNS as a destination on failure and success. As an alternative I'm sending the notification directly in the lambda function, this is to be able to customize the email notification
resource "aws_lambda_function_event_invoke_config" "lambda_sns_destination" {
  function_name = aws_lambda_alias.prod_lambda_alias.arn #aws_lambda_function.lambda_sns_dollar.function_name #name or ARN

  destination_config {
    # on_success {
    #   destination = aws_sns_topic.lambda_dollar_notifications.arn
    # }
    on_failure {
      destination = aws_sns_topic.lambda_dollar_notifications.arn
    }
  }
}

# Create the URL for the production Alias
resource "aws_lambda_function_url" "prod_alias_url" {
  function_name      = aws_lambda_function.lambda_sns_dollar.function_name
  qualifier          = aws_lambda_alias.prod_lambda_alias.name
  authorization_type = "NONE"
}

# Create the URL for the production Alias
resource "aws_lambda_function_url" "dev_alias_url" {
  function_name      = aws_lambda_function.lambda_sns_dollar.function_name
  qualifier          = aws_lambda_alias.dev_lambda_alias.name
  authorization_type = "NONE"
}
