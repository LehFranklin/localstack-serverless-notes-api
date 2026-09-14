# The REST API itself
resource "aws_api_gateway_rest_api" "notes_api" {
  name = "notes-api"
}

# A single resource path: /notes
resource "aws_api_gateway_resource" "notes" {
  rest_api_id = aws_api_gateway_rest_api.notes_api.id
  parent_id   = aws_api_gateway_rest_api.notes_api.root_resource_id
  path_part   = "notes"
}

# ANY method on /notes -- lets our single Lambda handle GET and POST itself,
# based on the httpMethod field it already checks internally.
resource "aws_api_gateway_method" "notes_any" {
  rest_api_id   = aws_api_gateway_rest_api.notes_api.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Connect that method to the Lambda function (Lambda proxy integration --
# API Gateway forwards the raw request and expects the raw response shape
# our handler.py already returns).
resource "aws_api_gateway_integration" "notes_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.notes_api.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.notes_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.notes_api.invoke_arn
}

# Grant API Gateway permission to actually invoke the Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notes_api.function_name
  principal     = "apigateway.amazonaws.com"
}

# Deploy the API so it's actually reachable at a URL
resource "aws_api_gateway_deployment" "notes_api" {
  rest_api_id = aws_api_gateway_rest_api.notes_api.id

  depends_on = [aws_api_gateway_integration.notes_lambda]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.notes.id,
      aws_api_gateway_method.notes_any.id,
      aws_api_gateway_integration.notes_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.notes_api.id
  rest_api_id   = aws_api_gateway_rest_api.notes_api.id
  stage_name    = "dev"
}

output "api_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.notes_api.id}/dev/_user_request_/notes"
}