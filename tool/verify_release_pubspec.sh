#!/usr/bin/env bash
# Release-cut guard: UTF-8 without BOM, parseable version line, optional
# release-mode alignment (prerelease requires '-' in version).
#
# 2026-10-27 起由 `.githooks/pre-push` 调用（**不是** pre-commit —— 提交时跑这个
# 没有意义：release 是推 tag / 推 main 那一刻的事，而 pre-commit 已经很慢）。
# 也可以手动跑：
#   bash tool/verify_release_pubspec.sh pubspec.yaml
#   bash tool/verify_release_pubspec.sh pubspec.yaml prerelease
set -euo pipefail

PUBSPEC="${1:-pubspec.yaml}"
RELEASE_MODE="${2:-}"

if [[ ! -f "${PUBSPEC}" ]]; then
  echo "ERROR: ${PUBSPEC} not found" >&2
  exit 1
fi

# 找一个能用的 Python。
#
# 原先这里硬编码 `python3`：CI（Linux）有，但 Windows 本地只有 `python` / `py`
# —— 于是这个「守卫」在本机一跑就 exit 49（"Python was not found; run without
# arguments to install from the Microsoft Store"），等于从来没生效过。
# 依次探测，全都找不到才报错。
PY=""
for candidate in python3 python py; do
  if command -v "${candidate}" >/dev/null 2>&1 &&
    "${candidate}" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
    PY="${candidate}"
    break
  fi
done
if [[ -z "${PY}" ]]; then
  echo "ERROR: 找不到可用的 Python 3.8+（试过 python3 / python / py）" >&2
  exit 1
fi

# Windows 工作区（git config core.autocrlf=true）里这份文件是 CRLF，
# 而下面 `grep -E '^version: ...$'` 的 `$` 会撞上 `\r`：同一个合法版本号
# （如 `2.1.3-3+138`）会被误判成「缺少 - 段」，让人以为 pubspec 写错了。
# 一律先归一化成 LF 再校验；错误信息仍报调用方传进来的那个路径。
PUBSPEC_INPUT="${PUBSPEC}"
PUBSPEC_LF="$(mktemp)"
trap 'rm -f "${PUBSPEC_LF}"' EXIT
tr -d '\r' < "${PUBSPEC_INPUT}" > "${PUBSPEC_LF}"
PUBSPEC="${PUBSPEC_LF}"

HEAD_BYTES="$(head -c 3 "${PUBSPEC}" | od -An -tx1 | tr -d ' \n')"
if [[ "${HEAD_BYTES}" == "efbbbf" ]]; then
  echo "ERROR: ${PUBSPEC_INPUT} has UTF-8 BOM (use UTF-8 without BOM)" >&2
  exit 1
fi

"${PY}" - "${PUBSPEC}" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

version_line = next((line for line in text.splitlines() if line.startswith("version:")), None)
if version_line is None:
    print("ERROR: missing version: line", file=sys.stderr)
    sys.exit(1)
version = version_line.split(":", 1)[1].strip()
if not re.fullmatch(r"\d+\.\d+\.\d+(?:-\d+)?\+\d+", version):
    print(f"ERROR: unparseable version: {version!r}", file=sys.stderr)
    sys.exit(1)

description_line = next(
    (line for line in text.splitlines() if line.startswith("description:")),
    None,
)
if description_line is None:
    print("ERROR: missing description: line", file=sys.stderr)
    sys.exit(1)
description = description_line.split(":", 1)[1].strip()
if not description:
    print("ERROR: empty description", file=sys.stderr)
    sys.exit(1)

print(f"OK: version={version}, description length={len(description)}")
PY

if [[ "${RELEASE_MODE}" == "prerelease" ]]; then
  if ! grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+-[0-9]+\+[0-9]+$' "${PUBSPEC}" >/dev/null; then
    echo "ERROR: prerelease cut requires pubspec version with '-' segment (e.g. 1.3.2-0+109 or 1.1.10-7+37)" >&2
    echo "       commit message 'prerelease' does NOT affect CI; android-build reads pubspec only." >&2
    exit 1
  fi
elif [[ "${RELEASE_MODE}" == "release" ]]; then
  if grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+-[0-9]+\+[0-9]+$' "${PUBSPEC}" >/dev/null; then
    echo "ERROR: formal release cut must not use '-' segment in pubspec (e.g. 1.1.11+37, not 1.1.11-0+37)" >&2
    exit 1
  fi
fi
