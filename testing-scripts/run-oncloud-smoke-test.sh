#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
TIMEOUT_SECONDS=30
CONNECT_TIMEOUT_SECONDS=10

test -n "${ENV_NAME}" || { echo "Usage: $0 <dev|uat|prod>"; exit 1; }

: "${PUBLIC_HOST_PRIMARY:?Set PUBLIC_HOST_PRIMARY in the env-specific smoke test script}"

case "${ENV_NAME}" in
  uat)
    TOKEN_CLIENT_ID_VALUE="${TOKEN_CLIENT_ID_UAT_ONCLOUD:-${TOKEN_CLIENT_ID:-}}"
    TOKEN_CLIENT_SECRET_VALUE="${TOKEN_CLIENT_SECRET_UAT_ONCLOUD:-${TOKEN_CLIENT_SECRET:-}}"
    ;;
  prod)
    TOKEN_CLIENT_ID_VALUE="${TOKEN_CLIENT_ID_PROD_ONCLOUD:-${TOKEN_CLIENT_ID:-}}"
    TOKEN_CLIENT_SECRET_VALUE="${TOKEN_CLIENT_SECRET_PROD_ONCLOUD:-${TOKEN_CLIENT_SECRET:-}}"
    ;;
  *)
    TOKEN_CLIENT_ID_VALUE="${TOKEN_CLIENT_ID_DEV_ONCLOUD:-${TOKEN_CLIENT_ID:-}}"
    TOKEN_CLIENT_SECRET_VALUE="${TOKEN_CLIENT_SECRET_DEV_ONCLOUD:-${TOKEN_CLIENT_SECRET:-}}"
    ;;
esac

test -n "${TOKEN_CLIENT_ID_VALUE}" || { echo "Set TOKEN_CLIENT_ID_DEV_ONCLOUD, TOKEN_CLIENT_ID_UAT_ONCLOUD, or TOKEN_CLIENT_ID_PROD_ONCLOUD"; exit 1; }
test -n "${TOKEN_CLIENT_SECRET_VALUE}" || { echo "Set TOKEN_CLIENT_SECRET_DEV_ONCLOUD, TOKEN_CLIENT_SECRET_UAT_ONCLOUD, or TOKEN_CLIENT_SECRET_PROD_ONCLOUD"; exit 1; }

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "python3 or python is required"
  exit 1
fi

BASE_URL="${TEST_BASE_URL:-https://${PUBLIC_HOST_PRIMARY}}"
TOKEN_GRANT_TYPE="${TOKEN_GRANT_TYPE:-client_credentials}"

: "${FAMILY_CERTIFICATE_DOWNLOAD_BODY:?Set FAMILY_CERTIFICATE_DOWNLOAD_BODY in the env-specific smoke test script}"
: "${MOTOR_CERTIFICATE_DOWNLOAD_CAR_BODY:?Set MOTOR_CERTIFICATE_DOWNLOAD_CAR_BODY in the env-specific smoke test script}"
: "${MOTOR_CERTIFICATE_DOWNLOAD_MOTORCYCLE_BODY:?Set MOTOR_CERTIFICATE_DOWNLOAD_MOTORCYCLE_BODY in the env-specific smoke test script}"
: "${MOTOR_ERECEIPT_DOWNLOAD_BODY:?Set MOTOR_ERECEIPT_DOWNLOAD_BODY in the env-specific smoke test script}"
: "${CREATE_CP_ID_BODY:?Set CREATE_CP_ID_BODY in the env-specific smoke test script}"
: "${MOTOR_GENERATE_RENEWAL_LINK_BODY:?Set MOTOR_GENERATE_RENEWAL_LINK_BODY in the env-specific smoke test script}"
: "${MOTOR_DECRYPT_RENEWAL_LINK_BODY:?Set MOTOR_DECRYPT_RENEWAL_LINK_BODY in the env-specific smoke test script}"
: "${MOTOR_CERTIFICATE_DETAILS_QUERY:?Set MOTOR_CERTIFICATE_DETAILS_QUERY in the env-specific smoke test script}"
: "${FAMILY_CERTIFICATE_DETAILS_QUERY:?Set FAMILY_CERTIFICATE_DETAILS_QUERY in the env-specific smoke test script}"

