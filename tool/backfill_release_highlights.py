#!/usr/bin/env python3
"""为历史版本更新日志补一行「本次重点」。

背景：从 v2.1.3.3 起，发布说明顶部会写

    > 本次重点：桌面小组件「效果预览」、小组件周末文案

App 的更新弹窗、历史版本页、官网与 GitHub Release 都靠这一行判断「这版想让人看
到什么」。100 多个历史版本没有这一行，只能按「新增 > 优化 > 移除 > 修复」猜。

本脚本按同一套规则，从每个版本自己的条目里挑至多 3 条，把这一行补在版本标题
下面。它**只加摘要行**，不动任何功能条目——`docs/RELEASE.md` 里「已发布版本禁止
追加功能条目」的规则仍然有效。

用法：
    python tool/backfill_release_highlights.py --dry-run   # 只打印将要写入的行
    python tool/backfill_release_highlights.py             # 实际写入
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RELEASES = ROOT / "docs" / "releases"

HEADING = re.compile(r"^#{1,6}\s+")
BULLET = re.compile(r"^[-*+]\s+(.+)$")
MARKER = re.compile(r"\*\*|__|~~|`")
LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
HEADLINE_STOP = re.compile(r"[：:；;。！!？?]")
LEADING_SEP = re.compile(r"^[\s:：\-—–~·、,，]+")
CLAIMED = re.compile(r"^>\s*(?:\*\*)?本次重点")

PREFIXES = (
    ("新增功能", "added"),
    ("新增", "added"),
    ("增加", "added"),
    ("优化", "improved"),
    ("改进", "improved"),
    ("改善", "improved"),
    ("修复", "fixed"),
    ("修正", "fixed"),
    ("移除", "removed"),
    ("删除", "removed"),
    ("下线", "removed"),
)
ENGLISH = re.compile(
    r"^(new|add|adds|added|feature|features|improve|improved|improves|enhance|enhanced|optimize|optimized|fix|fixes|fixed|remove|removes|removed|deprecate|deprecated)\b",
    re.IGNORECASE,
)
SECTION_KIND = {
    "新增": "added",
    "优化": "improved",
    "修复": "fixed",
    "移除": "removed",
}
PRIORITY = ("added", "improved", "removed", "fixed", "other")
MAX_HIGHLIGHTS = 3
MAX_HEADLINE_RUNES = 40


def clean(text: str) -> str:
    text = LINK.sub(r"\1", text)
    text = MARKER.sub("", text)
    return re.sub(r"\s+", " ", text).strip()


def headline_of(text: str) -> str:
    match = HEADLINE_STOP.search(text)
    headline = (text[: match.start()] if match else text).strip() or text.strip()
    if len(headline) > MAX_HEADLINE_RUNES:
        headline = headline[:MAX_HEADLINE_RUNES] + "…"
    return headline


def strip_separators(text: str) -> str:
    return LEADING_SEP.sub("", text).strip()


def entry_from_bullet(raw: str, section_kind: str | None) -> tuple[str, str]:
    text = clean(raw)
    kind = "other"
    rest = text
    for keyword, resolved in PREFIXES:
        if rest.startswith(keyword) and len(rest) > len(keyword):
            kind = resolved
            rest = rest[len(keyword):]
            break
    if kind == "other":
        match = ENGLISH.match(rest)
        if match and len(rest) > match.end():
            kind = {
                "new": "added", "add": "added", "adds": "added", "added": "added",
                "feature": "added", "features": "added",
                "improve": "improved", "improved": "improved", "improves": "improved",
                "enhance": "improved", "enhanced": "improved",
                "optimize": "improved", "optimized": "improved",
                "fix": "fixed", "fixes": "fixed", "fixed": "fixed",
                "remove": "removed", "removes": "removed", "removed": "removed",
                "deprecate": "removed", "deprecated": "removed",
            }[match.group(1).lower()]
            rest = rest[match.end():]
    if kind == "other" and section_kind:
        kind = section_kind
    return kind, strip_separators(rest) or text


def kind_from_heading(line: str) -> str | None:
    text = HEADING.sub("", line).strip()
    text = MARKER.sub("", text)
    text = re.sub(r"^[^A-Za-z0-9\u4e00-\u9fff]+", "", text)
    for keyword, resolved in SECTION_KIND.items():
        if text.startswith(keyword):
            return resolved
    if ENGLISH.match(text):
        word = ENGLISH.match(text).group(1).lower()  # type: ignore[union-attr]
        return {
            "new": "added", "add": "added", "adds": "added", "added": "added",
            "feature": "added", "features": "added",
            "improve": "improved", "improved": "improved", "improves": "improved",
            "enhance": "improved", "enhanced": "improved",
            "optimize": "improved", "optimized": "improved",
            "fix": "fixed", "fixes": "fixed", "fixed": "fixed",
            "remove": "removed", "removes": "removed", "removed": "removed",
            "deprecate": "removed", "deprecated": "removed",
        }[word]
    return None


def parse_entries(text: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    section_kind: str | None = None
    for line in text.splitlines():
        if HEADING.match(line):
            section_kind = kind_from_heading(line)
            continue
        match = BULLET.match(line)
        if not match:
            continue
        entries.append(entry_from_bullet(match.group(1), section_kind))
    return entries


def pick_highlights(entries: list[tuple[str, str]]) -> list[str]:
    picked: list[str] = []
    seen: set[str] = set()
    for kind in PRIORITY:
        for entry_kind, text in entries:
            if entry_kind != kind:
                continue
            headline = headline_of(text)
            if not headline or headline in seen:
                continue
            picked.append(headline)
            seen.add(headline)
            if len(picked) >= MAX_HIGHLIGHTS:
                return picked
    return picked


def insert_line(text: str, line: str) -> str:
    lines = text.splitlines()
    heading_index = next(
        (index for index, value in enumerate(lines) if value.startswith("#")),
        None,
    )
    if heading_index is None:
        raise ValueError("找不到版本标题")
    # 标题后先空一行，再放摘要，再空一行接正文；已有的空行不重复。
    tail = lines[heading_index + 1:]
    while tail and not tail[0].strip():
        tail.pop(0)
    rebuilt = lines[: heading_index + 1] + ["", line, ""] + tail
    return "\n".join(rebuilt).rstrip("\n") + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="只处理最新的 N 个文件")
    args = parser.parse_args()

    files = sorted(RELEASES.glob("v*.md"))
    if args.limit:
        files = files[-args.limit:]

    changed = skipped_claimed = skipped_empty = skipped_no_heading = 0
    for path in files:
        text = path.read_text(encoding="utf-8")
        if any(CLAIMED.match(line) for line in text.splitlines()):
            skipped_claimed += 1
            continue
        entries = parse_entries(text)
        if not entries:
            skipped_empty += 1
            continue
        highlights = pick_highlights(entries)
        if not highlights:
            skipped_empty += 1
            continue
        line = "> 本次重点：" + "、".join(highlights)
        try:
            rewritten = insert_line(text, line)
        except ValueError:
            # 个别老文件没有 `# 版本号` 标题（v1.2.1.4 直接从条目开始）。
            # 不替它编一个标题，保持原样跳过。
            print(f"跳过（无版本标题）：{path.name}")
            skipped_no_heading += 1
            continue
        if not text.endswith("\n"):
            # 原文件末尾没有换行就保持原样，避免整份文件被记成「最后一行改动」。
            rewritten = rewritten.rstrip("\n")
        if args.dry_run:
            print(f"{path.name}: {line}")
        else:
            path.write_text(rewritten, encoding="utf-8", newline="\n")
        changed += 1

    print(
        f"处理 {len(files)} 个文件：写入 {changed}，已有重点 {skipped_claimed}，"
        f"无可提取条目 {skipped_empty}，无版本标题 {skipped_no_heading}"
        + ("（dry-run，未写入）" if args.dry_run else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
