output "sns_topic_arn" {
  description = "Topic that receives budget and anomaly alerts. Other alarms in the account can publish here too."
  value       = aws_sns_topic.alerts.arn
}
