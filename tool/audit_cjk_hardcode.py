"""Scan lib/ for user-visible hardcoded CJK strings (excluding l10n ARB/generated)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

SKIP_PARTS = {
    "l10n/app_localizations",
    "l10n/app_zh",
    "l10n/app_en",
    "l10n/app_ja",
    "l10n/app_ko",
    "l10n/app_zh_HK",
    "l10n/app_zh_TW",
}

# Comments, imports, and debug-only paths are still flagged for manual review.
CJK = re.compile(r"[\u4e00-\u9fff]")
STRING = re.compile(r"(['\"])(?:(?=(\\?))\2.)*?\1", re.DOTALL)

def should_skip(path: Path) -> bool:
    rel = path.as_posix().replace("\\", "/")
    if "/l10n/" in rel and rel.endswith(".arb"):
        return True
    for part in SKIP_PARTS:
        if part in rel:
            return True
    return False

def main() -> int:
    hits: list[tuple[str, int, str]] = []
    for path in sorted(LIB.rglob("*.dart")):
        if should_skip(path):
            continue
        text = path.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            if "l10n." in line or "AppLocalizations" in line:
                continue
            if not CJK.search(line):
                continue
            # skip pure doc comments
            if stripped.startswith("///") and CJK.search(stripped[3:]):
                continue
            hits.append((path.relative_to(ROOT).as_posix(), lineno, line.rstrip()))

    by_file: dict[str, list[tuple[int, str]]] = {}
    for file, lineno, content in hits:
        by_file.setdefault(file, []).append((lineno, content))

    print(f"Files with CJK outside l10n: {len(by_file)}")
    print(f"Total lines: {len(hits)}")
    for file in sorted(by_file, key=lambda f: -len(by_file[f]))[:40]:
        print(f"\n{file} ({len(by_file[file])})")
        for lineno, content in by_file[file][:8]:
            print(f"  {lineno}: {content[:120]}")
        if len(by_file[file]) > 8:
            print(f"  ... +{len(by_file[file]) - 8} more")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
