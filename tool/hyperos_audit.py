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
    lines = text.splitlines()
    for match in rx.finditer(text):
        line = line_number(text, match.start())
        # 注释里提到被禁 API 是「说明」，不是「使用」：文档注释常写
        # 「用 HyperosPageRoute 代替 MaterialPageRoute」，按使用判违规会误报。
        # 与 check_prefer_hyperos_list_view 里对 `//` 行的处理保持一致。
        if line - 1 < len(lines) and lines[line - 1].lstrip().startswith("//"):
            continue
        snippet = lines[line - 1].strip()[:120]
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


def _matching_paren(text: str, open_idx: int) -> int:
    """从 `text[open_idx]` 的 `(` 起找配对的 `)`，返回下标（找不到返回 -1）。"""
    depth = 0
    i = open_idx
    while i < len(text):
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def check_hyperos_colors_usage(text: str, rel: str, rule: dict) -> list[Violation]:
    """逐处检查 `TextStyle(color: ...)` 是否走了 Hyperos 语义色。

    2026-10-27 之前这里是**整文件二值**判定：

        uses_hyperos = "HyperosColors." in text or "HyperosTypography." in text
        if has_text_style_color and not uses_hyperos: -> 报一条

    也就是文件里只要**出现过一次** `HyperosColors.`（哪怕在完全无关的地方），
    整份文件的硬编码颜色就都不报了。一个文件级的洞，谁都能绕。

    现在按**每一处** `TextStyle(color: X)` 判：X 里没有 `Hyperos` 就报一条，
    带行号与表达式。同文件里其它走了 token 的用法不受影响。

    为什么敢收紧：实测全仓含 Hyperos 壳的 76 个文件里 `TextStyle(color:)` 只有
    20 处，其中 14 处非 token、涉及 11 个文件 —— 命中面小到可以逐条看，
    不是那种一开就红几百条的规则。规则本身是 info 级，不参与 --strict 的失败判定。
    """
    if "HyperosSubpage" not in text and "HyperosRootPage" not in text:
        return []

    out: list[Violation] = []
    for match in re.finditer(r"TextStyle\s*\(", text):
        open_idx = match.end() - 1
        close_idx = _matching_paren(text, open_idx)
        if close_idx < 0:
            continue
        body = text[open_idx + 1 : close_idx]
        color_match = re.search(r"\bcolor\s*:\s*([^,)]+)", body)
        if not color_match:
            continue
        expr = color_match.group(1).strip()
        if "Hyperos" in expr:
            continue
        line = line_number(text, open_idx)
        out.append(
            Violation(
                rule_id=rule["id"],
                category=rule["category"],
                severity=rule["severity"],
                message=f"{rule['message']}（本处 `color: {expr}` 未走 Hyperos 语义色）",
                file=rel,
                line=line,
                snippet=expr[:120],
            )
        )
    return out


def check_header_inset_false(text: str, rel: str, rule: dict) -> list[Violation]:
    """Flag `HyperosListView(includeHeaderInset: false)` unless the file also
    proves a fixed-body split layout (the only legal use).

    Overlay pages start content at y=0 behind the frosted title; skipping the
    header inset without a `HyperosBlurredBodyInset` sibling pushes the first
    screen of content INTO the title bar (statistics analysis regression).
    """
    if "includeHeaderInset" not in text:
        return []
    out: list[Violation] = []
    rx = re.compile(r"includeHeaderInset\s*:\s*false", re.MULTILINE)
    has_body_inset = "HyperosBlurredBodyInset" in text
    lines = text.splitlines()
    for match in rx.finditer(text):
        if has_body_inset:
            continue
        line = line_number(text, match.start())
        # Ignore historical warning comments that mention the flag by name.
        if lines[line - 1].lstrip().startswith("//"):
            continue
        out.append(
            Violation(
                rule_id=rule["id"],
                category=rule["category"],
                severity=rule["severity"],
                message=rule["message"],
                file=rel,
                line=line,
                snippet=lines[line - 1].strip()[:120],
            )
        )
    return out


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
        elif check == "header_inset_false":
            violations.extend(check_header_inset_false(text, rel, rule))
        elif check == "switch_subtitle_maxlines_one":
            violations.extend(check_switch_subtitle_maxlines_one(text, rel, rule))
        elif check == "listtile_trailing_checkmark":
            violations.extend(check_listtile_trailing_checkmark(text, rel, rule))
        elif rule.get("pattern"):
            add_pattern_violations(text, rel, rule, violations)

    return FileScan(path=rel, violations=violations)


