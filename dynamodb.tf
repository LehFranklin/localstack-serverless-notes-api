resource "aws_dynamodb_table" "notes" {
  name         = "notes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = "localstack-serverless-api"
  }
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.notes.name
}
resource "aws_dynamodb_table" "notes" {
  name         = "notes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}
