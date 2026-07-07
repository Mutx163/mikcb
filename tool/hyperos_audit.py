#!/usr/bin/env python3
"""HyperOS page + design-system compliance audit for mikcb.

Registry: docs/reference/hyperos-page-compliance.json
Rules:    docs/reference/hyperos-audit-checklist.yaml
History:  docs/reference/hyperos-audit-user-history.yaml

Usage:
  python tool/hyperos_audit.py                 # full report (all rules)
  python tool/hyperos_audit.py --strict        # exit 1 on severity=error
  python tool/hyperos_audit.py --perfect       # exit 1 on error + warn
  python tool/hyperos_audit.py --history       # user history checklist only
  python tool/hyperos_audit.py --json
  python tool/hyperos_audit.py --sync-status
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = ROOT / "docs/reference/hyperos-page-compliance.json"
CHECKLIST_PATH = ROOT / "docs/reference/hyperos-audit-checklist.yaml"
USER_HISTORY_PATH = ROOT / "docs/reference/hyperos-audit-user-history.yaml"

SHELL_PATTERNS: dict[str, re.Pattern[str]] = {
    "HyperosRootPage": re.compile(r"\bHyperosRootPage\b"),
    "HyperosSubpage": re.compile(r"\bHyperosSubpage\b"),
    "HyperosSheet": re.compile(r"\bHyperosSheet\b|\bshowHyperosSheet\b"),
    "Scaffold": re.compile(r"\bScaffold\s*\("),
}

SEVERITY_ORDER = {"info": 0, "warn": 1, "error": 2}


@dataclass
class Violation:
    rule_id: str
    category: str
    severity: str
    message: str
    file: str
    line: int | None = None
    snippet: str | None = None


@dataclass
class FileScan:
    path: str
    violations: list[Violation] = field(default_factory=list)

    def worst_severity(self) -> str | None:
        if not self.violations:
            return None
        return max(self.violations, key=lambda v: SEVERITY_ORDER[v.severity]).severity


def load_registry() -> dict:
    if not REGISTRY_PATH.exists():
        raise SystemExit(f"Registry missing: {REGISTRY_PATH.relative_to(ROOT)}")
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def load_checklist() -> dict:
    if not CHECKLIST_PATH.exists():
        raise SystemExit(f"Checklist missing: {CHECKLIST_PATH.relative_to(ROOT)}")
    text = CHECKLIST_PATH.read_text(encoding="utf-8")
    if yaml is not None:
        return yaml.safe_load(text)
    raise SystemExit("PyYAML required: pip install pyyaml")


def load_user_history() -> dict:
    if not USER_HISTORY_PATH.exists():
        return {"groups": []}
    text = USER_HISTORY_PATH.read_text(encoding="utf-8")
    if yaml is not None:
        return yaml.safe_load(text) or {"groups": []}
    raise SystemExit("PyYAML required: pip install pyyaml")


def save_registry(data: dict) -> None:
    data["lastPipelineRun"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    REGISTRY_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def iter_audit_files(checklist: dict) -> list[Path]:
    excludes = checklist.get("excludePathFragments", [])
    files: list[Path] = []
    for rel in checklist.get("scanPaths", ["lib/screens", "lib/widgets"]):
        base = ROOT / rel
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.dart")):
            posix = path.as_posix()
            if any(ex in posix for ex in excludes):
                continue
            files.append(path)
    return files


def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def add_pattern_violations(
    text: str,
    rel: str,
    rule: dict,
    violations: list[Violation],
) -> None:
    pattern = rule.get("pattern")
    if not pattern:
        return
    rx = re.compile(pattern)
    for match in rx.finditer(text):
        line = line_number(text, match.start())
        snippet = text.splitlines()[line - 1].strip()[:120]
        violations.append(
            Violation(
                rule_id=rule["id"],
                category=rule["category"],
                severity=rule["severity"],
                message=rule["message"],
                file=rel,
                line=line,
                snippet=snippet,
            )
        )


def check_border_radius_values(text: str, rel: str, rule: dict, tokens: dict) -> list[Violation]:
    allowed = set(tokens.get("allowedBorderRadii", [8, 12, 16, 20, 24, 28]))
    out: list[Violation] = []
    rx = re.compile(r"BorderRadius\.circular\s*\(\s*(\d+(?:\.\d+)?)\s*\)")
    for match in rx.finditer(text):
        value = float(match.group(1))
        if value >= 48:  # pill / stadium / circle
            continue
        if value not in allowed:
            line = line_number(text, match.start())
            out.append(
                Violation(
                    rule_id=rule["id"],
                    category=rule["category"],
                    severity=rule["severity"],
                    message=f"{rule['message']} (found {value})",
                    file=rel,
                    line=line,
                    snippet=text.splitlines()[line - 1].strip()[:120],
                )
            )
    return out


def check_prefer_hyperos_list_view(text: str, rel: str, rule: dict) -> list[Violation]:
    if "HyperosSubpage" not in text:
        return []
    if "HyperosListView" in text:
        return []
    if re.search(r"\bListView\s*\(", text) or re.search(r"\bCustomScrollView\s*\(", text):
        return [
            Violation(
                rule_id=rule["id"],
                category=rule["category"],
                severity=rule["severity"],
                message=rule["message"],
                file=rel,
            )
        ]
    return []


def check_prefer_list_group(text: str, rel: str, rule: dict) -> list[Violation]:
    tile_count = len(re.findall(r"\bHyperosListTile\s*\(", text))
    group_count = len(re.findall(r"\bHyperosListGroup\s*\(", text))
    if tile_count >= 2 and group_count == 0:
        return [
            Violation(
                rule_id=rule["id"],
                category=rule["category"],
                severity=rule["severity"],
                message=rule["message"],
                file=rel,
            )
        ]
    return []


def check_edge_insets_grid(text: str, rel: str, rule: dict, tokens: dict) -> list[Violation]:
    allowed = set(tokens.get("allowedSpacing", []))
    out: list[Violation] = []
    rx = re.compile(
        r"EdgeInsets\.(?:all|symmetric|only)\([^)]*?(?:horizontal|left|right)\s*:\s*(\d+(?:\.\d+)?)"
    )
    for match in rx.finditer(text):
        value = float(match.group(1))
        if value not in allowed and value not in (0,):
            line = line_number(text, match.start())
            out.append(
                Violation(
                    rule_id=rule["id"],
                    category=rule["category"],
                    severity=rule["severity"],
                    message=f"{rule['message']} (horizontal {value})",
                    file=rel,
                    line=line,
                    snippet=text.splitlines()[line - 1].strip()[:120],
                )
            )
    return out


def check_hyperos_colors_usage(text: str, rel: str, rule: dict) -> list[Violation]:
    if "HyperosSubpage" not in text and "HyperosRootPage" not in text:
        return []
    has_text_style_color = bool(re.search(r"TextStyle\s*\([^)]*color\s*:", text))
    uses_hyperos = "HyperosColors." in text or "HyperosTypography." in text
    if has_text_style_color and not uses_hyperos:
        return [
            Violation(
                rule_id=rule["id"],
                category=rule["category"],
                severity=rule["severity"],
                message=rule["message"],
                file=rel,
            )
        ]
    return []


def check_switch_subtitle_maxlines_one(text: str, rel: str, rule: dict) -> list[Violation]:
    out: list[Violation] = []
    rx = re.compile(r"HyperosSwitchTile\s*\(", re.MULTILINE)
    for match in rx.finditer(text):
        start = match.start()
        end = min(len(text), start + 1200)
        block = text[start:end]
        if re.search(r"maxLines\s*:\s*1", block):
            line = line_number(text, start)
            out.append(
                Violation(
                    rule_id=rule["id"],
                    category=rule["category"],
                    severity=rule["severity"],
                    message=rule["message"],
                    file=rel,
                    line=line,
                )
            )
    return out


def check_listtile_trailing_checkmark(text: str, rel: str, rule: dict) -> list[Violation]:
    out: list[Violation] = []
    rx = re.compile(r"HyperosListTile\s*\(", re.MULTILINE)
    for match in rx.finditer(text):
        start = match.start()
        end = min(len(text), start + 800)
        block = text[start:end]
        if re.search(r"trailing\s*:", block) and re.search(
            r"(Icons\.check|HyperosSelectedCheckmark|Icon\s*\(\s*Icons\.check)",
            block,
        ):
            line = line_number(text, start)
            out.append(
                Violation(
                    rule_id=rule["id"],
                    category=rule["category"],
                    severity=rule["severity"],
                    message=rule["message"],
                    file=rel,
                    line=line,
                )
            )
    return out


def detect_shell(text: str) -> str:
    for name in ("HyperosRootPage", "HyperosSubpage", "HyperosSheet", "Scaffold"):
        if SHELL_PATTERNS[name].search(text):
            return name
    return "none"


def scan_file(path: Path, checklist: dict) -> FileScan:
    rel = path.relative_to(ROOT).as_posix()
    text = path.read_text(encoding="utf-8")
    tokens = checklist.get("tokens", {})
    violations: list[Violation] = []

    for rule in checklist.get("rules", []):
        if rule.get("manual"):
            continue
        check = rule.get("check")
        if check == "border_radius_values":
            violations.extend(check_border_radius_values(text, rel, rule, tokens))
        elif check == "prefer_hyperos_list_view":
            violations.extend(check_prefer_hyperos_list_view(text, rel, rule))
        elif check == "prefer_list_group":
            violations.extend(check_prefer_list_group(text, rel, rule))
        elif check == "edge_insets_grid":
            violations.extend(check_edge_insets_grid(text, rel, rule, tokens))
        elif check == "hyperos_colors_usage":
            violations.extend(check_hyperos_colors_usage(text, rel, rule))
        elif check == "switch_subtitle_maxlines_one":
            violations.extend(check_switch_subtitle_maxlines_one(text, rel, rule))
        elif check == "listtile_trailing_checkmark":
            violations.extend(check_listtile_trailing_checkmark(text, rel, rule))
        elif rule.get("pattern"):
            add_pattern_violations(text, rel, rule, violations)

    return FileScan(path=rel, violations=violations)


def infer_page_status(entry: dict, scan: FileScan | None) -> str:
    if entry.get("allowLegacy"):
        return entry.get("manualStatus", "pass")
    if scan is None or not scan.path:
        return "fail"
    expected = entry.get("expectedShell", "HyperosSubpage")
    shell = detect_shell(Path(ROOT / scan.path).read_text(encoding="utf-8"))
    shell_ok = shell == expected
    errors = [v for v in scan.violations if v.severity == "error"]
    warns = [v for v in scan.violations if v.severity == "warn"]
    if errors:
        return "fail"
    if not shell_ok:
        return "partial" if shell != "none" else "fail"
    if warns:
        return "partial"
    return "pass"


def audit_all(checklist: dict, registry: dict, user_history: dict | None = None) -> dict[str, Any]:
    files = iter_audit_files(checklist)
    scans = {scan.path: scan for scan in (scan_file(p, checklist) for p in files)}

    pages: list[dict] = []
    for entry in registry.get("pages", []):
        scan = scans.get(entry["file"])
        pages.append(
            {
                "id": entry["id"],
                "label": entry.get("label", entry["id"]),
                "file": entry["file"],
                "manualStatus": entry.get("manualStatus"),
                "inferredStatus": infer_page_status(entry, scan),
                "detectedShell": detect_shell(
                    (ROOT / entry["file"]).read_text(encoding="utf-8")
                )
                if (ROOT / entry["file"]).exists()
                else "missing",
                "allowLegacy": entry.get("allowLegacy", False),
            }
        )

    all_violations = [v for s in scans.values() for v in s.violations]
    manual_rules = [r for r in checklist.get("rules", []) if r.get("manual")]

    by_category: dict[str, list[Violation]] = {}
    for v in all_violations:
        by_category.setdefault(v.category, []).append(v)

    by_severity = {"error": 0, "warn": 0, "info": 0}
    for v in all_violations:
        by_severity[v.severity] = by_severity.get(v.severity, 0) + 1

    return {
        "pages": pages,
        "filesScanned": len(scans),
        "violations": [v.__dict__ for v in all_violations],
        "summary": {
            "errors": by_severity.get("error", 0),
            "warns": by_severity.get("warn", 0),
            "infos": by_severity.get("info", 0),
            "manualRules": len(manual_rules),
            "pagesPass": sum(1 for p in pages if p["inferredStatus"] == "pass"),
            "pagesPartial": sum(1 for p in pages if p["inferredStatus"] == "partial"),
            "pagesFail": sum(1 for p in pages if p["inferredStatus"] == "fail"),
        },
        "byCategory": {
            cat: len(vs) for cat, vs in by_category.items()
        },
        "manualRules": manual_rules,
        "categories": checklist.get("categories", []),
        "userHistory": build_user_history_report(
            user_history or {"groups": []},
            registry,
            all_violations,
            scans,
        ),
    }


def page_id_to_files(registry: dict) -> dict[str, str]:
    return {entry["id"]: entry["file"] for entry in registry.get("pages", [])}


def resolve_history_scope_files(item: dict, registry: dict) -> list[str]:
    files: list[str] = []
    id_map = page_id_to_files(registry)
    for page in item.get("pages", []) or []:
        if isinstance(page, str) and page in id_map:
            files.append(id_map[page])
    for path in item.get("files", []) or []:
        if isinstance(path, str):
            files.append(path)
    return sorted(set(files))


def violations_for_scope(
    violations: list[Violation],
    scope_files: list[str],
    rule_id: str | None = None,
) -> list[Violation]:
    scoped = [v for v in violations if v.file in scope_files]
    if rule_id:
        scoped = [v for v in scoped if v.rule_id == rule_id]
    return scoped


def pattern_hits_in_scope(
    pattern: str,
    scope_files: list[str],
    scans: dict[str, FileScan],
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    rx = re.compile(pattern)
    for rel in scope_files:
        scan = scans.get(rel)
        if scan is None:
            path = ROOT / rel
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8")
        else:
            path = ROOT / rel
            text = path.read_text(encoding="utf-8")
        for match in rx.finditer(text):
            line = line_number(text, match.start())
            hits.append({"file": rel, "line": line})
    return hits


def build_user_history_report(
    user_history: dict,
    registry: dict,
    all_violations: list[Violation],
    scans: dict[str, FileScan],
) -> dict[str, Any]:
    items_out: list[dict[str, Any]] = []
    auto_pass = auto_fail = manual = 0

    for group in user_history.get("groups", []):
        for item in group.get("items", []):
            scope = resolve_history_scope_files(item, registry)
            status = "manual"
            detail: str | None = None
            hits: list[dict[str, Any]] = []

            if item.get("manual") and not item.get("auditRule") and not item.get("pattern"):
                manual += 1
            elif item.get("auditRule"):
                scoped = violations_for_scope(
                    all_violations, scope, item["auditRule"]
                )
                if scoped:
                    status = "fail"
                    auto_fail += 1
                    detail = f"{len(scoped)} violation(s) [{item['auditRule']}]"
                    hits = [
                        {"file": v.file, "line": v.line, "rule": v.rule_id}
                        for v in scoped[:5]
                    ]
                else:
                    status = "pass"
                    auto_pass += 1
            elif item.get("pattern"):
                hits = pattern_hits_in_scope(item["pattern"], scope, scans)
                if hits:
                    status = "fail"
                    auto_fail += 1
                    detail = f"pattern match x{len(hits)}"
                else:
                    status = "pass"
                    auto_pass += 1
            else:
                manual += 1

            items_out.append(
                {
                    "id": item.get("id"),
                    "group": group.get("label"),
                    "userAsk": item.get("userAsk"),
                    "compliant": item.get("compliant"),
                    "status": status,
                    "detail": detail,
                    "scopeFiles": scope,
                    "hits": hits,
                    "manual": bool(item.get("manual")),
                    "spec": item.get("spec"),
                    "verifyTest": item.get("verifyTest"),
                }
            )

    return {
        "total": len(items_out),
        "autoPass": auto_pass,
        "autoFail": auto_fail,
        "manual": manual,
        "items": items_out,
    }


def print_user_history_report(history: dict[str, Any]) -> None:
    print("=== 用户历史修改要求核对（对话提炼）===")
    print(
        f"共 {history['total']} 条 | "
        f"自动通过 {history['autoPass']} | "
        f"自动失败 {history['autoFail']} | "
        f"需人工 {history['manual']}"
    )
    print(f"来源: {USER_HISTORY_PATH.relative_to(ROOT)}")
    print()

    current_group: str | None = None
    for item in history.get("items", []):
        group = item.get("group") or ""
        if group != current_group:
            current_group = group
            print(f"## {group}")
        mark = {"pass": "OK", "fail": "FAIL", "manual": "MANUAL"}.get(item["status"], "?")
        print(f"  [{mark}] {item['id']}")
        print(f"      用户要求: {item.get('userAsk', '')}")
        print(f"      合规做法: {item.get('compliant', '')}")
        if item.get("detail"):
            print(f"      检测: {item['detail']}")
            for hit in item.get("hits", [])[:3]:
                loc = f":{hit['line']}" if hit.get("line") else ""
                print(f"        - {hit['file']}{loc}")
        elif item["status"] == "manual":
            extra = item.get("spec") or item.get("verifyTest") or "真机/Agent 必查"
            print(f"      检测: 人工 — {extra}")
        print()


def print_human_report(result: dict[str, Any], history_only: bool = False) -> None:
    if history_only:
        print_user_history_report(result.get("userHistory", {}))
        return
    summary = result["summary"]
    print("HyperOS 澎湃 UI 完整审计")
    print(f"Registry: {REGISTRY_PATH.relative_to(ROOT)}")
    print(f"Checklist: {CHECKLIST_PATH.relative_to(ROOT)}")
    print(
        f"Files scanned: {result['filesScanned']} | "
        f"errors={summary['errors']} warn={summary['warns']} info={summary['infos']} | "
        f"manual rules={summary['manualRules']}"
    )
    print(
        f"Pages: pass={summary['pagesPass']} "
        f"partial={summary['pagesPartial']} fail={summary['pagesFail']}"
    )
    print()

    if result["byCategory"]:
        print("按类别违规计数:")
        cat_labels = {c["id"]: c["label"] for c in result.get("categories", [])}
        for cat, count in sorted(result["byCategory"].items(), key=lambda x: -x[1]):
            label = cat_labels.get(cat, cat)
            print(f"  - {label} ({cat}): {count}")
        print()

    print(f"{'状态':<8} {'页面':<14} {'壳层':<16} 文件")
    print("-" * 72)
    for page in result["pages"]:
        print(
            f"{page['inferredStatus']:<8} {page['label']:<14} "
            f"{page['detectedShell']:<16} {page['file']}"
        )

    errors = [v for v in result["violations"] if v["severity"] == "error"]
    warns = [v for v in result["violations"] if v["severity"] == "warn"]

    if errors:
        print("\n=== ERROR（--strict 失败）===")
        for v in errors[:40]:
            loc = f":{v['line']}" if v.get("line") else ""
            print(f"  [{v['rule_id']}] {v['file']}{loc} — {v['message']}")
        if len(errors) > 40:
            print(f"  ... +{len(errors) - 40} more")

    if warns:
        print("\n=== WARN（--perfect 失败）===")
        for v in warns[:40]:
            loc = f":{v['line']}" if v.get("line") else ""
            print(f"  [{v['rule_id']}] {v['file']}{loc} — {v['message']}")
        if len(warns) > 40:
            print(f"  ... +{len(warns) - 40} more")

    if result.get("manualRules"):
        print("\n=== 需人工/真机核对（完美合规必查）===")
        for rule in result["manualRules"]:
            print(f"  - [{rule['id']}] {rule['message']}")

    if result.get("userHistory"):
        print()
        print_user_history_report(result["userHistory"])


def sync_registry_status(registry: dict, result: dict[str, Any]) -> None:
    by_file = {p["file"]: p for p in result["pages"]}
    for entry in registry.get("pages", []):
        page = by_file.get(entry["file"])
        if not page or entry.get("allowLegacy"):
            continue
        entry["manualStatus"] = page["inferredStatus"]


def should_fail(result: dict[str, Any], strict: bool, perfect: bool) -> bool:
    summary = result["summary"]
    if perfect:
        return summary["errors"] > 0 or summary["warns"] > 0
    if strict:
        return summary["errors"] > 0
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="HyperOS full design-system audit")
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail on severity=error (CI default gate)",
    )
    parser.add_argument(
        "--perfect",
        action="store_true",
        help="Fail on error + warn — 严格完美澎湃 UI 合规",
    )
    parser.add_argument("--sync-status", action="store_true")
    parser.add_argument(
        "--history",
        action="store_true",
        help="Print user history checklist only (from past UI fix conversations)",
    )
    args = parser.parse_args()

    registry = load_registry()
    checklist = load_checklist()
    user_history = load_user_history()
    result = audit_all(checklist, registry, user_history)

    if args.sync_status:
        sync_registry_status(registry, result)
        save_registry(registry)

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print_human_report(result, history_only=args.history)

    if should_fail(result, args.strict, args.perfect):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
