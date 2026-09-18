#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

tag="${1:-}"
version="$(version_from_tag "${tag}")"

require_command xcodegen
require_command xcodebuild

cd "${REPOSITORY_ROOT}"
xcodegen generate --quiet

configured_version="$({
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -showBuildSettings
} | awk '$1 == "MARKETING_VERSION" && $2 == "=" { print $3; exit }')"

[[ "${configured_version}" == "${version}" ]] || \
  fail "Tag ${tag} does not match MARKETING_VERSION ${configured_version}"

grep -Eq "^## \[${version//./\.}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md || \
  fail "CHANGELOG.md needs a dated [${version}] section"

temporary_notes="$(mktemp)"
trap 'rm -f "${temporary_notes}"' EXIT
"${REPOSITORY_ROOT}/Scripts/release/extract-release-notes.sh" "${version}" "${temporary_notes}"

if plutil -p Resources/Pathsta.entitlements | grep -q 'com.apple.security.get-task-allow'; then
  fail "Release entitlements must not contain com.apple.security.get-task-allow"
fi

printf 'Release preflight passed for %s.\n' "${tag}"
