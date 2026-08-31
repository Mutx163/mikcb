"""Scan lib/ for user-visible hardcoded CJK strings (excluding l10n ARB/generated)."""
from __future__ import annotations

import argparse
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--baseline",
        metavar="FILE",
        help="ratchet mode: compare per-file counts against baseline file; "
        "fail on regressions, auto-lower baseline on improvements",
    )
    args = parser.parse_args()
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

    current = {file: len(items) for file, items in by_file.items()}

    # --baseline <file>: 与基线比对，只许减少不许增加（棘轮模式）。
    # 基线文件不存在时生成初始基线并以非零码退出，人工确认后入库。
    if args.baseline:
        baseline_path = Path(args.baseline)
        if baseline_path.exists():
            baseline: dict[str, int] = {}
            for line in baseline_path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                path, _, count = line.rpartition(":")
                baseline[path] = int(count)
            regressions = {
                file: (baseline.get(file, 0), count)
                for file, count in current.items()
                if count > baseline.get(file, 0)
            }
            new_files = sorted(set(current) - set(baseline))
            if regressions or new_files:
                print("CJK hardcode audit FAILED (ratchet only allows decreases)")
                for file, (old, cnt) in sorted(regressions.items()):
                    print(f"  REGRESSION {file}: {old} -> {cnt}")
                for file in new_files:
                    print(f"  NEW FILE {file}: {current[file]}")
                return 1
            improved = {
                file: (baseline[file], count)
                for file, count in current.items()
                if count < baseline.get(file, 0)
            }
            if improved:
                baseline.update(current)
                lines = [f"{file}:{count}" for file, count in sorted(baseline.items())]
                baseline_path.write_text(
                    "\n".join(lines) + "\n", encoding="utf-8"
                )
                print(
                    f"CJK hardcode audit OK, baseline improved "
                    f"({len(improved)} files reduced), baseline file updated"
                )
                for file, (old, cnt) in sorted(improved.items()):
                    print(f"  {file}: {old} -> {cnt}")
            else:
                print(
                    f"CJK hardcode audit OK: {len(current)} files, "
                    f"{sum(current.values())} lines (same as baseline)"
                )
            return 0
        lines = [f"{file}:{count}" for file, count in sorted(current.items())]
        baseline_path.parent.mkdir(parents=True, exist_ok=True)
        baseline_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(
            f"Baseline file created at {baseline_path} "
            f"({len(current)} files, {sum(current.values())} lines). "
            "Review and commit it."
        )
        return 1

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
