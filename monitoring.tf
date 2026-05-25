resource "aws_sns_topic" "alerts" {
  name = "lpnu-dev-alerts"
}


resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "mariana.hrudzinska.ri.2024@lpnu.ua"
}


resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "aws-billing-alarm-5usd"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "21600" 
  statistic           = "Maximum"
  threshold           = "5.0"   
  alarm_description   = "Тривога! Витрати перевищують $5"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}


resource "aws_cloudwatch_log_metric_filter" "lambda_errors" {
  name           = "LambdaErrorFilter"
  pattern        = "ERROR" 
  
  log_group_name = "/aws/lambda/lpnu-dev-get-all-courses"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "LPNU/LambdaMetrics"
    value     = "1" 
  }
}


resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-get-courses-error-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.lambda_errors.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.lambda_errors.metric_transformation[0].namespace
  period              = "60" 
  statistic           = "Sum"
  threshold           = "1"  
  alarm_description   = "Знайдено помилку в Ламбді get-all-courses!"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}



data "archive_file" "slack_lambda_zip" {
  type        = "zip"
  source_file = "slack_notifier.py"
  output_path = "slack_notifier.zip"
}


resource "aws_iam_role" "slack_lambda_role" {
  name = "lpnu-dev-slack-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "slack_lambda_logs" {
  role       = aws_iam_role.slack_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "slack_notifier" {
  filename      = "slack_notifier.zip"
  function_name = "lpnu-dev-slack-notifier"
  role          = aws_iam_role.slack_lambda_role.arn
  handler       = "slack_notifier.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/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" 
    }
  }
}


resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}


resource "aws_sns_topic_subscription" "slack_lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}