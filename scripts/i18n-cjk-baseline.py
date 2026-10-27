#!/usr/bin/env python3
"""扫描 Compose 渲染层（composeP1 源集）的中文字面量，生成/校验 i18n 棘轮基线。

用法：
    python scripts/i18n-cjk-baseline.py           # 打印当前统计
    python scripts/i18n-cjk-baseline.py --write   # 重写基线文件

基线文件：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt
文件格式：每行 `<相对 composeP1 根的路径>:<中文字面量数>`，`#` 起始为注释。

规则必须与 CjkLiteralGateTest.kt 逐字一致，否则基线会漂移：
  * 只扫 android/app/src/composeP1/kotlin 下的 *.kt
  * 纯注释行（lstrip 后以 '*' / '//' / '/*' 开头）整行跳过
  * 字面量用正则 "((?:[^"\\]|\\.)*)" 提取，含 [U+4E00..U+9FFF] 者计数
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "android/app/src/composeP1/kotlin"
BASELINE = (
    ROOT
    / "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt"
)
LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def count_line(line: str) -> int:
    if line.lstrip().startswith(("*", "//", "/*")):
        return 0
    n = 0
    for m in LITERAL_RE.finditer(line):
        if any("\u4e00" <= ch <= "\u9fff" for ch in m.group(1)):
            n += 1
    return n


def scan():
    counts = {}
    for path in sorted(SRC.rglob("*.kt")):
        total = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            total += count_line(line)
        if total:
            counts[path.relative_to(SRC).as_posix()] = total
    return counts


def render(counts) -> str:
    out = [
        "# i18n 棘轮基线：Compose 渲染层（composeP1）中文字面量计数",
        "# 生成：python scripts/i18n-cjk-baseline.py --write",
        "# 规则见 CjkLiteralGateTest.kt；修复某文件后必须下调该行数字，不得上调。",
    ]
    for name, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        out.append(f"{name}:{n}")
    return "\n".join(out) + "\n"


def main() -> int:
    counts = scan()
    total = sum(counts.values())
    if "--write" in sys.argv:
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(render(counts), encoding="utf-8")
        print(f"已写入 {BASELINE.relative_to(ROOT)}：{len(counts)} 个文件 / {total} 条")
        return 0
    print(f"中文字面量总计 {total} 条，分布 {len(counts)} 个文件")
    for name, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {n:>3}  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
