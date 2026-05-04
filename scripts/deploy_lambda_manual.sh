#!/usr/bin/env bash
# =============================================================================
# deploy_lambda_manual.sh
#
# Purpose:
#   Manually create the Lambda function and HTTP API Gateway that Terraform
#   cannot create when an SCP blocks lambda:CreateFunction / apigateway:*.
#
#   Run this script AFTER "terraform apply" has successfully deployed the rest
#   of the stack (ECS worker, DynamoDB, SQS, S3, ECR, IAM roles, SSM, etc.)
#   with enable_lambda_api = false in terraform.tfvars.
#
# What this script creates:
#   1. Lambda deployment package  (zip of full_app_aws/)
#   2. aws_lambda_function        genai-demo-prod-api
#   3. HTTP API Gateway           genai-demo-prod-http-api
#   4. Lambda integration         AWS_PROXY
#   5. Routes                     POST /generate-demo-async
#                                  GET  /job/{job_id}
#   6. Stage                      prod (auto-deploy)
#   7. Lambda resource policy     allow API GW to invoke
#
# Prerequisites:
#   - AWS CLI v2 configured with credentials that allow:
#       lambda:CreateFunction, lambda:AddPermission
#       apigateway:* (POST, GET on /apis, /integrations, /routes, /stages)
#   - The Terraform stack already deployed (to read DynamoDB/SQS/S3 names)
#   - python3 + zip available on the machine
#   - Terraform state must be accessible (or pass values via env vars below)
#
# Usage:
#   cd aws-genai-demo-platform/terraform/full_product
#   chmod +x ../../scripts/deploy_lambda_manual.sh
#   ../../scripts/deploy_lambda_manual.sh
#
#   Override any auto-detected value with environment variables:
#     AWS_REGION=us-east-1 LAMBDA_FUNCTION_NAME=my-func \
#       ../../scripts/deploy_lambda_manual.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "\n${CYAN}[STEP]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# =============================================================================
# 0.  Locate the terraform/full_product directory
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/full_product"
APP_DIR="${REPO_ROOT}/full_app_aws"

[[ -d "$TF_DIR" ]] || die "Terraform directory not found: $TF_DIR"
[[ -d "$APP_DIR" ]] || die "Application directory not found: $APP_DIR"

# =============================================================================
# 1.  Read configuration — from env vars or Terraform outputs/state
# =============================================================================
step "Reading configuration …"

_tf_output() {
  # Safely read a terraform output; returns empty string on failure.
  terraform -chdir="$TF_DIR" output -raw "$1" 2>/dev/null || true
}

# Allow each value to be overridden by an environment variable.
AWS_REGION="${AWS_REGION:-$(_tf_output aws_region 2>/dev/null || echo "us-east-1")}"
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"

# Derive the name prefix the same way locals.tf does.
PROJECT_NAME="${PROJECT_NAME:-genai-demo}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
NAME_PREFIX="${NAME_PREFIX:-${PROJECT_NAME}-${ENVIRONMENT}}"

LAMBDA_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-${NAME_PREFIX}-api}"
LAMBDA_ROLE_ARN="${LAMBDA_ROLE_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/${NAME_PREFIX}-lambda-role}"
LAMBDA_HANDLER="${LAMBDA_HANDLER:-lambda_handlers.api_gateway_router}"
LAMBDA_RUNTIME="${LAMBDA_RUNTIME:-python3.12}"
LAMBDA_TIMEOUT="${LAMBDA_TIMEOUT:-30}"

# Read resource names created by Terraform
JOBS_TABLE="${JOBS_TABLE:-$(_tf_output jobs_table_name)}"
METADATA_TABLE="${METADATA_TABLE:-$(_tf_output metadata_table_name)}"
QUEUE_NAME="${QUEUE_NAME:-$(_tf_output queue_url | awk -F'/' '{print $NF}')}"
S3_BUCKET="${S3_BUCKET:-$(_tf_output artifact_bucket_name)}"

# CloudWatch log group (created by Terraform observability.tf)
LOG_GROUP="/aws/lambda/${LAMBDA_FUNCTION_NAME}"