token_response_file="$(mktemp)"
api_response_file="$(mktemp)"
cleanup() {
  rm -f "${token_response_file}" "${api_response_file}"
}
trap cleanup EXIT

token_http_code="$(
  curl -sS \
    --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
    --max-time "${TIMEOUT_SECONDS}" \
    -o "${token_response_file}" \
    -w "%{http_code}" \
    -X POST "${BASE_URL}/api/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=${TOKEN_GRANT_TYPE}" \
    --data-urlencode "client_id=${TOKEN_CLIENT_ID_VALUE}" \
    --data-urlencode "client_secret=${TOKEN_CLIENT_SECRET_VALUE}"
)"

if [ "${token_http_code}" != "200" ]; then
  echo "Token request failed with HTTP ${token_http_code}"
  cat "${token_response_file}"
  exit 1
fi

TOKEN_RESPONSE_JSON="$(cat "${token_response_file}")"
ACCESS_TOKEN="$(
  "${PYTHON_BIN}" -c 'import json, sys; data = json.load(sys.stdin); print(data.get("access_token", ""))' \
    < "${token_response_file}"
)"
test -n "${ACCESS_TOKEN}" || { echo "Token response did not contain access_token"; cat "${token_response_file}"; exit 1; }
export TOKEN_RESPONSE_JSON
export ACCESS_TOKEN

run_get_test() {
  local test_name="$1"
  local path="$2"
  local query_string="${3:-}"
  local url="${BASE_URL}${path}"
  local http_code

  if [ -n "${query_string}" ]; then
    url="${url}?${query_string}"
  fi

  http_code="$(
    curl -sS \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${TIMEOUT_SECONDS}" \
      -o "${api_response_file}" \
      -w "%{http_code}" \
      -X GET "${url}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}"
  )"
  if [ "${http_code}" != "200" ]; then
    echo "[FAIL] ${test_name} -> HTTP ${http_code}"
    cat "${api_response_file}"
    exit 1
  fi
  echo "[PASS] ${test_name}"
}

run_post_test() {
  local test_name="$1"
  local path="$2"
  local body="$3"
  local http_code

  http_code="$(
    curl -sS \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${TIMEOUT_SECONDS}" \
      -o "${api_response_file}" \
      -w "%{http_code}" \
      -X POST "${BASE_URL}${path}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "${body}"
  )"
  if [ "${http_code}" != "200" ]; then
    echo "[FAIL] ${test_name} -> HTTP ${http_code}"
    cat "${api_response_file}"
    exit 1
  fi
  echo "[PASS] ${test_name}"
}

run_post_test "Core API Family V1 Download" "/core-api/family/download" "${FAMILY_CERTIFICATE_DOWNLOAD_BODY}"
run_post_test "Core API Motor V1 Download Car" "/core-api/motor/certificates/download-car" "${MOTOR_CERTIFICATE_DOWNLOAD_CAR_BODY}"
run_post_test "Core API Motor V1 Download Motorcycle" "/core-api/motor/certificates/download-motorcycle" "${MOTOR_CERTIFICATE_DOWNLOAD_MOTORCYCLE_BODY}"
run_post_test "Core API Motor V1 eReceipt Download" "/core-api/motor/e-receipt/download" "${MOTOR_ERECEIPT_DOWNLOAD_BODY}"
run_get_test "General API V1 Create CP ID Retry Failed" "/general-services/create-cp-id/retry-failed"
run_post_test "General API V1 Create CP ID" "/general-services/create-cp-id" "${CREATE_CP_ID_BODY}"
run_post_test "General API V1 Motor Generate Renewal Link" "/general-services/motor/generate-renewal-link" "${MOTOR_GENERATE_RENEWAL_LINK_BODY}"
run_post_test "General API V1 Motor Decrypt Renewal Link" "/general-services/motor/decrypt-renewal-link" "${MOTOR_DECRYPT_RENEWAL_LINK_BODY}"
run_get_test "Core API Motor V2 Certificate Details" "/core-api-2/motor/certificate-details" "${MOTOR_CERTIFICATE_DETAILS_QUERY}"
run_get_test "Core API Family V2 Certificate Details" "/core-api-2/family/certificate-details" "${FAMILY_CERTIFICATE_DETAILS_QUERY}"

echo "All ${ENV_NAME} OnCloud smoke tests passed."
