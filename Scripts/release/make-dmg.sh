#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
validate_version "${version}"
[[ -d "${APP_PATH}" ]] || fail "Build ${APP_NAME}.app before creating the disk image"

signing_identity="${SIGNING_IDENTITY:-${DEVELOPER_IDENTITY}}"
if [[ "${signing_identity}" == "-" ]]; then
  [[ "${ALLOW_ADHOC_SIGNING:-0}" == "1" ]] || fail "Ad hoc signing requires ALLOW_ADHOC_SIGNING=1"
fi

require_command codesign
require_command diskutil
require_command ditto
require_command xcrun

mkdir -p "${DISTRIBUTION_DIRECTORY}"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
volume_directory="${temporary_directory}/volume"
mkdir -p "${volume_directory}"
ditto --norsrc "${APP_PATH}" "${volume_directory}/${APP_NAME}.app"
ln -s /Applications "${volume_directory}/Applications"

volume_icon="${APP_PATH}/Contents/Resources/PathstaAppIcon.icns"
[[ -f "${volume_icon}" ]] || fail "Built app does not contain its generated icon"
# Finder requires both this hidden file and the volume's custom-icon flag.
ditto --norsrc "${volume_icon}" "${volume_directory}/.VolumeIcon.icns"
xcrun SetFile -a V "${volume_directory}/.VolumeIcon.icns"
xcrun SetFile -a C "${volume_directory}"

dmg_path="${DISTRIBUTION_DIRECTORY}/${APP_NAME}-${version}.dmg"
rm -f "${dmg_path}"
diskutil image create from \
  --format UDZO \
  --volumeName "${APP_NAME}" \
  "${volume_directory}" \
  "${dmg_path}"

codesign_arguments=(--force --sign "${signing_identity}")
if [[ "${signing_identity}" != "-" ]]; then
  codesign_arguments+=(--timestamp)
fi
codesign "${codesign_arguments[@]}" "${dmg_path}"
codesign --verify --strict --verbose=2 "${dmg_path}"
printf '%s\n' "${dmg_path}"
