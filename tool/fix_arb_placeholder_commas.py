#!/usr/bin/env python3
"""删除 ARB 里**多余的尾逗号**（JSON 不允许逗号后直接闭合）。

用法：
    python tool/fix_arb_placeholder_commas.py            # 只检查，不写盘
    python tool/fix_arb_placeholder_commas.py --write    # 真删尾逗号（带校验）
    python tool/fix_arb_placeholder_commas.py --file X   # 只处理一个文件

判定规则（只有这一条）：
    某行的最后一个非空白字符是 `,`，且**下一个非空行**以 `}` 或 `]` 开头
    → 这个逗号是多余的，删掉。

为什么要重写成这样（2026-10-27）：

上一版按两条行内匹配删逗号：

    if '{ "type": "String" },' in line:        # 规则 1
    if line.strip() == '},' and 上一行 == '}': # 规则 2

两条都是错的——它们删掉的是**必需的分隔逗号**：

* 规则 1 把 `"delta": { "type": "String" },` 的逗号删了，而下一行是
  `"busiestDay"`，于是两个键之间没有分隔符；
* 规则 2 把嵌套对象闭合处的 `},` 变成 `}`，而下一行常常就是下一个顶层键。

实测后果：对 6 份 ARB 各命中 411~446 处规则 2，全部变成非法 JSON；
`json.load` 报 `Expecting ',' delimiter`，`gen-l10n` 失败、App 编译不过。

因此本版加了两道闸：

1. **只删真正多余的逗号**（逗号后紧跟闭合括号），必需的分隔逗号一律不动；
2. **写盘前强制 `json.loads` 校验**：任何一份改完不合法，就整份放弃、
   原文件一个字节都不动，并以非 0 退出码报告。

ARB 的 JSON 合法性另有守卫：`test/l10n/arb_cross_locale_test.dart` 会
`jsonDecode` 六份文件，CI 里 `flutter test` 会拦下非法 JSON。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Windows 控制台默认 GBK，直接 print 中文会变乱码（2026-10-27 实测：同一段
# 输出在 cmd 里读不出来，害得「改了 446 处」这种关键数字没人看得到）。
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):  # 老 Python / 被重定向到非文本流
    pass

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"


def strip_trailing_commas(text: str) -> tuple[str, list[int]]:
    """删掉「逗号后紧跟闭合括号」的那些逗号，返回 (新文本, 命中行号列表)。"""
    lines = text.splitlines()

    # 先记录每个非空行后面第一个非空行（从后往前扫一遍）。
    removed: list[int] = []
    for i, line in enumerate(lines):
        if not line.rstrip().endswith(","):
            continue
        nxt = next((l.strip() for l in lines[i + 1 :] if l.strip()), "")
        if not nxt.startswith(("}", "]")):
            continue
        # 只去掉行尾那一个逗号，保留行尾其余空白形态（缩进由原行负责）。
        stripped = line.rstrip()
        lines[i] = stripped[:-1] + line[len(stripped) :]
        removed.append(i + 1)

    return "\n".join(lines) + ("\n" if text.endswith("\n") else ""), removed


def main() -> int:
    args = sys.argv[1:]
    write = "--write" in args
    only: str | None = None
    if "--file" in args:
        idx = args.index("--file")
        if idx + 1 >= len(args):
            print("--file 后面要跟一个文件名", file=sys.stderr)
            return 2
        only = args[idx + 1]

    targets = sorted(L10N.glob("app_*.arb"))
    if only:
        targets = [p for p in targets if p.name == only]
        if not targets:
            print(f"未找到 {L10N / only}", file=sys.stderr)
            return 2

    if not targets:
        print(f"未在 {L10N} 找到 app_*.arb", file=sys.stderr)
        return 2

    total_hits = 0
    failures: list[str] = []

    for path in targets:
        original = path.read_text(encoding="utf-8")
        fixed, removed = strip_trailing_commas(original)

        # 闸 1：改完必须是合法 JSON，否则整份放弃。
        if fixed != original:
            try:
                json.loads(fixed)
            except json.JSONDecodeError as exc:
                failures.append(
                    f"{path.name}: 删除尾逗号后仍是非法 JSON（{exc}），已放弃、原文件未改"
                )
                continue

        if not removed:
            print(f"OK    {path.name}：没有多余尾逗号")
            continue

        total_hits += len(removed)
        head = ", ".join(str(n) for n in removed[:8])
        more = " …" if len(removed) > 8 else ""
        print(f"FOUND {path.name}：{len(removed)} 处多余尾逗号（行 {head}{more}）")

        if write:
            path.write_text(fixed, encoding="utf-8")
            print(f"      已写回 {path.name}")

    if failures:
        print("", file=sys.stderr)
        for msg in failures:
            print(f"ERROR {msg}", file=sys.stderr)
        return 1

    if total_hits and not write:
        print(f"\n共 {total_hits} 处。加 --write 才会写盘。")
    elif total_hits and write:
        print(f"\n共删除 {total_hits} 处，全部通过 JSON 校验。")
    else:
        print("\n六份 ARB 都合法，无需改动。")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
