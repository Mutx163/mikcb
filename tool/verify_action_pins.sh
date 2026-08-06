#!/usr/bin/env bash
# Verify that every external GitHub Actions reference is pinned to a real commit SHA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOWS="${WORKFLOWS_DIR:-${ROOT}/.github/workflows}"
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
found=0
shopt -s nullglob
workflow_files=("${WORKFLOWS}"/*.yml "${WORKFLOWS}"/*.yaml)
if [[ "${#workflow_files[@]}" -eq 0 ]]; then
  echo "ERROR: no workflow files found under ${WORKFLOWS}" >&2
  exit 1
fi

for workflow in "${workflow_files[@]}"; do
  line_number=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    ((line_number += 1))
    if [[ ! "${line}" =~ ^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*(.*)$ ]]; then
      continue
    fi

    reference="${BASH_REMATCH[2]}"
    # Action references cannot contain '#'; strip an inline YAML comment.
    reference="${reference%%#*}"
    reference="${reference%"${reference##*[![:space:]]}"}"
    if [[ "${reference}" == \"*\" && "${reference}" == *\" ]]; then
      reference="${reference:1:${#reference}-2}"
    elif [[ "${reference}" == \'*\' && "${reference}" == *\' ]]; then
      reference="${reference:1:${#reference}-2}"
    fi

    # Local reusable workflows/actions are checked by the repository itself and
    # do not have an external commit ref to validate.
    if [[ "${reference}" == ./* || "${reference}" == ../* ]]; then
      echo "OK: ${workflow}:${line_number} local action ${reference}"
      continue
    fi

    found=1
    if [[ ! "${reference}" =~ ^([^@[:space:]]+)@([^@[:space:]]+)$ ]]; then
      echo "ERROR: ${workflow}:${line_number}: malformed uses reference '${reference}'" >&2
      failed=1
      continue
    fi
    action="${BASH_REMATCH[1]}"
    sha="${BASH_REMATCH[2],,}"
    if [[ ! "${sha}" =~ ^[0-9a-f]{40}$ ]]; then
      echo "ERROR: ${workflow}:${line_number}: ${action}@${sha} is not a full 40-character commit SHA" >&2
      failed=1
      continue
    fi
    if ! check_sha "${action}" "${sha}" "${workflow}:${line_number} ${action}"; then
      failed=1
    fi
  done < "${workflow}"
done

if [[ "${found}" -eq 0 ]]; then
  echo "ERROR: no external workflow action references found under ${WORKFLOWS}" >&2
  exit 1
fi
if [[ "${failed}" -ne 0 ]]; then
  echo "Fix workflow pins or run: gh api repos/<owner>/<repo>/commits/<sha>" >&2
  exit 1
fi

echo "All workflow action SHAs verified."
