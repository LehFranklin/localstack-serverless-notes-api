# Zip up the Lambda code automatically whenever handler.py changes
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

# The IAM role Lambda assumes when it runs. In real AWS this genuinely
# controls permissions; LocalStack accepts it for realism/parity even
# though it doesn't enforce every permission the way real AWS IAM does.
resource "aws_iam_role" "lambda_exec" {
  name = "notes-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "notes-lambda-dynamodb-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
      ]
      Resource = aws_dynamodb_table.notes.arn
    }]
  })
}
resource "aws_lambda_function" "notes_api" {
  function_name    = "notes-api"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME       = aws_dynamodb_table.notes.name
      AWS_ENDPOINT_URL = "http://host.docker.internal:4566"
    }
  }
}

output "lambda_function_name" {
  value = aws_lambda_function.notes_api.function_name
}
