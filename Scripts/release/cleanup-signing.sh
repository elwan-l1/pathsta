#!/bin/bash

set -euo pipefail

if [[ -z "${RELEASE_KEYCHAIN_PATH:-}" && \
      -z "${RELEASE_KEYCHAIN_DIRECTORY:-}" && \
      -z "${RELEASE_KEYCHAIN_LIST_PATH:-}" ]]; then
  printf 'No temporary Pathsta signing keychain is configured; cleanup skipped.\n'
  exit 0
fi

if [[ -z "${RELEASE_KEYCHAIN_PATH:-}" || \
      -z "${RELEASE_KEYCHAIN_DIRECTORY:-}" || \
      -z "${RELEASE_KEYCHAIN_LIST_PATH:-}" ]]; then
  printf 'error: Incomplete temporary keychain state; refusing cleanup.\n' >&2
  exit 1
fi

marker_path="${RELEASE_KEYCHAIN_DIRECTORY}/.pathsta-release-keychain"
expected_keychain_path="${RELEASE_KEYCHAIN_DIRECTORY}/release-signing.keychain-db"
expected_list_path="${RELEASE_KEYCHAIN_DIRECTORY}/original-keychains.txt"

if [[ "$(basename "${RELEASE_KEYCHAIN_DIRECTORY}")" != pathsta-signing.* || \
      "${RELEASE_KEYCHAIN_PATH}" != "${expected_keychain_path}" || \
      "${RELEASE_KEYCHAIN_LIST_PATH}" != "${expected_list_path}" || \
      ! -f "${marker_path}" || \
      ! -f "${RELEASE_KEYCHAIN_LIST_PATH}" ]]; then
  printf 'error: Temporary keychain paths failed validation; refusing cleanup.\n' >&2
  exit 1
fi

original_keychains=()
while IFS= read -r keychain; do
  [[ -n "${keychain}" ]] && original_keychains+=("${keychain}")
done <"${RELEASE_KEYCHAIN_LIST_PATH}"

if [[ "${#original_keychains[@]}" -eq 0 ]]; then
  printf 'error: Original keychain list is empty; refusing cleanup.\n' >&2
  exit 1
fi

security delete-keychain "${RELEASE_KEYCHAIN_PATH}" >/dev/null 2>&1 || true
security list-keychains -d user -s "${original_keychains[@]}"

unlink "${RELEASE_KEYCHAIN_LIST_PATH}"
unlink "${marker_path}"
rmdir "${RELEASE_KEYCHAIN_DIRECTORY}"
