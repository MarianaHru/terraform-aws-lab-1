resource "aws_api_gateway_rest_api" "api" {
  name        = "${module.base_label.id}-api"
  description = "API Gateway for Serverless Application"
}

resource "aws_api_gateway_resource" "authors" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "authors"
}

resource "aws_api_gateway_resource" "courses" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "courses"
}

resource "aws_api_gateway_resource" "course_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.courses.id
  path_part   = "{id}"
}

resource "aws_api_gateway_model" "course_model" {
  rest_api_id  = aws_api_gateway_rest_api.api.id
  name         = "CourseInputModel"
  content_type = "application/json"
  schema = jsonencode({
    "$schema"  = "http://json-schema.org/schema#"
    title      = "CourseInputModel"
    type       = "object"
    properties = {
      title    = { type = "string" }
      authorId = { type = "string" }
      length   = { type = "string" }
      category = { type = "string" }
    }
    required = ["title", "authorId", "length", "category"]
  })
}

resource "aws_api_gateway_request_validator" "body" {
  name                        = "ValidateBody"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = false
}

locals {
  template_id_only = <<EOF
{
  "id": "$input.params('id')"
}
EOF

  template_put = <<EOF
{
  "id": "$input.params('id')",
  "title" : $input.json('$.title'),
  "authorId" : $input.json('$.authorId'),
  "length" : $input.json('$.length'),
  "category" : $input.json('$.category'),
  "watchHref" : $input.json('$.watchHref')
}
EOF

  endpoints = {
    "get_authors"      = { res_id = aws_api_gateway_resource.authors.id,   method = "GET",    lambda = "get-all-authors", validator = null, model = null, template = null }
    "get_courses"      = { res_id = aws_api_gateway_resource.courses.id,   method = "GET",    lambda = "get-all-courses", validator = null, model = null, template = null }
    "post_courses"     = { res_id = aws_api_gateway_resource.courses.id,   method = "POST",   lambda = "save-course",     validator = aws_api_gateway_request_validator.body.id, model = aws_api_gateway_model.course_model.name, template = null }
    "get_course_id"    = { res_id = aws_api_gateway_resource.course_id.id, method = "GET",    lambda = "get-course",      validator = null, model = null, template = local.template_id_only }
    "delete_course_id" = { res_id = aws_api_gateway_resource.course_id.id, method = "DELETE", lambda = "delete-course",   validator = null, model = null, template = local.template_id_only }
    "put_course_id"    = { res_id = aws_api_gateway_resource.course_id.id, method = "PUT",    lambda = "update-course",   validator = null, model = null, template = local.template_put }
  }
}

resource "aws_api_gateway_method" "methods" {
  for_each             = local.endpoints
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = each.value.res_id
  http_method          = each.value.method
  authorization        = "NONE"
  request_validator_id = each.value.validator
  request_models       = each.value.model != null ? { "application/json" = each.value.model } : {}
}
resource "aws_api_gateway_integration" "integrations" {
  for_each                = local.endpoints
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value.res_id
  http_method             = aws_api_gateway_method.methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.api[each.value.lambda].invoke_arn

  request_templates = each.value.template != null ? { "application/json" = each.value.template } : null
}

resource "aws_api_gateway_method_response" "responses_200" {
  for_each    = local.endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.res_id
  http_method = aws_api_gateway_method.methods[each.key].http_method
  status_code = "200"
  response_models = { "application/json" = "Empty" }
  response_parameters = { "method.response.header.Access-Control-Allow-Origin" = true }
}

resource "aws_api_gateway_integration_response" "integration_responses_200" {
  for_each    = local.endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.res_id
  http_method = aws_api_gateway_method.methods[each.key].http_method
  status_code = aws_api_gateway_method_response.responses_200[each.key].status_code
  depends_on  = [aws_api_gateway_integration.integrations]
  response_parameters = { "method.response.header.Access-Control-Allow-Origin" = "'*'" }
}

locals {
  api_resources = {
    "authors"    = aws_api_gateway_resource.authors.id
    "courses"    = aws_api_gateway_resource.courses.id
    "courses_id" = aws_api_gateway_resource.course_id.id
  }
}

resource "aws_api_gateway_method" "options" {
  for_each      = local.api_resources
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each          = local.api_resources
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = each.value
  http_method       = aws_api_gateway_method.options[each.key].http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "options" {
  for_each    = local.api_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"
  response_models = { "application/json" = "Empty" }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each    = local.api_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = aws_api_gateway_method_response.options[each.key].status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "apigw" {
  for_each      = local.lambdas
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.authors.id,
      aws_api_gateway_resource.courses.id,
      aws_api_gateway_resource.course_id.id,
      aws_api_gateway_method.methods,
      aws_api_gateway_integration.integrations,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.integrations,
    aws_api_gateway_integration.options
  ]
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.api_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "v1"
}

output "api_base_url" {
  value = aws_api_gateway_stage.v1.invoke_url
}