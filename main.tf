provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "lab1"
      ManagedBy   = "Terraform"
    }
  }
}


module "base_label" {
  source    = "cloudposse/label/null"
  version   = "0.25.0"
  namespace = "lpnu"
  stage     = "dev"
}


module "dynamodb_courses" {
  source     = "./modules/dynamodb"
  table_name = "courses"
  hash_key   = "id"
  context    = module.base_label.context
}


module "dynamodb_authors" {
  source     = "./modules/dynamodb"
  table_name = "authors"
  hash_key   = "id"
  context    = module.base_label.context
}


module "dynamodb_categories" {
  source     = "./modules/dynamodb"
  table_name = "categories"
  hash_key   = "id"
  context    = module.base_label.context
}


locals {
  api_functions = [
    "delete-course",
    "get-all-authors",
    "get-all-courses",
    "get-course",
    "save-course",
    "update-course"
  ]
}


resource "aws_iam_role" "lambda_exec" {
  for_each = toset(local.api_functions)
  
  
  name = "lpnu-dev-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}


resource "aws_iam_role_policy" "lambda_policy" {
  for_each = toset(local.api_functions)
  
  name = "DatabaseAccess"
  role = aws_iam_role.lambda_exec[each.key].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan"
      ]
      Effect   = "Allow"
      Resource = [
        module.dynamodb_courses.table_arn,
        module.dynamodb_authors.table_arn,
        module.dynamodb_categories.table_arn
      ]
    }]
  })
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/index.py"
  output_path = "${path.module}/functions/lambda_function.zip"
}


resource "aws_lambda_function" "api" {
  for_each      = toset(local.api_functions)
  filename      = data.archive_file.lambda_zip.output_path
  
  
  function_name = "lpnu-dev-${each.key}"
  
  
  role          = aws_iam_role.lambda_exec[each.key].arn
  handler       = "index.handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ACTION                = each.key
      COURSES_TABLE_NAME    = module.dynamodb_courses.table_name
      COURSES_TABLE_ARN     = module.dynamodb_courses.table_arn
      AUTHORS_TABLE_NAME    = module.dynamodb_authors.table_name
      AUTHORS_TABLE_ARN     = module.dynamodb_authors.table_arn
      CATEGORIES_TABLE_NAME = module.dynamodb_categories.table_name
      CATEGORIES_TABLE_ARN  = module.dynamodb_categories.table_arn
    }
  }
}