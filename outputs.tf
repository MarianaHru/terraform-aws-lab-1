output "dynamodb_tables" {
  value = [
    module.dynamodb_courses.table_name,
    module.dynamodb_authors.table_name,
    module.dynamodb_categories.table_name
  ]
}

output "lambda_functions" {
  value = [for f in aws_lambda_function.api : f.function_name]
}