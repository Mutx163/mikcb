#!/usr/bin/env python3
"""发版前的「本次重点」自检（去 Flutter 化后从 Dart 工具改写而来）。

原工具是 `tool/check_release_highlights.dart`，随 lib/ 一并删除；但它挡的是真事故
（v2.1.4.1 把重点写成「转场掉帧」，解析器认不回任何条目 → 更新弹窗里显示成一条
没有分类标签的灰色重点）。判定口径与 Dart 版一致：

  1. 先看互相包含（条目含重点，或重点含条目的标题）；
  2. 再用中文二字组重合率兜底，阈值 0.34；
  3. 都不中 → 认不回。

用法：
    python3 tool/check_release_highlights.py [notes 路径]
      不传路径时按 android/version.properties 的 versionName 推出 docs/releases/vX.Y.Z[N].md
退出码：0 全部认回；1 有认不回；2 文件不存在。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "android" / "version.properties"

# 正文顶部的 `> 本次重点：A、B、C`
DECLARED_QUOTE = re.compile(r"^(?:本次|这次)?(?:更新|版本)?(?:的)?(?:重点|亮点|看点)\s*[:：]?\s*")
DECLARED_SECTION = re.compile(r"^(?:本次|这次)?(?:更新|版本)?(?:的)?(?:重点|亮点|看点)$")
# 条目行开头的分类前缀，如 `- **新增**：xxx` / `- 修复：xxx`
CATEGORY = re.compile(r"^[\-\*]\s*(?:\*\*)?(?:新增|优化|移除|修复|其他)(?:\*\*)?\s*[:：]?\s*")
THRESHOLD = 0.34


def tag_for_version(version: str) -> str:
    """A.B.C-N+build → vA.B.C.N；A.B.C-0+build → vA.B.C；A.B.C+build → vA.B.C。

    `-0` 分支与 CI 同口径（`android-build.yml:70` 的 `sed -E 's/-0$//; ...'`：
    三位数预发布 `1.3.2-0` 的对外 tag 是 `v1.3.2`，不是 `v1.3.2.0`）。
    """
    without_build = version.split("+")[0]
    if "-" not in without_build:
        return "v" + without_build
    base, fourth = without_build.rsplit("-", 1)
    if fourth == "0":
        return "v" + base
    return f"v{base}.{fourth}"


def read_version() -> str:
    text = VERSION_FILE.read_text(encoding="utf-8")
    for line in text.splitlines():
        if line.startswith("versionName="):
            return line.split("=", 1)[1].strip()
    sys.exit(f"FAIL 读不到 versionName：{VERSION_FILE}")


def split_items(value: str) -> list[str]:
    return [x.strip() for x in re.split(r"[、,，;；|/]", value) if x.strip()]


def bigrams(value: str) -> set[str]:
    return {value[i : i + 2] for i in range(len(value) - 1)}


def similarity(key: str, candidate: str) -> float:
    if not key or not candidate:
        return 0.0
    if key in candidate or candidate in key:
        return 1.0
    grams = bigrams(key)
    if not grams:
        return 0.0
    return len(grams & bigrams(candidate)) / len(grams)


def parse(text: str) -> tuple[list[str], list[str], bool]:
    """返回 (条目标题列表, 声明的重点列表, 是否有「本次重点」声明)。"""
    entries: list[str] = []
    declared: list[str] = []
    in_fence = False
    in_declared_section = False

    for raw in text.splitlines():
        line = raw.rstrip()
        trimmed = line.strip()
        if trimmed.startswith("```") or trimmed.startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        if trimmed.startswith(">"):
            body = trimmed.lstrip("> ").strip()
            m = DECLARED_QUOTE.match(body)
            if m:
                declared.extend(split_items(body[m.end() :]))
            continue

        if trimmed.startswith("#"):
            heading = trimmed.lstrip("#").strip()
            in_declared_section = bool(DECLARED_SECTION.match(heading))
            if in_declared_section:
                declared.append("")  # 占位，小节内的条目稍后补进来
            continue

        # 只认顶格（不缩进）的列表项；缩进的是上一条的细节
        if (line.startswith("- ") or line.startswith("* ")) and line[:1] in {"-", "*"}:
            body = CATEGORY.sub("", line[2:].strip())
            headline = re.split(r"[：:。（(]", body, 1)[0].strip() or body
            entries.append(headline)
            if in_declared_section:
                declared.append(headline)

    declared = [d for d in declared if d]
    return entries, declared, bool(declared)


def main(argv: list[str]) -> int:
    if argv:
        path = Path(argv[0])
    else:
        path = ROOT / "docs" / "releases" / f"{tag_for_version(read_version())}.md"
    if not path.is_file():
        print(f"FAIL 发版说明不存在：{path}", file=sys.stderr)
        return 2

    entries, declared, has_declared = parse(path.read_text(encoding="utf-8"))
    if not has_declared:
        print(f"{path} 没有 `> 本次重点：…` 行：弹窗会退化成按「新增>优化>移除>修复」猜")
        return 0

    unresolved: list[str] = []
    for item in declared:
        best = max((similarity(item, e) for e in entries), default=0.0)
        if best < THRESHOLD:
            unresolved.append(item)

    if not unresolved:
        print(f"「本次重点」{len(declared)} 条全部认回条目：{'、'.join(declared)}")
        return 0

    print("「本次重点」里有认不回条目的说法（会显示成没有分类标签的灰色重点）：", file=sys.stderr)
    for item in unresolved:
        print(f"       「{item}」", file=sys.stderr)
    print(
        "       改法：把简写换成条目里的原话（含其中几个字即可），"
        "例如条目是「转场更顺：进页面时……」就写「转场更顺」。",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
