#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

target_path="${1:-}"
[[ -e "${target_path}" ]] || fail "Notarization target does not exist: ${target_path}"

require_environment_variable NOTARY_API_KEY_P8
require_environment_variable NOTARY_KEY_ID
require_environment_variable NOTARY_ISSUER_ID
require_command ditto
require_command jq
require_command xcrun

temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
api_key_path="${temporary_directory}/AuthKey_${NOTARY_KEY_ID}.p8"
printf '%s' "${NOTARY_API_KEY_P8}" | base64 --decode >"${api_key_path}"
chmod 600 "${api_key_path}"

submission_path="${target_path}"
if [[ -d "${target_path}" ]]; then
  submission_path="${temporary_directory}/$(basename "${target_path}").zip"
  ditto --norsrc -c -k --keepParent "${target_path}" "${submission_path}"
fi

result_path="${temporary_directory}/submission.json"
xcrun notarytool submit "${submission_path}" \
  --key "${api_key_path}" \
  --key-id "${NOTARY_KEY_ID}" \
  --issuer "${NOTARY_ISSUER_ID}" \
  --wait \
  --output-format json >"${result_path}"

submission_id="$(jq -r '.id' "${result_path}")"
status="$(jq -r '.status' "${result_path}")"
log_path="${DISTRIBUTION_DIRECTORY}/notary-$(basename "${target_path}").json"
xcrun notarytool log "${submission_id}" \
  --key "${api_key_path}" \
  --key-id "${NOTARY_KEY_ID}" \
  --issuer "${NOTARY_ISSUER_ID}" >"${log_path}"

[[ "${status}" == "Accepted" ]] || fail "Apple rejected notarization submission ${submission_id} (${status})"
xcrun stapler staple "${target_path}"
xcrun stapler validate "${target_path}"
