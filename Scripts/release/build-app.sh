#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
build_number="${2:-}"
validate_version "${version}"
[[ "${build_number}" =~ ^[1-9][0-9]*$ ]] || fail "Build number must be a positive integer"

signing_identity="${SIGNING_IDENTITY:-${DEVELOPER_IDENTITY}}"
release_architectures="${RELEASE_ARCHITECTURES:-arm64}"

if [[ "${signing_identity}" == "-" ]]; then
  [[ "${ALLOW_ADHOC_SIGNING:-0}" == "1" ]] || fail "Ad hoc signing requires ALLOW_ADHOC_SIGNING=1"
else
  security find-identity -v -p codesigning | grep -Fq "${signing_identity}" || \
    fail "Signing identity is unavailable: ${signing_identity}"
fi

require_command codesign
require_command ditto
require_command xcodebuild
require_command xcodegen

cd "${REPOSITORY_ROOT}"
rm -rf "${RELEASE_ROOT}"
mkdir -p "${RELEASE_ROOT}" "${DISTRIBUTION_DIRECTORY}"
xcodegen generate --quiet

xcodebuild archive \
  -quiet \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  -clonedSourcePackagesDirPath "${RELEASE_ROOT}/SourcePackages" \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CURRENT_PROJECT_VERSION="${build_number}" \
  MARKETING_VERSION="${version}" \
  ARCHS="${release_architectures}" \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO \
  archive

archived_app="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
[[ -d "${archived_app}" ]] || fail "Archive did not contain ${APP_NAME}.app"
ditto --norsrc "${archived_app}" "${APP_PATH}"
xattr -cr "${APP_PATH}"

sign_component() {
  local component="$1"
  shift
  [[ -e "${component}" ]] || fail "Code-signing component is missing: ${component}"

  local arguments=(--force --options runtime --generate-entitlement-der --sign "${signing_identity}")
  if [[ "${signing_identity}" != "-" ]]; then
    arguments+=(--timestamp)
  fi
  arguments+=("$@" "${component}")
  codesign "${arguments[@]}"
}

# Sparkle contains nested executables that must be signed from the inside out.
# Do not use --deep for signing: Downloader.xpc carries its own entitlements.
sparkle_framework="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
sparkle_version="${sparkle_framework}/Versions/B"
sign_component "${sparkle_version}/XPCServices/Installer.xpc"
sign_component "${sparkle_version}/XPCServices/Downloader.xpc" \
  --preserve-metadata=entitlements
sign_component "${sparkle_version}/Autoupdate"
sign_component "${sparkle_version}/Updater.app"
sign_component "${sparkle_framework}"
sign_component "${APP_PATH}" \
  --entitlements "${REPOSITORY_ROOT}/Resources/Pathsta.entitlements"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

actual_version="$(defaults read "${APP_PATH}/Contents/Info" CFBundleShortVersionString)"
actual_build="$(defaults read "${APP_PATH}/Contents/Info" CFBundleVersion)"
[[ "${actual_version}" == "${version}" ]] || fail "Built app version is ${actual_version}, expected ${version}"
[[ "${actual_build}" == "${build_number}" ]] || fail "Built app build is ${actual_build}, expected ${build_number}"

for architecture in ${release_architectures}; do
  lipo -archs "${APP_PATH}/Contents/MacOS/${APP_NAME}" | tr ' ' '\n' | grep -Fxq "${architecture}" || \
    fail "Built app is missing architecture ${architecture}"
done
