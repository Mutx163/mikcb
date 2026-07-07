#!/usr/bin/env bash
# Verify that GitHub Actions pinned commit SHAs exist on their upstream repos.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOWS="${ROOT}/.github/workflows"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

check_sha() {
  local repo="$1"
  local sha="$2"
  local label="$3"
  local code

  if command -v gh >/dev/null 2>&1 && [[ -n "${TOKEN}" ]]; then
    if gh api "repos/${repo}/commits/${sha}" --jq .sha >/dev/null 2>&1; then
      echo "OK: ${label} @ ${sha:0:12}…"
      return 0
    fi
    echo "ERROR: ${label}: commit ${sha} not found on ${repo} (gh api)" >&2
    return 1
  fi

  local curl_args=(-s -o /dev/null -w '%{http_code}')
  if [[ -n "${TOKEN}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${TOKEN}")
  fi
  code="$(curl "${curl_args[@]}" "https://api.github.com/repos/${repo}/commits/${sha}")"
  if [[ "${code}" == "200" ]]; then
    echo "OK: ${label} @ ${sha:0:12}…"
    return 0
  fi
  if [[ "${code}" == "403" && -z "${TOKEN}" ]]; then
    echo "SKIP: ${label} @ ${sha:0:12}… (HTTP 403 without token; CI uses GITHUB_TOKEN)" >&2
    return 0
  fi
  echo "ERROR: ${label}: commit ${sha} not found on ${repo} (HTTP ${code})" >&2
  return 1
}

failed=0

while IFS= read -r line; do
  if [[ "${line}" =~ uses:[[:space:]]([^@]+)@([0-9a-f]{40}) ]]; then
    action="${BASH_REMATCH[1]}"
    sha="${BASH_REMATCH[2]}"
    repo="${action}"
    if ! check_sha "${repo}" "${sha}" "${action}"; then
      failed=1
    fi
  fi
done < <(grep -E 'uses:.*@[0-9a-f]{40}' "${WORKFLOWS}"/*.yml || true)

if [[ "${failed}" -ne 0 ]]; then
  echo "Fix workflow pins or run: gh api repos/<owner>/<repo>/commits/<sha>" >&2
  exit 1
fi

echo "All pinned action SHAs verified."
