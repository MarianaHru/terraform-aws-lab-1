provider "aws" {
  region = "us-east-1"
}

module "label" {
  source    = "cloudposse/label/null"
  version   = "0.25.0"
  namespace = "itstep"
  stage     = "dev"
  name      = "domain1"
}

module "dynamodb_table" {
  source     = "./modules/dynamodb"
  table_name = "${module.label.id}-courses"
  hash_key   = "ID"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${module.label.id}-lambda-role"
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
  name = "CourseDatabaseAccess"
  role = aws_iam_role.lambda_exec.id
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
      Resource = module.dynamodb_table.table_arn
    }]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/index.py"
  output_path = "${path.module}/functions/lambda_function.zip"
}

locals {
  course_functions = ["create", "get", "update", "delete", "list", "notify"]
}

resource "aws_lambda_function" "course_api" {
  for_each      = toset(local.course_functions)
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${module.label.id}-${each.key}-course"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = module.dynamodb_table.table_name
      ACTION     = each.key
    }
  }
}