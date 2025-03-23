
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
  policy = jsonencode({
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

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "DynamoDB policy for lambda"
  policy = jsonencode({
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


resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}



# SNS Topic Policy to allow Lambda to publish to SNS
resource "aws_sns_topic_policy" "lambda_dollar_notifications_policy" {
  arn = aws_sns_topic.lambda_dollar_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.lambda_dollar_notifications.arn,
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



