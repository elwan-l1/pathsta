#!/bin/bash
# shellcheck disable=SC2034

set -euo pipefail

# This file is sourced by small release commands, so each command uses only part of it.
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPOSITORY_ROOT
readonly APP_NAME="Pathsta"
readonly SCHEME="Pathsta"
readonly PROJECT="Pathsta.xcodeproj"
readonly BUNDLE_IDENTIFIER="ch.codevs.pathsta"
readonly TEAM_IDENTIFIER="K85JVL5Z98"
readonly DEVELOPER_IDENTITY="Developer ID Application: CODEVS Sarl (${TEAM_IDENTIFIER})"
readonly GITHUB_API_VERSION="2026-03-10"
readonly RELEASE_ROOT="${REPOSITORY_ROOT}/.build/release"
readonly ARCHIVE_PATH="${RELEASE_ROOT}/${APP_NAME}.xcarchive"
readonly APP_PATH="${RELEASE_ROOT}/${APP_NAME}.app"
readonly DISTRIBUTION_DIRECTORY="${RELEASE_ROOT}/dist"
readonly SPARKLE_KEY_ACCOUNT="ch.codevs.pathsta"
readonly SPARKLE_PUBLIC_KEY="9TznX86q/BzyskCGcSxaOpXPIq5bE77bD/5f0Ji+vM4="
readonly SPARKLE_BIN_DIRECTORY="${RELEASE_ROOT}/SourcePackages/artifacts/sparkle/Sparkle/bin"
readonly SPARKLE_FEED_NAME="appcast.xml"
readonly SPARKLE_FEED_URL="https://github.com/elwan-l1/pathsta/releases/latest/download/${SPARKLE_FEED_NAME}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_environment_variable() {
  local variable_name="$1"
  [[ -n "${!variable_name:-}" ]] || fail "Required environment variable is empty: ${variable_name}"
}

validate_version() {
  local version="$1"
  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]] || \
    fail "Version must use SemVer without a leading v: ${version}"
}

version_from_tag() {
  local tag="$1"
  [[ "${tag}" == v* ]] || fail "Release tag must start with v: ${tag}"
  local version="${tag#v}"
  validate_version "${version}"
  printf '%s\n' "${version}"
}

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}