# API Gateway name
API_NAME="${API_NAME:-${NAME_PREFIX}-http-api}"

# Validate required values
for var in AWS_REGION ACCOUNT_ID LAMBDA_ROLE_ARN JOBS_TABLE METADATA_TABLE QUEUE_NAME S3_BUCKET; do
  [[ -n "${!var}" ]] || die "Could not determine $var. Set it as an environment variable or ensure Terraform outputs are available."
done

ok "Region       : $AWS_REGION"
ok "Account      : $ACCOUNT_ID"
ok "Function     : $LAMBDA_FUNCTION_NAME"
ok "Role         : $LAMBDA_ROLE_ARN"
ok "Jobs table   : $JOBS_TABLE"
ok "Metadata     : $METADATA_TABLE"
ok "Queue name   : $QUEUE_NAME"
ok "S3 bucket    : $S3_BUCKET"

# =============================================================================
# 2.  Build the Lambda deployment package
# =============================================================================
step "Building Lambda deployment package …"

BUNDLE_PATH="${TF_DIR}/lambda_bundle.zip"

# Remove stale bundle
rm -f "$BUNDLE_PATH"

# Zip the full_app_aws directory contents (same as Terraform archive_file)
(cd "$APP_DIR" && zip -qr "$BUNDLE_PATH" .)
ok "Bundle created: $BUNDLE_PATH ($(du -sh "$BUNDLE_PATH" | cut -f1))"

# =============================================================================
# 3.  Create (or update) the Lambda function
# =============================================================================
step "Creating/updating Lambda function '${LAMBDA_FUNCTION_NAME}' …"

ENV_VARS="Variables={AWS_REGION=${AWS_REGION},GENAI_JOBS_TABLE=${JOBS_TABLE},GENAI_QUEUE_NAME=${QUEUE_NAME},GENAI_S3_BUCKET=${S3_BUCKET},GENAI_METADATA_TABLE=${METADATA_TABLE}}"

if aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" \
     --region "$AWS_REGION" &>/dev/null; then

  warn "Function already exists – updating code and configuration …"

  aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --zip-file "fileb://${BUNDLE_PATH}" \
    --region "$AWS_REGION" \
    --output text --query 'FunctionName' > /dev/null

  # Wait for update to complete before changing config
  aws lambda wait function-updated \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --region "$AWS_REGION"

  aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --handler "$LAMBDA_HANDLER" \
    --runtime "$LAMBDA_RUNTIME" \
    --timeout "$LAMBDA_TIMEOUT" \
    --environment "$ENV_VARS" \
    --tracing-config Mode=Active \
    --region "$AWS_REGION" \
    --output text --query 'FunctionName' > /dev/null

  ok "Lambda function updated"

else

  aws lambda create-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --runtime "$LAMBDA_RUNTIME" \
    --role "$LAMBDA_ROLE_ARN" \
    --handler "$LAMBDA_HANDLER" \
    --zip-file "fileb://${BUNDLE_PATH}" \
    --timeout "$LAMBDA_TIMEOUT" \
    --environment "$ENV_VARS" \
    --tracing-config Mode=Active \
    --logging-config '{"LogFormat":"JSON","LogGroup":"'"${LOG_GROUP}"'"}' \
    --region "$AWS_REGION" \
    --output text --query 'FunctionName' > /dev/null

  ok "Lambda function created"

fi

LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${LAMBDA_FUNCTION_NAME}"

# Wait until the function is Active before creating the API GW
step "Waiting for Lambda function to become Active …"
aws lambda wait function-active \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION"
ok "Lambda function is Active"

# =============================================================================
# 4.  Create (or reuse) the HTTP API Gateway
# =============================================================================
step "Setting up HTTP API Gateway '${API_NAME}' …"

# Check if API already exists
EXISTING_API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='${API_NAME}'].ApiId" \
  --output text)

if [[ -n "$EXISTING_API_ID" && "$EXISTING_API_ID" != "None" ]]; then
  API_ID="$EXISTING_API_ID"
  warn "HTTP API already exists: $API_ID – reusing it"
else
  API_ID=$(aws apigatewayv2 create-api \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --region "$AWS_REGION" \
    --query 'ApiId' --output text)
  ok "HTTP API created: $API_ID"
