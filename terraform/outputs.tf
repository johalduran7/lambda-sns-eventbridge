output eventbridge_rules {
  value       = module.eventbridge.eventbridge_rule_arns
}

output "sns_topic_arn" {
  value = aws_sns_topic.lambda_dollar_notifications.arn
}
