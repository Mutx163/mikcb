#!/usr/bin/env python3
"""
Fix ALL remaining HyperOS audit violations across typography, border-radius,
spacing, and colors categories.

Usage:
  python tool/fix_audit_all.py --dry-run   # preview changes only
  python tool/fix_audit_all.py --apply     # apply fixes
  python tool/fix_audit_all.py             # same as --dry-run
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Pattern

ROOT = Path(__file__).resolve().parents[1]
AUDIT_JSON = ROOT / "tool" / "audit_output.json"

# Files that must NOT be modified (legitimate exceptions)
EXCLUDED_FILES = {
    "lib/screens/timetable_screen.dart",
    "lib/widgets/course_card.dart",
}


# ─── Fix helpers ────────────────────────────────────────────────────────────

def _nearest(value: float, standards: list[float]) -> float:
    """Return the standard value closest to *value*."""
    return min(standards, key=lambda s: abs(s - value))


# ─── Typography fixes ────────────────────────────────────────────────────────

FONT_WEIGHT_MAP: dict[str, str] = {
    "FontWeight.bold": "FontWeight.w400",
    "FontWeight.w700": "FontWeight.w400",
    "FontWeight.w800": "FontWeight.w400",
    "FontWeight.w900": "FontWeight.w400",
    "FontWeight.w600": "FontWeight.w400",
}

# Regex that matches FontWeight references (avoid partial matches inside
# identifiers like `FooFontWeight`).
_FONT_WEIGHT_RE = re.compile(
    r"(?<![.\w])(" + "|".join(re.escape(kw) for kw in FONT_WEIGHT_MAP) + r")"
)


def fix_typography_line(line: str) -> str | None:
    """Fix FontWeight violations on a single line. Return new line or None."""
    new_line = _FONT_WEIGHT_RE.sub(
        lambda m: FONT_WEIGHT_MAP[m.group(1)], line
    )
    return new_line if new_line != line else None


# ─── Border-radius fixes ────────────────────────────────────────────────────

# Non-standard → standard mapping for border-radius (task-specified)
RADIUS_MAP: dict[int, int] = {
    1: 4,
    6: 8,
    7: 8,
    10: 8,
    11: 12,
    14: 16,
    18: 16,
    22: 24,
}
_RADIUS_RE = re.compile(r"BorderRadius\.circular\((\d+)\)")


def _radius_replacer(m: re.Match[str]) -> str | None:
    val = int(m.group(1))
    new_val = RADIUS_MAP.get(val)
    if new_val is None:
        # Try nearest standard
        standards = [4, 8, 12, 16, 20, 24, 28]
        nv = int(_nearest(float(val), standards))
        if nv != val:
            new_val = nv
    if new_val is not None and new_val != val:
        return f"BorderRadius.circular({new_val})"
    return None


def fix_radius_line(line: str) -> str | None:
    """Fix border-radius violations on a single line. Return new line or None."""
    # Extract the radius value from the snippet and try to replace
    m = _RADIUS_RE.search(line)
    if m:
        replacement = _radius_replacer(m)
        if replacement:
            return line.replace(m.group(0), replacement, 1)
    return None


# ─── Spacing fixes ──────────────────────────────────────────────────────────

# Non-standard → standard mapping for spacing values (task-specified)
SPACING_MAP: dict[int, int] = {
    2: 4,
    5: 4,
    7: 8,
    9: 8,
    10: 12,
    11: 12,
    14: 16,
}
STANDARD_SPACING = [4, 6, 8, 12, 13, 16, 20, 24, 28, 32, 48, 56, 72]

# Patterns to match EdgeInsets declarations
_EDGE_INSETS_PATTERNS: list[tuple[Pattern[str], str]] = [
    (re.compile(r"EdgeInsets\.symmetric\(horizontal:\s*(\d+),?\s*vertical:\s*(\d+)?\)"), "symmetric_hv"),
    (re.compile(r"EdgeInsets\.symmetric\(horizontal:\s*(\d+)\)"), "symmetric_h"),
    (re.compile(r"EdgeInsets\.symmetric\(vertical:\s*(\d+)\)"), "symmetric_v"),
    (re.compile(r"EdgeInsets\.only\(([^)]*)\)"), "only"),
    (re.compile(r"EdgeInsets\.all\((\d+)\)"), "all"),
    (re.compile(r"EdgeInsets\.fromLTRB\(([^)]*)\)"), "fromLTRB"),
]


def _clamp_spacing(val_str: str) -> str:
    val = int(val_str)
    # Check explicit mapping first
    if val in SPACING_MAP:
        return str(SPACING_MAP[val])
    # Check if already standard
    if val in STANDARD_SPACING:
        return val_str
    # Round to nearest standard
    return str(int(_nearest(float(val), STANDARD_SPACING)))


def fix_spacing_line(line: str, snippet: str | None = None) -> str | None:
    """Fix spacing-grid violations. Return new line or None."""
    new_line = line

    # Handle EdgeInsets.symmetric(horizontal: X, vertical: Y)
    m = re.search(r"EdgeInsets\.symmetric\(horizontal:\s*(\d+),\s*vertical:\s*(\d+)\)", new_line)
    if m:
        h = _clamp_spacing(m.group(1))
        v = _clamp_spacing(m.group(2))
        old = m.group(0)
        new = f"EdgeInsets.symmetric(horizontal: {h}, vertical: {v})"
        new_line = new_line.replace(old, new, 1)
        if new_line != line:
            return new_line

    # Handle EdgeInsets.symmetric(horizontal: X)
    m = re.search(r"EdgeInsets\.symmetric\(horizontal:\s*(\d+)\)", new_line)
    if m:
        h = _clamp_spacing(m.group(1))
        new_line = new_line.replace(m.group(0), f"EdgeInsets.symmetric(horizontal: {h})", 1)
        if new_line != line:
            return new_line

    # Handle EdgeInsets.symmetric(vertical: X)
    m = re.search(r"EdgeInsets\.symmetric\(vertical:\s*(\d+)\)", new_line)
    if m:
        v = _clamp_spacing(m.group(1))
        new_line = new_line.replace(m.group(0), f"EdgeInsets.symmetric(vertical: {v})", 1)
        if new_line != line:
            return new_line

    # Handle EdgeInsets.all(X)
    m = re.search(r"EdgeInsets\.all\((\d+)\)", new_line)
    if m:
        a = _clamp_spacing(m.group(1))
        new_line = new_line.replace(m.group(0), f"EdgeInsets.all({a})", 1)
        if new_line != line:
            return new_line

    # Handle EdgeInsets.only(left: X, top: Y, bottom: Z)
    m = re.search(r"EdgeInsets\.only\(([^)]+)\)", new_line)
    if m:
        inner = m.group(1)
        parts = {}
        for kv in inner.split(","):
            kv = kv.strip()
            if ":" in kv:
                k, v = kv.split(":", 1)
                parts[k.strip()] = v.strip()
        changed = False
        for k, v in parts.items():
            try:
                v_int = int(v)
            except ValueError:
                continue
            clamped = _clamp_spacing(str(v_int))
            if clamped != v:
                parts[k] = clamped
                changed = True
        if changed:
            new_inner = ", ".join(f"{k}: {v}" for k, v in parts.items())
            new_line = new_line.replace(m.group(0), f"EdgeInsets.only({new_inner})", 1)
            if new_line != line:
                return new_line

    # Handle EdgeInsets.fromLTRB(left, top, right, bottom)
    m = re.search(r"EdgeInsets\.fromLTRB\(([^)]+)\)", new_line)
    if m:
        inner = m.group(1)
        vals = [x.strip() for x in inner.split(",")]
        new_vals = []
        changed = False
        for v in vals:
            try:
                v_int = int(v)
                clamped = _clamp_spacing(str(v_int))
                new_vals.append(clamped)
                if clamped != v:
                    changed = True
            except ValueError:
                new_vals.append(v)
        if changed:
            new_inner = ", ".join(new_vals)
            new_line = new_line.replace(m.group(0), f"EdgeInsets.fromLTRB({new_inner})", 1)
            if new_line != line:
                return new_line

    return None


# ─── Color fixes ────────────────────────────────────────────────────────────

_COLORS_WHITE_RE = re.compile(r"(?<!HyperosIcon)Colors\.white\b")
_COLORS_BLACK_RE = re.compile(r"(?<!HyperosIcon)Colors\.black\b")

# Known Colors.xxx → replacement (must check context availability)
_COLOR_NAMED_MAP: dict[str, str] = {
    "Colors.white": "HyperosColors.onPrimary(context)",
    "Colors.black": "HyperosColors.primaryText(context)",
}


def fix_material_colors_line(line: str) -> str | None:
    """Fix no-material-colors violations. Return new line or None."""
    new_line = line

    # Replace Colors.white and Colors.black (with negative lookbehind for HyperosIcon)
    for old_color, new_color in _COLOR_NAMED_MAP.items():
        # Build regex that avoids HyperosIcon prefix
        pat = re.compile(r"(?<!HyperosIcon)" + re.escape(old_color) + r"\b")
        new_line = pat.sub(new_color, new_line)

    return new_line if new_line != line else None


# Hex color → HyperosIconColors mapping for common colors
# Only used for no-hardcoded-color-hex violations
_HEX_TO_ICON: dict[str, str] = {
    "0xFFFF2442": "HyperosIconColors.red",       # Xiaohongshu red
    "0xFF4CAF50": "HyperosIconColors.green",      # Generic green
    "0xFF12B7F5": "HyperosIconColors.blue",       # Generic blue
    "0xFFD1FAE5": "HyperosIconColors.green",      # Light green bg
    "0xFF047857": "HyperosIconColors.green",      # Dark green
    "0xFF4338CA": "HyperosIconColors.indigo",     # Indigo
    "0xFFEEF2FF": "HyperosIconColors.indigo",     # Light indigo bg
    "0xFF0369A1": "HyperosIconColors.blue",       # Dark blue
    "0xFFE0F2FE": "HyperosIconColors.blue",       # Light blue bg
    "0xFF10B981": "HyperosIconColors.green",      # WeChat green
    "0xFF0EA5E9": "HyperosIconColors.blue",       # Generic blue
}

# Hex → HyperosTokens mapping (for non-icon colors)
_HEX_TO_TOKEN: dict[str, str] = {
    "0xFF181717": "HyperosTokens.primaryText",    # Near-black → primary text
    "0xFF1E1E1E": "HyperosTokens.primaryText",    # Dark → primary text
    "0xFF111111": "HyperosTokens.primaryText",    # Near-black → primary text
    "0xFF121212": "HyperosTokens.primaryText",    # Near-black → primary text
    "0xFFFFFFFF": "HyperosTokens.card",           # White → card bg
    "0xFFE8E8E8": "HyperosTokens.secondaryText",  # Light gray → secondary text
    "0x66000000": "",                             # Translucent black → complex, skip
    "0xE6FFFFFF": "",                             # Translucent white → complex, skip
    "0xE6000000": "",                             # Translucent black → complex, skip
    "0x00000000": "",                             # Transparent → skip
}


def fix_hardcoded_hex_color(line: str, snippet: str | None = None) -> str | None:
    """Fix no-hardcoded-color-hex violations. Return new line or None."""
    new_line = line

    for hex_val, replacement in _HEX_TO_TOKEN.items():
        if not replacement:
            continue  # Skip complex entries
        if hex_val in new_line:
            # Only replace in `Color(hex_val)` patterns
            old_pat = f"Color({hex_val})"
            if old_pat in new_line:
                new_line = new_line.replace(old_pat, replacement, 1)
            else:
                old_pat = f"const Color({hex_val})"
                if old_pat in new_line:
                    new_line = new_line.replace(old_pat, replacement, 1)

    for hex_val, replacement in _HEX_TO_ICON.items():
        if hex_val in new_line:
            old_pat = f"Color({hex_val})"
            if old_pat in new_line:
                new_line = new_line.replace(old_pat, replacement, 1)
            else:
                old_pat = f"const Color({hex_val})"
                if old_pat in new_line:
                    new_line = new_line.replace(old_pat, replacement, 1)

    return new_line if new_line != line else None


# ─── Main fix dispatch ──────────────────────────────────────────────────────

def fix_lines(lines: list[str], violations: list[dict]) -> dict[int, tuple[str, str]]:
    """Apply fixes to a list of lines based on violations.

    Returns a dict mapping 1-based line number → (old_line, new_line).
    """
    changes: dict[int, tuple[str, str]] = {}
    rule_handlers = {
        "no-font-bold": fix_typography_line,
        "no-font-w600": fix_typography_line,
        "border-radius-token": fix_radius_line,
        "spacing-grid": fix_spacing_line,
        "no-material-colors": fix_material_colors_line,
        "no-hardcoded-color-hex": fix_hardcoded_hex_color,
    }

    # Group violations by line to process all rules for a given line at once
    line_violations: dict[int, list[dict]] = defaultdict(list)
    for v in violations:
        line_num = v.get("line")
        if line_num is not None and v["rule_id"] in rule_handlers:
            line_violations[line_num].append(v)

    for line_num, file_violations in sorted(line_violations.items()):
        idx = line_num - 1  # 0-based index
        if idx < 0 or idx >= len(lines):
            continue

        line = lines[idx]
        new_line = line

        for v in file_violations:
            handler = rule_handlers.get(v["rule_id"])
            if handler:
                result = handler(new_line)
                if result is not None:
                    new_line = result

        if new_line != line:
            changes[line_num] = (line.rstrip("\n"), new_line.rstrip("\n"))
            lines[idx] = new_line

    return changes


def process_audit(audit_data: dict, dry_run: bool = True) -> int:
    """Process all violations in the audit data. Return total fix count."""
    violations_raw = audit_data.get("violations", [])
    if not violations_raw:
        print("ERROR: No 'violations' key found in audit JSON")
        return 0

    # Group violations by file (excluding protected files)
    file_violations: dict[str, list[dict]] = defaultdict(list)
    for v in violations_raw:
        fname = v.get("file", "")
        if fname in EXCLUDED_FILES:
            continue
        file_violations[fname].append(v)

    total_fixes = 0
    for file_path_rel, viols in sorted(file_violations.items()):
        file_abs = ROOT / file_path_rel
        if not file_abs.exists():
            print(f"  SKIP  {file_path_rel} (not found)")
            continue

        original = file_abs.read_text(encoding="utf-8")
        lines = original.splitlines(keepends=True)

        changes = fix_lines(lines, viols)

        if not changes:
            continue

        total_fixes += len(changes)

        if dry_run:
            print(f"\n  {file_path_rel} ({len(changes)} fix(es)):")
            for line_num, (old, new) in changes.items():
                print(f"    L{line_num}: {old}")
                print(f"        -> {new}")
        else:
            # Write back modified content
            new_content = "".join(lines)
            file_abs.write_text(new_content, encoding="utf-8")
            print(f"  FIXED {file_path_rel} ({len(changes)} fix(es)):")
            for line_num, (old, new) in changes.items():
                print(f"    L{line_num}: {old}")
                print(f"        -> {new}")

    return total_fixes


# ─── CLI ────────────────────────────────────────────────────────────────────

def main() -> None:
    dry_run = "--apply" not in sys.argv

    if not AUDIT_JSON.exists():
        print(
            f"ERROR: Audit output not found at {AUDIT_JSON}\n"
            "Run hyperos_audit.py --json first:\n"
            "  python tool/hyperos_audit.py --json > tool/audit_output.json"
        )
        sys.exit(1)

    audit_data = json.loads(AUDIT_JSON.read_text(encoding="utf-8"))

    print(f"{'DRY RUN' if dry_run else 'APPLYING'} — fixing violations...\n")

    total = process_audit(audit_data, dry_run=dry_run)

    print(f"\n{'─' * 40}")
    print(f"Total fixes: {total}")

    if dry_run:
        print("\nRun with --apply to apply these changes.")
    else:
        print("\nFixes applied. Re-run hyperos_audit.py to verify.")


if __name__ == "__main__":
    main()
