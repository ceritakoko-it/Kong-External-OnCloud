#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PUBLIC_HOST_PRIMARY='dev-connect.kaotim.my'
export FAMILY_CERTIFICATE_DOWNLOAD_BODY='{"policyNo":"TMK20250364263","documentType":"EMEDICAL_CARD"}'
export MOTOR_CERTIFICATE_DOWNLOAD_CAR_BODY='{"cover_note_no":"TMKT00000748","language":"BM"}'
export MOTOR_CERTIFICATE_DOWNLOAD_MOTORCYCLE_BODY='{"cover_note_no":"TMKT00000748","language":"BM"}'
export MOTOR_ERECEIPT_DOWNLOAD_BODY='{"e_certificate_no":"TMKT00000974","payment_reference_no":"R0101552","masked_card":"","vehicle_type":"car"}'
export CREATE_CP_ID_BODY='{"userNric":"900101-01-1234","userDob":"1990-01-01","userEmail":"user@example.com","userMobile":"60123456789","userName":"John Doe","userNricType":"N","eCertNo":"TMKT00001352"}'
export MOTOR_GENERATE_RENEWAL_LINK_BODY='{"product":"motor","identificationNumber":"900101011234","vehRegNo":"ABC1234"}'
export MOTOR_DECRYPT_RENEWAL_LINK_BODY='{"link":"https://uat1-motor.kaotim.my/renewal?r=UzOQzwtEQ4FtVq5AyG5DYPeWl1Qi3CnwB5ZfBRWAJ4E%3D"}'
export MOTOR_CERTIFICATE_DETAILS_QUERY='e_certificate_no=TMKT00001352'
export FAMILY_CERTIFICATE_DETAILS_QUERY='e_certificate_no=TMK20230002180'

bash "${SCRIPT_DIR}/run-oncloud-smoke-test.sh" dev
