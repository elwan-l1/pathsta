#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
validate_version "${version}"

dmg_path="${DISTRIBUTION_DIRECTORY}/${APP_NAME}-${version}.dmg"
dsym_path="${ARCHIVE_PATH}/dSYMs/${APP_NAME}.app.dSYM"
dsym_archive="${DISTRIBUTION_DIRECTORY}/${APP_NAME}-${version}.dSYM.zip"
notes_path="${DISTRIBUTION_DIRECTORY}/release-notes.md"
checksums_path="${DISTRIBUTION_DIRECTORY}/SHA256SUMS"

[[ -f "${dmg_path}" ]] || fail "Disk image does not exist: ${dmg_path}"
[[ -d "${dsym_path}" ]] || fail "dSYM does not exist: ${dsym_path}"

rm -f "${dsym_archive}" "${notes_path}" "${checksums_path}"
ditto --norsrc -c -k --keepParent "${dsym_path}" "${dsym_archive}"
"${REPOSITORY_ROOT}/Scripts/release/extract-release-notes.sh" "${version}" "${notes_path}"

(
  cd "${DISTRIBUTION_DIRECTORY}"
  shasum -a 256 "$(basename "${dmg_path}")" "$(basename "${dsym_archive}")" >"${checksums_path}"
)
