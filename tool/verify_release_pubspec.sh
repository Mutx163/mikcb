#!/usr/bin/env bash
# Pre-commit guard for release cuts: UTF-8 without BOM, parseable version line.
set -euo pipefail

PUBSPEC="${1:-pubspec.yaml}"

if [[ ! -f "${PUBSPEC}" ]]; then
  echo "ERROR: ${PUBSPEC} not found" >&2
  exit 1
fi

if head -c 3 "${PUBSPEC}" | od -An -tx1 | grep -q 'ef bb bf'; then
  echo "ERROR: ${PUBSPEC} has UTF-8 BOM (use UTF-8 without BOM)" >&2
  exit 1
fi

python3 - "${PUBSPEC}" <<'PY'
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
