#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
output_path="${2:-/dev/stdout}"
validate_version "${version}"

awk -v heading="## [${version}]" '
  index($0, heading) == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found { print }
' "${REPOSITORY_ROOT}/CHANGELOG.md" >"${output_path}"

grep -q '[^[:space:]]' "${output_path}" || fail "No release notes found for ${version}"
