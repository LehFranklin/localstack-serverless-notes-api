import json
import os
import uuid
import boto3

# When running inside LocalStack, AWS_ENDPOINT_URL is set via the Lambda's
# environment variables (see lambda.tf) so boto3 talks to LocalStack instead
# of real AWS, exactly like the Terraform provider does.
dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=os.environ.get("AWS_ENDPOINT_URL"),
    region_name=os.environ.get("AWS_REGION", "us-east-1"),
)
table = dynamodb.Table(os.environ.get("TABLE_NAME", "notes"))


def handler(event, context):
    """
    A tiny CRUD API for notes, triggered by API Gateway.
    - GET  /notes       -> list all notes
    - POST /notes       -> create a note, body: {"text": "..."}
    """
    method = event.get("httpMethod", "GET")

    try:
        if method == "POST":
            body = json.loads(event.get("body") or "{}")
            note_id = str(uuid.uuid4())
            item = {"id": note_id, "text": body.get("text", "")}
            table.put_item(Item=item)
            return _response(201, item)

        elif method == "GET":
            result = table.scan()
            return _response(200, result.get("Items", []))

        else:
            return _response(405, {"error": f"Method {method} not allowed"})

    except Exception as e:
        return _response(500, {"error": str(e)})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
