#!/usr/bin/env python3
"""
Precise line-level color fixer for HyperOS audit violations.
Reads violations from audit JSON, matches by line number, applies safe fixes.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# ── Safe fixes: line_prefix → full_line_replacement ──
# key is matched as substring of the line; if found, the ENTIRE line is replaced.
LINE_FIXES: list[tuple[str, str]] = [
    # White → onPrimary/card
    (r'^\s*color:\s*Colors\.white,\s*$', '            color: HyperosColors.onPrimary(context),'),
    (r'^\s*backgroundColor:\s*Colors\.white,\s*$', '            backgroundColor: HyperosColors.card(context),'),
    (r'^\s*color:\s*Colors\.black,\s*$', '            color: HyperosColors.primaryText(context),'),

    # About screen
    (r'color:\s*Colors\.black\.withValues\(alpha:\s*0\.06\),\s*$', '          color: HyperosColors.outline(context).withValues(alpha: 0.3),'),
    (r'Colors\.green\.withValues\(alpha:\s*0\.12\),\s*$', '          HyperosIconColors.green.withValues(alpha: 0.12),'),
    (r'^\s*Colors\.green,\s*$', '          HyperosIconColors.green,'),

    # Add course
    (r'const\s+Color\(0xFF2196F3\)\s*\)', 'HyperosIconColors.blue)'),
    (r'child:\s*const\s+Icon\(Icons\.check,\s+size:\s*16,\s*color:\s*Colors\.white\)\s*$', '          child: Icon(Icons.check, size: 16, color: HyperosColors.onPrimary(context)),'),
    (r'\?\s*const\s+Icon\(Icons\.check,\s+size:\s*16,\s*color:\s*Colors\.white\)\s*$', '          ? Icon(Icons.check, size: 16, color: HyperosColors.onPrimary(context))'),

    # Add schedule
    (r'Color\(0xFF2196F3\)', 'HyperosIconColors.blue'),
    (r'\?\s*const\s+Icon\(Icons\.check,\s+size:\s*16,\s*color:\s*Colors\.white\)\s*$', '          ? Icon(Icons.check, size: 16, color: HyperosColors.onPrimary(context))'),

    # Settings appearance
    (r'^\s*color:\s*Colors\.white,$', '                                  color: HyperosColors.onPrimary(context),'),

    # Settings live
    (r'Colors\.green\s*$', 'HyperosIconColors.green'),
    (r'Colors\.orange\s*$', 'HyperosIconColors.orange'),

    # Settings timetable page
    (r'color:\s*Colors\.white\)\s*$', 'color: HyperosColors.onPrimary(context)),'),

    # Exam list
    (r'Color\(0xFF000000\)', 'HyperosColors.primaryText(context)'),

    # Week selector
    (r'Color\(0xFFE8E8E8\)', 'HyperosMiuixLightColors.surfaceContainerHigh'),

    # Couple timetable settings
    (r'fallback:\s*Colors\.blue\)\s*;', 'fallback: HyperosIconColors.blue);'),

    # Live settings subpages
    (r'Color\(0xFF2563EB\)', 'HyperosIconColors.blue'),

    # Timetable settings
    (r'Color\(0xFF2563EB\)', 'HyperosIconColors.blue'),
    (r'color:\s*Colors\.white\)', 'color: HyperosColors.onPrimary(context))'),

    # Course color picker
    (r'Color\(0xFF2196F3\)', 'HyperosIconColors.blue'),

    # Timetable text color settings
    (r'Color\(0xFF000000\)', 'HyperosColors.primaryText(context)'),

    # Week preview
    (r'shadowColor:\s*Colors\.black\.withValues\(', 'shadowColor: HyperosColors.primaryText(context).withValues('),
    (r'themeFallback:\s*isDark\s*\?\s*Colors\.white\s*:\s*Colors\.grey\.shade\d+,', 'themeFallback: isDark ? HyperosColors.onPrimary(context) : HyperosColors.secondaryText(context),'),
]

# Files whose colors are dynamic (course/chart) → skip entirely
SKIP_FILES = {
    'lib/screens/timetable_screen.dart',
    'lib/widgets/course_card.dart',
    'lib/widgets/course_surface.dart',
    'lib/widgets/home_page_region_blur.dart',
    'lib/widgets/warehouse_playback_overlay.dart',
    'lib/widgets/app_boot_branding.dart',  # splash screen, platform colors
    'lib/screens/lan_edit_screen.dart',    # QR code, needs pure white/black
    'lib/widgets/miuix_date_picker_sheet.dart',  # Miuix overlay
    'lib/screens/about_screen.dart',  # complex, handle later
    'lib/widgets/statistics/statistics_export_brand_footer.dart',  # export doc
    'lib/widgets/timetable_week_preview.dart',  # complex scrollbar colors
    'lib/widgets/statistics/statistics_export_course_ranking.dart',  # export doc
}


def apply_fixes(path: str, violations=None) -> tuple[int, int]:
    """Apply fixes to file. Returns (fixed_count, skipped_count)."""
    fpath = ROOT / path
    if not fpath.exists():
        return 0, 0

    text = fpath.read_text(encoding='utf-8')
    lines = text.split('\n')
    fixed = 0
    modified_lines = set()

    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()

        for pattern, replacement in LINE_FIXES:
            if re.search(pattern, line):
                if lineno in modified_lines:
                    continue
                # Build replacement preserving indentation
                indent = line[:len(line) - len(line.lstrip())]
                new_line = replacement
                if not new_line.startswith(indent) and indent:
                    new_line = indent + new_line.lstrip()
                lines[lineno - 1] = new_line
                modified_lines.add(lineno)
                fixed += 1
                break

    if fixed > 0:
        new_text = '\n'.join(lines)
        fpath.write_text(new_text, encoding='utf-8')

    return fixed, len([v for v in (violations or []) if v.get('line', 0) not in modified_lines])


def load_audit() -> dict:
    result = subprocess.run(
        [sys.executable, 'tool/hyperos_audit.py', '--json'],
        capture_output=True, text=True, cwd=ROOT,
    )
    return json.loads(result.stdout)


def main():
    dry_run = '--dry-run' in sys.argv
    apply = '--apply' in sys.argv

    if not apply:
        print('Dry-run mode. Use --apply to execute.')
        print('=' * 60)

    audit = load_audit()
    violations = audit['violations']
    color_v = [v for v in violations if v['rule_id'] in ('no-material-colors', 'no-hardcoded-color-hex')]

    by_file = defaultdict(list)
    for v in color_v:
        by_file[v['file']].append(v)

    total_fixed = 0
    total_skipped = 0

    for rel_path, vlist in sorted(by_file.items(), key=lambda x: -len(x[1])):
        if rel_path in SKIP_FILES:
            print(f'  SKIP {rel_path} ({len(vlist)} violations — dynamic colors)')
            total_skipped += len(vlist)
            continue

        if apply:
            fixed, skipped = apply_fixes(rel_path, vlist)
            if fixed:
                print(f'  FIX  {rel_path}: {fixed} fixed, {skipped} remaining')
            else:
                print(f'  ?    {rel_path}: 0 fixed ({len(vlist)} violations — manual review needed)')
            total_fixed += fixed
            total_skipped += skipped
        else:
            print(f'  {len(vlist):>3}  {rel_path}')

    print(f'\nTotal: fixed={total_fixed} skipped={total_skipped}')


if __name__ == '__main__':
    main()
