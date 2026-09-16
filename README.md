markdown
# Serverless Notes API — Terraform + LocalStack

A small serverless REST API (Lambda + API Gateway + DynamoDB), fully defined in Terraform and deployed entirely to **LocalStack** — a local AWS emulator. Zero AWS account, zero cost, fully reproducible, and validated automatically in CI on every push.

## Why this project

Most "I know Terraform" claims on a resume are unverifiable. This project proves it: a real, working serverless API — provisioned, tested, and torn down entirely through Infrastructure as Code — with a GitHub Actions pipeline that deploys and tests it fresh on every commit.

## Architecture

Terraform apply
↓
LocalStack (local AWS emulator, running in Docker)
├── DynamoDB table (notes)
├── Lambda function (Python, CRUD handler)
├── IAM role + policy (Lambda → DynamoDB access)
└── API Gateway (REST API, ANY /notes → Lambda proxy integration)
↓
curl / HTTP client → API Gateway → Lambda → DynamoDB → response


## Stack

- **IaC:** Terraform (AWS provider, pointed at LocalStack instead of real AWS)
- **Compute:** AWS Lambda (Python 3.12)
- **Database:** DynamoDB
- **API layer:** API Gateway (REST, Lambda proxy integration)
- **Local AWS emulation:** LocalStack
- **CI:** GitHub Actions (spins up LocalStack, deploys, tests the live API)

## What it does

`GET /notes` — lists all notes
`POST /notes` — creates a note, body: `{"text": "..."}`

Both routes are handled by a single Lambda function reading/writing a DynamoDB table, fronted by a real API Gateway REST API — the same resource types and wiring you'd use against real AWS.

## The bug I found (and the actual point of this project)

Everything worked perfectly on my Mac. Then I pushed it to GitHub Actions CI and the Lambda started failing with a `502` from every request — with no error message, just a `START`/`END` log pair and a suspiciously exact 10-second delay (matching the Lambda's configured timeout).

The cause: my Lambda code connected to DynamoDB using `host.docker.internal` — a hostname that **only resolves automatically on Docker Desktop for Mac/Windows**. GitHub Actions runners use plain Linux, where that hostname doesn't exist by default. The Lambda wasn't crashing — it was silently hanging trying to reach a host that didn't resolve, until it timed out.

**Fix:** LocalStack automatically injects an environment variable called `LOCALSTACK_HOSTNAME` into every Lambda invocation, correctly pointing back to itself regardless of the underlying OS. Swapping the hardcoded `host.docker.internal` for this dynamic value fixed it on both platforms — no environment-specific branching needed.

**Lesson:** something that "just works" locally can hide an OS-specific assumption that only breaks in a different environment. Testing in CI — not just on your own machine — is what actually catches this class of bug.

## Local setup

```bash
# 1. Start LocalStack (requires a free LocalStack account + auth token)
export LOCALSTACK_AUTH_TOKEN=<your-token>
localstack start -d

# 2. Deploy everything
terraform init
terraform apply

# 3. Test it
API_URL=$(terraform output -raw api_url)
curl "$API_URL"
curl -X POST "$API_URL" -H "Content-Type: application/json" -d '{"text": "hello"}'

# 4. Tear down (LocalStack state is ephemeral, but this cleans Terraform state too)
terraform destroy
```

## Repo structure

├── providers.tf # AWS provider configured to point at LocalStack
├── dynamodb.tf # The notes table
├── lambda.tf # IAM role, policy, Lambda function
├── api_gateway.tf # REST API, resource, method, integration, deployment
├── lambda/
│ └── handler.py # CRUD logic (GET/POST /notes)
└── .github/workflows/
└── ci.yml # Spins up LocalStack, deploys, tests the live API