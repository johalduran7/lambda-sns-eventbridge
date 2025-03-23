# Create an SNS Topic
resource "aws_sns_topic" "lambda_dollar_notifications" {
  name = "lambda_dollar_notifications"
  tags = {
    Terraform = "yes"
  }
}


# Create an SNS Subscription for your email
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.lambda_dollar_notifications.arn
  protocol  = "email"
  endpoint  = "johalduran@gmail.com" # Replace with your email address
}

