#!/bin/bash

set -euo pipefail
umask 077

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

require_environment_variable SIGNING_CERT_P12
require_environment_variable SIGNING_CERT_PASSWORD
require_environment_variable GITHUB_ENV
require_command base64
require_command security

temporary_directory="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pathsta-signing.XXXXXX")"
certificate_path="${temporary_directory}/developer-id.p12"
keychain_path="${temporary_directory}/release-signing.keychain-db"
keychain_list_path="${temporary_directory}/original-keychains.txt"
marker_path="${temporary_directory}/.pathsta-release-keychain"
keychain_password="$(uuidgen)$(uuidgen)"

printf 'Pathsta temporary signing keychain\n' >"${marker_path}"
security list-keychains -d user \
  | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//' \
  >"${keychain_list_path}"

original_keychains=()
while IFS= read -r keychain; do
  [[ -n "${keychain}" ]] && original_keychains+=("${keychain}")
done <"${keychain_list_path}"
[[ "${#original_keychains[@]}" -gt 0 ]] || fail "No existing user keychains were found"

cleanup_failed_setup() {
  security delete-keychain "${keychain_path}" >/dev/null 2>&1 || true
  security list-keychains -d user -s "${original_keychains[@]}" >/dev/null 2>&1 || true
  [[ ! -f "${certificate_path}" ]] || unlink "${certificate_path}"
  [[ ! -f "${keychain_list_path}" ]] || unlink "${keychain_list_path}"
  [[ ! -f "${marker_path}" ]] || unlink "${marker_path}"
  rmdir "${temporary_directory}" >/dev/null 2>&1 || true
}
trap cleanup_failed_setup ERR

printf '%s' "${SIGNING_CERT_P12}" | base64 --decode >"${certificate_path}"
security create-keychain -p "${keychain_password}" "${keychain_path}"
security set-keychain-settings -lut 21600 "${keychain_path}"
security unlock-keychain -p "${keychain_password}" "${keychain_path}"
security import "${certificate_path}" \
  -k "${keychain_path}" \
  -P "${SIGNING_CERT_PASSWORD}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "${keychain_password}" \
  "${keychain_path}" >/dev/null
security list-keychains -d user -s "${keychain_path}" "${original_keychains[@]}"

security find-identity -v -p codesigning "${keychain_path}" | grep -Fq "${DEVELOPER_IDENTITY}" || \
  fail "The imported certificate is not ${DEVELOPER_IDENTITY}"

{
  printf 'RELEASE_KEYCHAIN_PATH=%s\n' "${keychain_path}"
  printf 'RELEASE_KEYCHAIN_DIRECTORY=%s\n' "${temporary_directory}"
  printf 'RELEASE_KEYCHAIN_LIST_PATH=%s\n' "${keychain_list_path}"
} >>"${GITHUB_ENV}"

unlink "${certificate_path}"
trap - ERR
