# to trigger asynchronously: $ aws lambda invoke --function-name lambda_sns_dollar --invocation-type Event response.json
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_sns_dollar_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "lambda_logs_policy"
  description = "Policy to allow Lambda to filter and query log events"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery"
        ],
        Resource = [
          "arn:aws:logs:us-east-1:948586925757:log-group:/aws/lambda/lambda_sns_dollar:*"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# Allow Lambda to publish to SNS topic
resource "aws_iam_role_policy_attachment" "lambda_SNS_execution_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkRoleSNS"
  
}

# Allow Lambda to write to CW
resource "aws_iam_role_policy_attachment" "lambda_CW_execution_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



# using the same function as the other module. It doesn't really matter
resource "aws_lambda_function" "lambda_sns_dollar" {
  function_name = "lambda_sns_dollar"
  handler       = "modules/lambda/lambda_sns_dollar/lambda_function.lambda_handler" # Python handler
  runtime       = "python3.9"                                     # Specify the Python runtime version
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 10
#   dead_letter_config {
#     target_arn="${aws_sqs_queue.dlq_queue.arn}"
#   }
  source_code_hash = filebase64sha256("modules/lambda/lambda_sns_dollar/lambda_function.zip")

  # Specify the S3 bucket and object if you upload the ZIP file to S3, or use the `filename` attribute for local deployment
  filename = "modules/lambda/lambda_sns_dollar/lambda_function.zip" # Path to your ZIP file

  environment {
    variables = {
      url = "https://script.google.com/macros/s/AKfycbxoDsLKnhaaQ8kcFz7DApoi7E9VEIZEHcqeMZRAVRPGxi1YNdcI0izmHdzxOIGgbbM/exec"
      sns_arn = "${aws_sns_topic.lambda_dollar_notifications.arn}"
    }
  }

  reserved_concurrent_executions=10
  publish= true # whenever I want to publish a new version

}

# zip modules/lambda/lambda_sns_dollar/lambda_function.zip modules/lambda/lambda_sns_dollar/lambda_function.py

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_sns_dollar.function_name}"  # Use the log group name of your Lambda function
  retention_in_days = 1
}

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



# Create event bridge to trigger Lambda
module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    crons = {
      description         = "Trigger for a Lambda"
      schedule_expression = "cron(0 15-23/3,0 * * ? *)" # from 10 AM ET to 7 PM. This is in GMT-0
    }
  }

  targets = {
    crons = [
      {
        name  = "lambda-loves-cron"
        arn   = "${aws_lambda_alias.prod_lambda_alias.arn}"
        input = jsonencode({"job": "cron-by-rate"})
      }
    ]
  }
  tags = {
    Name = "lambda_rule"
    Terraform = "yes"
  }
}

output eventbridge_rules {
  value       = module.eventbridge.eventbridge_rule_arns
}


# Allow and add eventbridge as a trigger for lambda
resource "aws_lambda_permission" "eventbridge_resource_based_policy_permission" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.prod_lambda_alias.arn
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_rule_arns.crons
}



# Create an SNS Topic
resource "aws_sns_topic" "lambda_dollar_notifications" {
  name = "lambda_dollar_notifications"
  tags = {
    Terraform = "yes"
  }
}

# SNS Topic Policy to allow Lambda to publish to SNS
resource "aws_sns_topic_policy" "lambda_dollar_notifications_policy" {
  arn = aws_sns_topic.lambda_dollar_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action    = "SNS:Publish",
        Resource  = aws_sns_topic.lambda_dollar_notifications.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = [
              aws_lambda_function.lambda_sns_dollar.arn
              #,
              #aws_lambda_alias.prod_lambda_alias.arn
              ]
          }
        }
      }
    ]
  })
}


# Create an SNS Subscription for your email
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.lambda_dollar_notifications.arn
  protocol  = "email"
  endpoint  = "johalduran@gmail.com" # Replace with your email address
}


output "sns_topic_arn" {
  value = aws_sns_topic.lambda_dollar_notifications.arn
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


# DynamoDB Table to store the price of dollar


resource "aws_dynamodb_table" "price_dollar" {
  name           = "price_dollar"
  billing_mode   = "PAY_PER_REQUEST" # On-demand billing mode
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S" # S = String; change to "N" for Number if required
  }



  tags = {
    Environment = "Production"
    Project     = "dollar_sns"
    Terraform   = "yes"
  }
}

# Adding the first row. I don't Need to add the first row anymore, I'm handling this in the lambda function directly
# resource "aws_dynamodb_table_item" "price_dollar_first_row" {
#   table_name = aws_dynamodb_table.price_dollar.name
#   hash_key   = aws_dynamodb_table.price_dollar.hash_key

#   item = <<ITEM
# {
#   "id": {"S": "1"},
#   "price": {"S": "4140"}
# }
# ITEM
# }


resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "DynamoDB policy for lambda"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:DeleteTable",
          "dynamodb:CreateTable",
          "dynamodb:UpdateTable",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ],
        Resource = [
          "arn:aws:dynamodb:us-east-1:948586925757:table/price_dollar"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
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
