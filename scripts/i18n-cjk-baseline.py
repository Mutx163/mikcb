#!/usr/bin/env python3
"""扫描 Kotlin 源码里的中文字面量，生成/校验 i18n 棘轮基线。

用法：
    python scripts/i18n-cjk-baseline.py                    # 打印两个源集的当前统计
    python scripts/i18n-cjk-baseline.py --write            # 重写两个基线文件
    python scripts/i18n-cjk-baseline.py --source-set main  # 只看 main 源集
    python scripts/i18n-cjk-baseline.py --source-set main --write

基线文件（每个源集一份，键是相对该源集根的路径）：
    composeP1：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt
    main     ：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline-main.txt
文件格式：每行 `<相对源集根的路径>:<中文字面量数>`，`#` 起始为注释。

规则必须与 CjkLiteralGateTest.kt 逐字一致，否则基线会漂移：
  * composeP1 只扫 android/app/src/composeP1/kotlin
    main 只扫 android/app/src/main/kotlin，两者都只收 *.kt
  * 纯注释行（lstrip 后以 '*' / '//' / '/*' 开头）整行跳过
  * `Log.*(...)` 行整行跳过：日志是给开发者看的，永远不上屏
  * 生成代码跳过：路径里含 build/ 或 generated/ 目录，或文件名以 Generated.kt 结尾
  * i18n 文案表整文件跳过（它们本来就该放中文，不是债务）：
      - 文件名含 `Strings` 或 `Arb`
      - 文件名以 `ServiceMessages.kt` / `LogMessages.kt` / `Localizer.kt` 结尾
  * 字面量用正则 "((?:[^"\\]|\\.)*)" 提取，含 [U+4E00..U+9FFF] 者计数

## 为什么按文件名排除文案表

文案表的键值对本身就是中文，且由 `*ParityTest` 与 ARB 逐字对拍，不归本门禁管。
按「文件名 + 明确后缀」排除是唯一能在 Python 与 Kotlin 两侧写成**逐字一致**、
又不会误伤 Compose 的 `Text("中文")` 的判据（按构造函数名排除会误把 `Text(` 当成文案表）。
代价是：**夹在普通模型文件里的文案表**（如 `ChangelogModel.kt` 末尾的 `ChangelogStrings`）
仍会被计入基线，见 CjkLiteralGateTest 的类注释；那是已知的保守面，不是漏判。

## 为什么每个源集一份基线

两个源集的相对路径可能重名；分开存不用给键加前缀，也能各自 `--write` 独立重生成，
并行改不同源集的人不会互相改到对方的基线（与 `tool/compose_style_baseline/<域>.txt` 同理）。
代价是要维护两个文件，测试循环遍历。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE_DIR = ROOT / "android/app/src/test/kotlin/com/mutx163/qingyu/i18n"

# name -> (源码根, 基线文件, 基线标题)
SOURCE_SETS = {
    "composeP1": (
        ROOT / "android/app/src/composeP1/kotlin",
        BASELINE_DIR / "cjk-literal-baseline.txt",
        "Compose 渲染层（composeP1）",
    ),
    "main": (
        ROOT / "android/app/src/main/kotlin",
        BASELINE_DIR / "cjk-literal-baseline-main.txt",
        "main 源集（壳与页面模型）",
    ),
}

# 兼容既有脚本（.agents/compose-phase3/tmp/i18n_gate_diff.py 会 import 这两个名字）。
SRC = SOURCE_SETS["composeP1"][0]
BASELINE = SOURCE_SETS["composeP1"][1]

LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')

# 与 CjkLiteralGateTest.LOG_CALL 逐字一致：`Log.*(...)` 的中文是开发者日志、不上屏，整行跳过。
LOG_CALL = re.compile(r"\bLog\.[vdiwe]\s*\(")

# 与 CjkLiteralGateTest 的 COPY_TABLE_* / GENERATED_* 逐字一致。
COPY_TABLE_NAME_MARKERS = ("Strings", "Arb")
COPY_TABLE_SUFFIXES = ("ServiceMessages.kt", "LogMessages.kt", "Localizer.kt")
GENERATED_DIRS = ("build", "generated")
GENERATED_SUFFIX = "Generated.kt"


def is_copy_table(name: str) -> bool:
    return any(marker in name for marker in COPY_TABLE_NAME_MARKERS) or name.endswith(
        COPY_TABLE_SUFFIXES
    )


def is_generated(rel: Path) -> bool:
    if any(part.lower() in GENERATED_DIRS for part in rel.parts[:-1]):
        return True
    return rel.name.endswith(GENERATED_SUFFIX)


def count_line(line: str) -> int:
    if line.lstrip().startswith(("*", "//", "/*")):
        return 0
    if LOG_CALL.search(line):
        return 0
    n = 0
    for m in LITERAL_RE.finditer(line):
        if any("一" <= ch <= "鿿" for ch in m.group(1)):
            n += 1
    return n


def scan(source_set: str = "composeP1") -> dict:
    src = SOURCE_SETS[source_set][0]
    counts = {}
    for path in sorted(src.rglob("*.kt")):
        rel = path.relative_to(src)
        if is_generated(rel) or is_copy_table(path.name):
            continue
        total = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            total += count_line(line)
        if total:
            counts[rel.as_posix()] = total
    return counts


def render(counts, title: str) -> str:
    out = [
        f"# i18n 棘轮基线：{title}中文字面量计数",
        "# 生成：python scripts/i18n-cjk-baseline.py --write",
        "# 规则见 CjkLiteralGateTest.kt；修复某文件后必须下调该行数字，不得上调。",
        "# 已排除：i18n 文案表（*Strings*.kt / *Arb*.kt / *ServiceMessages.kt / "
        "*LogMessages.kt / *Localizer.kt）与生成代码；Log.* 行整行跳过。",
    ]
    for name, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        out.append(f"{name}:{n}")
    return "\n".join(out) + "\n"


def main() -> int:
    selected = sys.argv[sys.argv.index("--source-set") + 1] if "--source-set" in sys.argv else None
    if selected is not None and selected not in SOURCE_SETS:
        print(f"未知源集：{selected}，可选：{', '.join(SOURCE_SETS)}")
        return 2

    names = [selected] if selected else list(SOURCE_SETS)
    for name in names:
        _, baseline, title = SOURCE_SETS[name]
        counts = scan(name)
        total = sum(counts.values())
        if "--write" in sys.argv:
            baseline.parent.mkdir(parents=True, exist_ok=True)
            baseline.write_text(render(counts, title), encoding="utf-8")
            print(f"已写入 {baseline.relative_to(ROOT)}：{len(counts)} 个文件 / {total} 条")
        else:
            print(f"[{name}] 中文字面量总计 {total} 条，分布 {len(counts)} 个文件")
            for rel, n in sorted(counts.items(), key=lambda kv: -kv[1]):
                print(f"  {n:>3}  {rel}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
