#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
build_number="${2:-}"
validate_version "${version}"
[[ "${build_number}" =~ ^[1-9][0-9]*$ ]] || fail "Build number must be a positive integer"

repository="${GITHUB_REPOSITORY:-elwan-l1/pathsta}"
release_tag="${GITHUB_REF_NAME:-v${version}}"
[[ "$(version_from_tag "${release_tag}")" == "${version}" ]] || \
  fail "Release tag ${release_tag} does not match version ${version}"

dmg_name="${APP_NAME}-${version}.dmg"
dmg_path="${DISTRIBUTION_DIRECTORY}/${dmg_name}"
notes_path="${DISTRIBUTION_DIRECTORY}/release-notes.md"
appcast_path="${DISTRIBUTION_DIRECTORY}/${SPARKLE_FEED_NAME}"
checksums_path="${DISTRIBUTION_DIRECTORY}/SHA256SUMS"
generate_appcast="${SPARKLE_BIN_DIRECTORY}/generate_appcast"
generate_keys="${SPARKLE_BIN_DIRECTORY}/generate_keys"

[[ -f "${dmg_path}" ]] || fail "Disk image does not exist: ${dmg_path}"
[[ -f "${notes_path}" ]] || fail "Release notes do not exist: ${notes_path}"
[[ -f "${checksums_path}" ]] || fail "Release checksums do not exist: ${checksums_path}"
[[ -x "${generate_appcast}" ]] || fail "Sparkle generate_appcast tool is unavailable"
[[ -x "${generate_keys}" ]] || fail "Sparkle generate_keys tool is unavailable"

require_command xmllint
require_command xcrun

temporary_directory="$(mktemp -d)"
cleanup() {
  rm -rf "${temporary_directory}"
}
trap cleanup EXIT
private_key_path="${temporary_directory}/sparkle-private-key"

if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  printf '%s\n' "${SPARKLE_EDDSA_PRIVATE_KEY}" >"${private_key_path}"
else
  "${generate_keys}" --account "${SPARKLE_KEY_ACCOUNT}" -x "${private_key_path}"
fi
chmod 600 "${private_key_path}"

derived_public_key="$({
  xcrun swift -e \
    'import CryptoKit; import Foundation; let encoded = readLine()!; let data = Data(base64Encoded: encoded)!; let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: data); print(key.publicKey.rawRepresentation.base64EncodedString())' \
    <"${private_key_path}"
})"
[[ "${derived_public_key}" == "${SPARKLE_PUBLIC_KEY}" ]] || \
  fail "Sparkle private key does not match the public key embedded in Pathsta"

archives_directory="${temporary_directory}/archives"
mkdir -p "${archives_directory}"
ditto --norsrc "${dmg_path}" "${archives_directory}/${dmg_name}"
ditto --norsrc "${notes_path}" "${archives_directory}/${APP_NAME}-${version}.md"

download_url="https://github.com/${repository}/releases/download/${release_tag}/"
"${generate_appcast}" \
  --ed-key-file "${private_key_path}" \
  --download-url-prefix "${download_url}" \
  --embed-release-notes \
  --link "https://github.com/${repository}/releases/tag/${release_tag}" \
  --maximum-versions 1 \
  --maximum-deltas 0 \
  -o "${archives_directory}/${SPARKLE_FEED_NAME}" \
  "${archives_directory}"

xmllint --noout "${archives_directory}/${SPARKLE_FEED_NAME}"
grep -Fq "<sparkle:version>${build_number}</sparkle:version>" \
  "${archives_directory}/${SPARKLE_FEED_NAME}" || \
  fail "Appcast does not contain build ${build_number}"
grep -Fq "<sparkle:shortVersionString>${version}</sparkle:shortVersionString>" \
  "${archives_directory}/${SPARKLE_FEED_NAME}" || fail "Appcast does not contain version ${version}"
grep -Fq "url=\"${download_url}${dmg_name}\"" "${archives_directory}/${SPARKLE_FEED_NAME}" || \
  fail "Appcast download URL is incorrect"
grep -Fq 'sparkle:edSignature=' "${archives_directory}/${SPARKLE_FEED_NAME}" || \
  fail "Appcast update is not signed"
grep -Fq 'sparkle-signatures:' "${archives_directory}/${SPARKLE_FEED_NAME}" || \
  fail "Appcast feed is not signed"

ditto --norsrc "${archives_directory}/${SPARKLE_FEED_NAME}" "${appcast_path}"
updated_checksums="${temporary_directory}/SHA256SUMS"
awk -v feed="${SPARKLE_FEED_NAME}" '$2 != feed' "${checksums_path}" >"${updated_checksums}"
(
  cd "${DISTRIBUTION_DIRECTORY}"
  shasum -a 256 "${SPARKLE_FEED_NAME}" >>"${updated_checksums}"
)
mv "${updated_checksums}" "${checksums_path}"
printf 'Generated signed Sparkle feed for %s %s.\n' "${APP_NAME}" "${version}"
