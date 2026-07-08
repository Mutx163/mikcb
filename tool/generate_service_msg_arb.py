#!/usr/bin/env python3
"""Generate serviceMsg* ARB entries from service_message_localizer.dart."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent
LOCALIZER = ROOT / "lib" / "l10n" / "service_message_localizer.dart"
ARB_DIR = ROOT / "lib" / "l10n"

text = LOCALIZER.read_text(encoding="utf-8")

# Simple getters (no parens before semicolon/newline)
getter_names = sorted(
    set(
        re.findall(
            r"return l10n\.(serviceMsg[A-Z][a-zA-Z0-9]*)\s*;",
            text,
        )
    )
)

# Methods: name + args from call sites
method_specs: dict[str, list[str]] = {}
for m in re.finditer(
    r"return l10n\.(serviceMsg[A-Z][a-zA-Z0-9]*)\(([^;]*?)\)\s*;",
    text,
    re.S,
):
    name = m.group(1)
    args_block = m.group(2)
    args = []
    for line in args_block.split("\n"):
        line = line.strip().rstrip(",")
        if not line or line.startswith("_"):
            # infer arg name from helper call
            if "_intArg(resolvedArgs, '" in line:
                args.append(re.search(r"'([^']+)'", line).group(1))
            elif "resolvedArgs['" in line:
                args.append(re.search(r"resolvedArgs\['([^']+)'\]", line).group(1))
            elif "_localizeFieldName" in line:
                if "startField" in line:
                    args.append("startField")
                elif "endField" in line:
                    args.append("endField")
                else:
                    args.append("field")
        elif line.startswith("localizeServiceMessage"):
            args.append("message")
    method_specs[name] = args

def humanize(name: str) -> str:
    s = name.removeprefix("serviceMsg")
    out = []
    for i, ch in enumerate(s):
        if ch.isupper() and i > 0:
            out.append(" ")
        out.append(ch.lower() if i > 0 and s[i - 1].islower() else ch)
    return "".join(out)


def template(name: str, args: list[str], lang: str) -> str:
    if not args:
        return humanize(name)
    ph = " ".join(f"{{{a}}}" for a in args)
    return f"{humanize(name)}: {ph}"


def arb_entry(key: str, value: str, args: list[str]) -> list[str]:
    lines = [f'  "{key}": {json.dumps(value, ensure_ascii=False)}']
    if args:
        meta = {"placeholders": {a: {"type": "int" if a.endswith(
            ("Number", "Week", "Section", "Count", "Index", "Code", "Seconds")
        ) or a in {
            "rowNumber", "startSection", "endSection", "requiredMaxSection",
            "sectionNumber", "sourceWeek", "startWeek", "semesterWeekCount",
            "endWeek", "section", "maxSection", "columnCount", "index",
            "statusCode", "candidatesCount", "stepIndex", "totalSteps",
            "timeoutSeconds", "shiftedWeeks", "calendarWeek",
        } else "String"} for a in args}}
        lines.append(f'  "@{key}": {json.dumps(meta, ensure_ascii=False)}')
    return lines


def append_to_arb(path: Path, entries: list[str]) -> int:
    content = path.read_text(encoding="utf-8")
    added = 0
    new_lines = []
    for block in entries:
        key = block.split('"')[1]
        if re.search(rf'^\s*"{re.escape(key)}"\s*:', content, re.M):
            continue
        new_lines.extend(block.splitlines())
        added += 1
    if not new_lines:
        return 0
    content = content.rstrip()
    if content.endswith("}"):
        content = content[:-1].rstrip()
        if not content.endswith(","):
            content += ","
        content += "\n" + "\n".join(new_lines) + "\n}\n"
    path.write_text(content, encoding="utf-8")
    return added


# Build entries
all_keys = set(getter_names) | set(method_specs)
entries_en = []
for key in sorted(all_keys):
    args = method_specs.get(key, [])
    entries_en.append("\n".join(arb_entry(key, template(key, args, "en"), args)))

locale_files = {
    "zh": "app_zh.arb",
    "en": "app_en.arb",
    "ja": "app_ja.arb",
    "ko": "app_ko.arb",
    "zh_HK": "app_zh_HK.arb",
    "zh_TW": "app_zh_TW.arb",
}

mirror_keys = {
    "appUpdateMirrorPresetGhfast": "ghfast",
    "appUpdateMirrorPresetGhproxyCn": "ghproxy.cn",
    "appUpdateMirrorPresetGhLlkk": "gh.llkk.cc",
    "appUpdateMirrorPresetGhProxyCom": "ghproxy.com",
    "appUpdateMirrorPresetGhproxyNet": "ghproxy.net",
    "appUpdateMirrorPresetCustom": "Custom",
    "appUpdateMirrorPresetCustomDescription": "Enter a custom mirror URL prefix",
}

for locale, fname in locale_files.items():
    extra = []
    for k, v in mirror_keys.items():
        if locale.startswith("zh"):
            zh_v = {
                "appUpdateMirrorPresetGhfast": "ghfast",
                "appUpdateMirrorPresetGhproxyCn": "ghproxy.cn",
                "appUpdateMirrorPresetGhLlkk": "gh.llkk.cc",
                "appUpdateMirrorPresetGhProxyCom": "ghproxy.com",
                "appUpdateMirrorPresetGhproxyNet": "ghproxy.net",
                "appUpdateMirrorPresetCustom": "自定义",
                "appUpdateMirrorPresetCustomDescription": "填写自定义镜像地址前缀",
            }[k]
            extra.append("\n".join(arb_entry(k, zh_v, [])))
        else:
            extra.append("\n".join(arb_entry(k, v, [])))
    n1 = append_to_arb(ARB_DIR / fname, entries_en)
    n2 = append_to_arb(ARB_DIR / fname, extra)
    print(f"{fname}: +{n1} service +{n2} mirror")

print(f"getters={len(getter_names)} methods={len(method_specs)}")
