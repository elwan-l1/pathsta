#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

dmg_path="${1:-}"
version="${2:-}"
build_number="${3:-}"
validate_version "${version}"
[[ "${build_number}" =~ ^[1-9][0-9]*$ ]] || fail "Build number must be a positive integer"
[[ -f "${dmg_path}" ]] || fail "Disk image does not exist: ${dmg_path}"

allow_unnotarized="${ALLOW_UNNOTARIZED:-0}"
if [[ "${allow_unnotarized}" == "1" ]]; then
  [[ "${ALLOW_ADHOC_SIGNING:-0}" == "1" ]] || fail "ALLOW_UNNOTARIZED is only permitted with ad hoc signing"
fi

require_command codesign
require_command hdiutil
require_command spctl

codesign --verify --strict --verbose=2 "${dmg_path}"
if [[ "${allow_unnotarized}" != "1" ]]; then
  xcrun stapler validate "${dmg_path}"
  spctl --assess --type open --context context:primary-signature --verbose=2 "${dmg_path}"
fi

mount_directory="$(mktemp -d)"
detach_and_clean() {
  hdiutil detach "${mount_directory}" -quiet >/dev/null 2>&1 || true
  rm -rf "${mount_directory}"
}
trap detach_and_clean EXIT
hdiutil attach "${dmg_path}" -nobrowse -readonly -mountpoint "${mount_directory}" -quiet

mounted_app="${mount_directory}/${APP_NAME}.app"
[[ -d "${mounted_app}" ]] || fail "Disk image does not contain ${APP_NAME}.app"
[[ -L "${mount_directory}/Applications" ]] || fail "Disk image does not contain an Applications shortcut"

codesign --verify --deep --strict --verbose=2 "${mounted_app}"
codesign_details="$(codesign -dv --verbose=4 "${mounted_app}" 2>&1)"
grep -Fq "Identifier=${BUNDLE_IDENTIFIER}" <<<"${codesign_details}" || fail "Unexpected bundle identifier"

if [[ "${allow_unnotarized}" != "1" ]]; then
  grep -Fq "TeamIdentifier=${TEAM_IDENTIFIER}" <<<"${codesign_details}" || fail "Unexpected signing team"
  xcrun stapler validate "${mounted_app}"
  spctl --assess --type execute --verbose=2 "${mounted_app}"
  if command -v syspolicy_check >/dev/null 2>&1; then
    syspolicy_check distribution "${mounted_app}"
  fi
fi

actual_version="$(defaults read "${mounted_app}/Contents/Info" CFBundleShortVersionString)"
actual_build="$(defaults read "${mounted_app}/Contents/Info" CFBundleVersion)"
[[ "${actual_version}" == "${version}" ]] || fail "Distributed app version is ${actual_version}, expected ${version}"
[[ "${actual_build}" == "${build_number}" ]] || fail "Distributed app build is ${actual_build}, expected ${build_number}"

expected_architectures="${RELEASE_ARCHITECTURES:-arm64}"
actual_architectures="$(lipo -archs "${mounted_app}/Contents/MacOS/${APP_NAME}")"
for architecture in ${expected_architectures}; do
  grep -qw "${architecture}" <<<"${actual_architectures}" || fail "Distributed app is missing ${architecture}"
done

if find "${mount_directory}" -name '._*' -print -quit | grep -q .; then
  fail "Disk image contains AppleDouble metadata files"
fi

printf 'Verified %s %s (%s).\n' "${APP_NAME}" "${version}" "${actual_architectures}"
