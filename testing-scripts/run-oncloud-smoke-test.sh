#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
TIMEOUT_SECONDS=60
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
FAILURES=0
FAILED_TESTS=()

print_result() {
  local status="$1"
  local category="$2"
  local method="$3"
  local test_name="$4"
  local http_code="$5"
  local time_total="$6"

  printf '[%s] [%s] %s %s | HTTP %s | %ss\n' \
    "${status}" "${category}" "${method}" "${test_name}" "${http_code}" "${time_total}"
}

print_failure_detail() {
  local response_body

  if [ -s "${api_response_file}" ]; then
    response_body="$(tr '\r\n' ' ' < "${api_response_file}" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    if [ -n "${response_body}" ]; then
      printf '  detail: %s\n' "${response_body}"
    fi
  fi
}

cleanup() {
  rm -f "${token_response_file}" "${api_response_file}"
}
trap cleanup EXIT

fetch_access_token() {
  local token_http_code
  local time_total
  local access_token
  local curl_rc=0

  set +e
  read -r token_http_code time_total <<< "$(
    curl -sS \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${TIMEOUT_SECONDS}" \
      -o "${token_response_file}" \
      -w "%{http_code} %{time_total}" \
      -X POST "${BASE_URL}/api/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=${TOKEN_GRANT_TYPE}" \
      --data-urlencode "client_id=${TOKEN_CLIENT_ID_VALUE}" \
      --data-urlencode "client_secret=${TOKEN_CLIENT_SECRET_VALUE}"
  )"
  curl_rc=$?
  set -e

  if [ "${curl_rc}" -ne 0 ] || [ "${token_http_code}" != "200" ]; then
    if [ "${token_http_code:-000}" = "000" ] || [ -z "${token_http_code:-}" ]; then
      token_http_code="CURL-${curl_rc}"
    fi
    time_total="${time_total:-0}"
    print_result "FAIL" "OnCloud" "POST" "Get Access Token" "${token_http_code}" "${time_total}" >&2
    if [ -s "${token_response_file}" ]; then
      printf '  detail: %s\n' "$(tr '\r\n' ' ' < "${token_response_file}" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')" >&2
    fi
    return 1
  fi

  print_result "PASS" "OnCloud" "POST" "Get Access Token" "${token_http_code}" "${time_total}" >&2

  TOKEN_RESPONSE_JSON="$(cat "${token_response_file}")"
  export TOKEN_RESPONSE_JSON

  access_token="$(
    "${PYTHON_BIN}" -c 'import json, sys; data = json.load(sys.stdin); print(data.get("access_token", ""))' \
      < "${token_response_file}"
  )"
  test -n "${access_token}" || { echo "Token response did not contain access_token"; cat "${token_response_file}"; exit 1; }
  printf '%s' "${access_token}"
}

run_get_test() {
  local category="$1"
  local test_name="$2"
  local path="$3"
  local query_string="${4:-}"
  local url="${BASE_URL}${path}"
  local http_code
  local time_total
  local curl_rc=0

  if [ -n "${query_string}" ]; then
    url="${url}?${query_string}"
  fi

  set +e
  read -r http_code time_total <<< "$(
    curl -sS \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${TIMEOUT_SECONDS}" \
      -o "${api_response_file}" \
      -w "%{http_code} %{time_total}" \
      -X GET "${url}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}"
  )"
  curl_rc=$?
  set -e

  if [ "${curl_rc}" -ne 0 ] || [ "${http_code}" != "200" ]; then
    if [ "${http_code}" = "000" ]; then
      http_code="CURL-${curl_rc}"
    fi
    print_result "FAIL" "${category}" "GET" "${test_name}" "${http_code}" "${time_total}"
    print_failure_detail
    FAILURES=$((FAILURES + 1))
    FAILED_TESTS+=("[${category}] ${test_name}")
    return 0
  fi
  print_result "PASS" "${category}" "GET" "${test_name}" "${http_code}" "${time_total}"
}

run_post_test() {
  local category="$1"
  local test_name="$2"
  local path="$3"
  local body="$4"
  local http_code
  local time_total
  local curl_rc=0

  set +e
  read -r http_code time_total <<< "$(
    curl -sS \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${TIMEOUT_SECONDS}" \
      -o "${api_response_file}" \
      -w "%{http_code} %{time_total}" \
      -X POST "${BASE_URL}${path}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "${body}"
  )"
  curl_rc=$?
  set -e

  if [ "${curl_rc}" -ne 0 ] || [ "${http_code}" != "200" ]; then
    if [ "${http_code}" = "000" ]; then
      http_code="CURL-${curl_rc}"
    fi
    print_result "FAIL" "${category}" "POST" "${test_name}" "${http_code}" "${time_total}"
    print_failure_detail
    FAILURES=$((FAILURES + 1))
    FAILED_TESTS+=("[${category}] ${test_name}")
    return 0
  fi
  print_result "PASS" "${category}" "POST" "${test_name}" "${http_code}" "${time_total}"
}

if ! ACCESS_TOKEN="$(fetch_access_token)"; then
  exit 1
fi
export ACCESS_TOKEN

run_post_test "OnCloud" "Core API Family V1 Download" "/core-api/family/download" "${FAMILY_CERTIFICATE_DOWNLOAD_BODY}"
run_post_test "OnCloud" "Core API Motor V1 Download Car" "/core-api/motor/certificates/download-car" "${MOTOR_CERTIFICATE_DOWNLOAD_CAR_BODY}"
run_post_test "OnCloud" "Core API Motor V1 Download Motorcycle" "/core-api/motor/certificates/download-motorcycle" "${MOTOR_CERTIFICATE_DOWNLOAD_MOTORCYCLE_BODY}"
run_post_test "OnCloud" "Core API Motor V1 eReceipt Download" "/core-api/motor/e-receipt/download" "${MOTOR_ERECEIPT_DOWNLOAD_BODY}"
run_get_test "OnCloud" "General API V1 Create CP ID Retry Failed" "/general-services/create-cp-id/retry-failed"
run_post_test "OnCloud" "General API V1 Create CP ID" "/general-services/create-cp-id" "${CREATE_CP_ID_BODY}"
run_post_test "OnCloud" "General API V1 Motor Generate Renewal Link" "/general-services/motor/generate-renewal-link" "${MOTOR_GENERATE_RENEWAL_LINK_BODY}"
run_post_test "OnCloud" "General API V1 Motor Decrypt Renewal Link" "/general-services/motor/decrypt-renewal-link" "${MOTOR_DECRYPT_RENEWAL_LINK_BODY}"
run_get_test "OnCloud" "Core API Motor V2 Certificate Details" "/core-api-2/motor/certificate-details" "${MOTOR_CERTIFICATE_DETAILS_QUERY}"
run_get_test "OnCloud" "Core API Family V2 Certificate Details" "/core-api-2/family/certificate-details" "${FAMILY_CERTIFICATE_DETAILS_QUERY}"

if [ "${FAILURES}" -gt 0 ]; then
  echo
  echo "${ENV_NAME} OnCloud smoke tests completed with ${FAILURES} failure(s):"
  for failed_test in "${FAILED_TESTS[@]}"; do
    echo "- ${failed_test}"
  done
  exit 1
fi

echo "All ${ENV_NAME} OnCloud smoke tests passed."