fi

# =============================================================================
# 5.  Create (or reuse) the Lambda integration
# =============================================================================
step "Setting up Lambda integration …"

LAMBDA_INVOKE_ARN="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

EXISTING_INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query "Items[?IntegrationUri=='${LAMBDA_INVOKE_ARN}'].IntegrationId" \
  --output text)

if [[ -n "$EXISTING_INTEGRATION_ID" && "$EXISTING_INTEGRATION_ID" != "None" ]]; then
  INTEGRATION_ID="$EXISTING_INTEGRATION_ID"
  warn "Integration already exists: $INTEGRATION_ID – reusing it"
else
  INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$LAMBDA_INVOKE_ARN" \
    --payload-format-version "2.0" \
    --region "$AWS_REGION" \
    --query 'IntegrationId' --output text)
  ok "Integration created: $INTEGRATION_ID"
fi

# =============================================================================
# 6.  Create routes
# =============================================================================
step "Setting up routes …"

_ensure_route() {
  local route_key="$1"
  local existing
  existing=$(aws apigatewayv2 get-routes \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --query "Items[?RouteKey=='${route_key}'].RouteId" \
    --output text)

  if [[ -n "$existing" && "$existing" != "None" ]]; then
    warn "Route '${route_key}' already exists ($existing) – skipping"
  else
    local route_id
    route_id=$(aws apigatewayv2 create-route \
      --api-id "$API_ID" \
      --route-key "$route_key" \
      --target "integrations/${INTEGRATION_ID}" \
      --region "$AWS_REGION" \
      --query 'RouteId' --output text)
    ok "Route created: ${route_key} → $route_id"
  fi
}

_ensure_route "POST /generate-demo-async"
_ensure_route "GET /job/{job_id}"

# =============================================================================
# 7.  Create prod stage (auto-deploy)
# =============================================================================
step "Setting up 'prod' stage …"

EXISTING_STAGE=$(aws apigatewayv2 get-stages \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --query "Items[?StageName=='prod'].StageName" \
  --output text)

if [[ -n "$EXISTING_STAGE" && "$EXISTING_STAGE" != "None" ]]; then
  warn "Stage 'prod' already exists – skipping"
else
  aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name "prod" \
    --auto-deploy \
    --region "$AWS_REGION" \
    --output text --query 'StageName' > /dev/null
  ok "Stage 'prod' created"
fi

# =============================================================================
# 8.  Grant API Gateway permission to invoke the Lambda function
# =============================================================================
step "Adding Lambda resource policy for API Gateway …"

SOURCE_ARN="arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/*"

# Remove existing statement if it exists (idempotent re-run)
aws lambda remove-permission \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --statement-id "AllowInvokeFromApiGateway" \
  --region "$AWS_REGION" 2>/dev/null || true

aws lambda add-permission \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --statement-id "AllowInvokeFromApiGateway" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "$SOURCE_ARN" \
  --region "$AWS_REGION" \
  --output text --query 'Statement' > /dev/null

ok "Lambda invoke permission granted to API Gateway"

# =============================================================================
# 9.  Print the API URL
# =============================================================================
API_BASE_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod"

echo ""
echo -e "${GREEN}=================================================================${NC}"
echo -e "${GREEN} Lambda + API Gateway deployed successfully!${NC}"
echo -e "${GREEN}=================================================================${NC}"
echo ""
echo -e "  API base URL : ${CYAN}${API_BASE_URL}${NC}"
echo ""
echo -e "${CYAN}Test the API:${NC}"
echo ""
echo "  curl -X POST \"${API_BASE_URL}/generate-demo-async\" \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"use_case\":\"payment\",\"complexity\":\"high\"}'"
echo ""
echo "  JOB_ID=<paste-job-id>"
echo "  curl \"${API_BASE_URL}/job/\${JOB_ID}\""
echo ""
echo -e "${YELLOW}Note:${NC} This Lambda + API GW configuration is not tracked in Terraform"
echo "state because enable_lambda_api = false.  Re-run this script to"
echo "update the function code after code changes."
echo ""
