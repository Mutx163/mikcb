#!/usr/bin/env python3
"""Fetch qingyu_warehouse root_index.yaml and write docs/schools.json for the site."""

from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_SOURCE = "https://github.com/Mutx163/qingyu_warehouse"
DEFAULT_SOURCE_REF = "main"
DEFAULT_YAML_URL = (
    "https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml"
)
DEFAULT_OUTPUT = Path("docs/schools.json")

QUOTED_VALUE = re.compile(r'^[^:\s]+:\s*["\']?(.+?)["\']?\s*$')


def extract_value(line: str) -> str:
    without_comment = re.sub(r"\s+#.*$", "", line.strip())
    match = QUOTED_VALUE.match(without_comment)
    if not match:
        return ""
    return match.group(1).strip()


def parse_root_index_yaml(text: str) -> list[dict[str, str]]:
    schools: list[dict[str, str]] = []
    current: dict[str, str] | None = None

    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if stripped.startswith("- id:"):
            if current:
                schools.append(current)
            current = {"id": extract_value(stripped.removeprefix("- ").strip())}
            continue

        if current is None:
            continue

        for key in ("name", "initial", "resource_folder"):
            if stripped.startswith(f"{key}:"):
                current[key] = extract_value(stripped)
                break

    if current:
        schools.append(current)

    return [
        item
        for item in schools
        if item.get("id") and item.get("name") and item.get("resource_folder")
    ]


def classify_school(entry: dict[str, str]) -> str:
    school_id = entry["id"]
    name = entry["name"]
    if school_id == "GLOBAL_TOOLS" or "通用" in name:
        return "generic"
    return "school"


def sort_key(entry: dict[str, str]) -> tuple[int, str, str]:
    category = classify_school(entry)
    generic_rank = 0 if category == "generic" else 1
    return (generic_rank, entry.get("initial", ""), entry.get("name", ""))


def build_payload(entries: list[dict[str, str]]) -> dict:
    normalized = []
    for entry in sorted(entries, key=sort_key):
        normalized.append(
            {
                "id": entry["id"],
                "name": entry["name"],
                "initial": entry.get("initial", ""),
                "resourceFolder": entry["resource_folder"],
                "category": classify_school(entry),
            }
        )

    school_count = sum(1 for item in normalized if item["category"] == "school")
    generic_count = sum(1 for item in normalized if item["category"] == "generic")

    return {
        "updatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source": DEFAULT_SOURCE,
        "sourceRef": DEFAULT_SOURCE_REF,
        "counts": {
            "total": len(normalized),
            "schools": school_count,
            "generic": generic_count,
        },
        "schools": normalized,
    }


def fetch_yaml(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "mikcb-sync-schools-json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset)


def main() -> int:
    output_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    yaml_url = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_YAML_URL

    try:
        yaml_text = fetch_yaml(yaml_url)
    except urllib.error.URLError as error:
        print(f"ERROR: failed to fetch {yaml_url}: {error}", file=sys.stderr)
        return 1

    entries = parse_root_index_yaml(yaml_text)
    if not entries:
        print("ERROR: no schools parsed from root_index.yaml", file=sys.stderr)
        return 1

    payload = build_payload(entries)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(f"{json.dumps(payload, ensure_ascii=False, indent=2)}\n", encoding="utf-8")
    print(
        f"Wrote {output_path} "
        f"({payload['counts']['schools']} schools, {payload['counts']['generic']} generic)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
