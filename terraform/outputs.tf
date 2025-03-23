output eventbridge_rules {
  value       = module.eventbridge.eventbridge_rule_arns
}

output "sns_topic_arn" {
  value = aws_sns_topic.lambda_dollar_notifications.arn
}

output prod_function_url {
  value       = aws_lambda_function_url.prod_alias_url.function_url
  value       = aws_lambda_function_url.dev_alias_url.function_url
}
