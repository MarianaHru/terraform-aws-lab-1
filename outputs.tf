output "dynamodb_table_name" {
  value = module.dynamodb_table.table_name
}

output "lambda_functions" {
  value = [for f in aws_lambda_function.course_api : f.function_name]
}