def skipped_rules_for(entry: dict) -> set[str]:
    """这一页被豁免的规则 id 集合。

    2026-10-27 之前这里读的是 `allowLegacy: true` —— 一个布尔值让整页
    **所有**检查都不生效（`infer_page_status` 直接 return 一个手写状态）。
    那等于「把门禁关掉」，页面上后来新增的任何违规都不会被发现，而 registry
    里看不出它关掉了什么。

    现在改成 `skipRules: [<规则 id>...]`，只豁免点名的规则，其余照查；
    并且必须同时写 `skipReason`，否则算配置错误（见 `registry_problems`）。
    """
    raw = entry.get("skipRules") or []
    if isinstance(raw, str):
        return {raw}
    return {str(x) for x in raw}


def registry_problems(entry: dict) -> list[str]:
    """registry 条目的配置错误（会直接判该页 fail）。

    这几条是**故意判红**的：豁免是门禁上开的洞，必须写清开在哪、为什么。
    不这么写，洞就会悄悄变多。
    """
    problems: list[str] = []
    if entry.get("allowLegacy"):
        problems.append(
            f"`{entry.get('id')}` 还在用 allowLegacy —— 它让整页所有规则都不生效，"
            f"已废弃。改成 `skipRules: [<规则 id>]` + `skipReason: <为什么>`，"
            f"只豁免真正需要豁免的那几条"
        )
    skips = skipped_rules_for(entry)
    if skips and not (entry.get("skipReason") or "").strip():
        problems.append(
            f"`{entry.get('id')}` 声明了 skipRules {sorted(skips)} 但没写 skipReason —— "
            f"豁免必须写明理由，否则下一个人不知道这个洞能不能堵"
        )
    if entry.get("shellException") is not None and not str(
        entry.get("shellException")
    ).strip():
        problems.append(
            f"`{entry.get('id')}` 写了空的 shellException —— "
            f"要豁免壳检查就写明为什么，不豁免就删掉这个字段"
        )
    if entry.get("scanExempt") is not None and not str(
        entry.get("scanExempt")
    ).strip():
        problems.append(
            f"`{entry.get('id')}` 写了空的 scanExempt —— "
            f"要么写明为什么这个文件不进扫描范围，要么把它从 registry 删掉"
        )
    return problems


def infer_page_status(entry: dict, scan: FileScan | None) -> str:
    if registry_problems(entry):
        return "fail"
    if scan is None or not scan.path:
        # 文件不在扫描范围内（被 checklist 的 excludePathFragments 排除）。
        # 2026-10-27 之前这种条目靠 allowLegacy 直接报 pass，等于把「登记了却
        # 根本没查」这件事藏起来。现在要求写明 scanExempt 理由，否则判 fail ——
        # 要么说明白为什么不扫，要么把条目删掉。
        if str(entry.get("scanExempt") or "").strip():
            return entry.get("manualStatus") or "pass"
        return "fail"
    skip = skipped_rules_for(entry)
    expected = entry.get("expectedShell", "HyperosSubpage")
    shell = detect_shell(Path(ROOT / scan.path).read_text(encoding="utf-8"))
    # 壳检查也允许「写明理由的例外」：有些页面（相机取景、二维码全屏）本来就不该
    # 套 HyperosSubpage。但必须写 shellException 说明原因，否则仍判不符。
    shell_ok = shell == expected or bool(
        str(entry.get("shellException") or "").strip()
    )
    # 只滤掉被点名的规则；其余违规照常参与判定。
    effective = [v for v in scan.violations if v.rule_id not in skip]
    errors = [v for v in effective if v.severity == "error"]
    warns = [v for v in effective if v.severity == "warn"]
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
                "skipRules": sorted(skipped_rules_for(entry)),
                "registryProblems": registry_problems(entry),
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
        if not page:
            continue
        # 有配置错误的条目不同步状态：把 inferredStatus=fail 写回 registry 会
        # 让「配置写错了」看起来像「页面不合规」，掩盖真正要改的地方。
        if page.get("registryProblems"):
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
