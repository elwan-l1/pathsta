#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

tag="${1:-}"
version_from_tag "${tag}" >/dev/null
require_environment_variable GITHUB_REPOSITORY
require_command gh

owner="${GITHUB_REPOSITORY%%/*}"
repository="${GITHUB_REPOSITORY#*/}"

for _ in {1..20}; do
  immutable="$(gh api \
    -H "X-GitHub-Api-Version: ${GITHUB_API_VERSION}" \
    "repos/${owner}/${repository}/releases/tags/${tag}" \
    --jq .immutable)"
  if [[ "${immutable}" == "true" ]]; then
    printf 'Release %s is immutable.\n' "${tag}"
    exit 0
  fi
  sleep 3
done

fail "Release ${tag} did not become immutable; enable immutable releases before publishing"
