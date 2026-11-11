#!/usr/bin/env python3
"""扫描 Kotlin 源码里的中文字面量，生成/校准 i18n 棘轮基线（**棘轮只降不升**）。

用法：
    python scripts/i18n-cjk-baseline.py                    # 打印两个源集的当前统计（只读）
    python scripts/i18n-cjk-baseline.py --check            # 只读门禁：同一套判据，红绿走 exit code
    python scripts/i18n-cjk-baseline.py --write            # 校验通过才落盘（只降不升）
    python scripts/i18n-cjk-baseline.py --source-set main  # 只看 main 源集
    python scripts/i18n-cjk-baseline.py --source-set main --check
    python scripts/i18n-cjk-baseline.py --source-set main --write

exit code：0 绿 / 1 被拒（红）/ 2 用法错。

基线文件（每个源集一份，键是相对该源集根的路径）：
    composeP1：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt
    main     ：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline-main.txt
文件格式：每行 `<相对源集根的路径>:<中文字面量数>`，`#` 起始为注释。

## 棘轮只降不升（2026-11-11 起）

旧版 `--write` 会把**当前扫描结果整段写回基线**，于是留了一条洗白通道：往源码里随手加中文
字面量、跑一次 `--write`，基线自动变长，门禁照样绿。现在落盘前先读旧基线，逐文件比
「新扫描计数 vs 旧基线」：

* 允许：文件从扫描面消失（基线行删掉）、计数**下降**、计数**不变**；
* 拒绝：**新增文件**、任何文件计数**上调**。

只要有一处被拒 ⇒ 逐条打印「文件：旧 → 新」、**一个字节都不写**、exit 1。

`--check` 是同一套判据的只读版本（不写文件，红绿走 exit code）。它比 `--write` 多守一条：
「已修复但基线没下调」也是红——与 `CjkLiteralGateTest` 的口径逐字一致（棘轮只许收不许放，
否则修好的文件会被后来者「顺手」加回去）。

两个源集默认一起判：**先全量校验、全部通过才统一落盘**，不会写一半（一边写一边拒）。

## 与 CjkLiteralGateTest 的分工

本脚本 = 基线**生成器 + 只读预检**；权威闸门仍是 JVM 单测 `CjkLiteralGateTest`
（CI 跑 `:app:testProdDebugUnitTest`，本地 L2 跑 `:app:testDevDebugUnitTest`）。
两侧的**计数规则与排除规则必须逐字一致**，否则基线会漂移。

规则（与 CjkLiteralGateTest.kt 逐字一致）：
  * composeP1 只扫 android/app/src/composeP1/kotlin
    main 只扫 android/app/src/main/kotlin，两者都只收 *.kt
  * 纯注释行（lstrip 后以 '*' / '//' / '/*' 开头）整行跳过
  * `Log.*(...)` 行整行跳过：日志是给开发者看的，永远不上屏
  * 生成代码跳过：路径里含 build/ 或 generated/ 目录，或文件名以 Generated.kt 结尾
  * i18n 文案表整文件跳过（它们本来就该放中文，不是债务）：
      - 文件名含 `Strings` 或 `Arb`
      - 文件名以 `ServiceMessages.kt` / `LogMessages.kt` / `Localizer.kt` 结尾
  * 字面量用正则 "((?:[^"\\]|\\.)*)" 提取，含 [U+4E00..U+9FFF] 者计数
  * `@Preview(...)` 的参数与被它标注的函数体整段跳过（先抹空白再按行数，见下节）

## 为什么 `@Preview` 参数与预览函数体不算「屏上文案」（2026-11-11 统一口径）

`@Preview` 的参数（`name = "1 有数据"`、假课程名）和预览函数体里的构造数据**永远不上屏**：
它们只出现在 Android Studio 的预览面板里，用户看不到，也与六语文案无关。
`EmptyStateUnificationGuardTest` 从 2026-11-10 起就是这么判的（它的 `blankPreviewSpans`：
只抹 `@Preview(...)` 的参数与被注解函数体，**抹完不外溢**）。本棘轮一直没跟上，于是同一份
源码在两套守卫下判出两种结论——预览名被算成 i18n 债务，逼人把预览名改成英文
（`33a5c6e15` 就是这么走的）。这次两侧对齐：**豁免只放开预览块，不放开水位**。

实现：先把整个文件的文本做一遍「抹空白」（换行保留，字符偏移不变），再按行数计数。
抹的范围严格是两段——
  1. `@Preview` 之后紧跟的 `(...)` 参数列表；
  2. 该注解之后**第一个** `fun` 的函数体（花括号配对）。
配对失败（未闭合）时**宁可不豁免**：多抹会盖住真正的违规，少抹只会多报，多报是安全方向。

「`@Preview`」必须出现在**行首（允许前导空白）**才算——KDoc 里的 ` * @Preview`、注释里的
`// @Preview`、字符串里的 `"@Preview"` 都不算。这条比 `EmptyStateUnificationGuardTest` 的
「全文 `indexOf`」更窄，是刻意的：那套写法遇到注释里的 @Preview 会一路抹到下一个 `fun`，
把真代码一起盖掉。两侧（本文件与 `CjkLiteralGateTest.kt`）实现**逐字一致**。

## 为什么按文件名排除文案表

文案表的键值对本身就是中文，且由 `*ParityTest` 与 ARB 逐字对拍，不归本门禁管。
按「文件名 + 明确后缀」排除是唯一能在 Python 与 Kotlin 两侧写成**逐字一致**、
又不会误伤 Compose 的 `Text("中文")` 的判据（按构造函数名排除会误把 `Text(` 当成文案表）。
代价是：**夹在普通模型文件里的文案表**（如 `ChangelogModel.kt` 末尾的 `ChangelogStrings`）
仍会被计入基线，见 CjkLiteralGateTest 的类注释；那是已知的保守面，不是漏判。

## 为什么每个源集一份基线

两个源集的相对路径可能重名；分开存不用给键加前缀，也能各自 `--write` 独立重生成，
并行改不同源集的人不会互相改到对方的基线（按来源拆分清单，避免多人共写一个文件）。
代价是要维护两个文件，测试循环遍历。

## `--write` 不动手写注释（2026-11-11）

基线不只是数字表：里面夹着成片**手写理由**（为什么某文件几十条中文还不算债）。落盘时旧注释按
「紧随其后的那条数据行」归属，原样搬到新文件里；表头那一段每次重生成（它的内容随规则变），
文件末尾的悬挂注释统一贴到末尾。条目消失时它的注释一起走（条目没了，理由也就无所指）。

不做这件事的代价是可测的：2026-11-11 重生成前，两份基线合计 **102 行手写注释**
（composeP1 75 行 + main 27 行），其中就有「预览名照中文写」的首席口径与 `IcsExportModel` 的
ICU pattern 理由。`render()` 原样重排会把它们整片抹掉——理由是这套棘轮最贵的东西，不能丢。

## 环境变量可以换「读哪个基线」（只影响读取）

`CJK_LITERAL_BASELINE` / `CJK_LITERAL_BASELINE_MAIN` 覆盖**读取**路径（与 `CjkLiteralGateTest`
的 `System.getenv` 同名同义），`--write` 仍然只写回 `SOURCE_SETS` 里的规范路径。
用途：拿 `git show <sha>:<基线>` 存一份历史基线到临时目录，直接对拍「历史 vs 现在」，
不必先把仓库里的基线改成历史版本（改来改去最容易把别人的改动卷进来）。
"""
import os
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

USAGE = (
    "用法：python scripts/i18n-cjk-baseline.py [--check | --write] [--source-set <composeP1|main>]"
)


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


# ── `@Preview` 豁免：抹掉预览参数与预览函数体 ─────────────────────────────
# 与 CjkLiteralGateTest.kt 的 PREVIEW_ANNOTATION / blankPreviewSpans / matchingDelimiter
# **逐字一致**。改一边必须同步改另一边，否则基线会在两侧之间漂移。
#
# 只认**行首**的 `@Preview`（允许前导空白）：KDoc 的 ` * @Preview`、`// @Preview`、
# 字符串里的 `"@Preview"` 都不算。比 EmptyStateUnificationGuardTest 的全文 indexOf 更窄，
# 因为那套写法遇到注释里的 @Preview 会一路抹到下一个 `fun`，把真代码一起盖掉。
PREVIEW_ANNOTATION = re.compile(r"(?m)^[ \t]*(@Preview\b)")


def matching_delimiter(text: str, open_index: int, open_ch: str, close_ch: str) -> int:
    """成对标点的配对位置（`(`…`)` / `{`…`}`）；未闭合返回 -1。"""
    depth = 0
    for k in range(open_index, len(text)):
        ch = text[k]
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return k
    return -1


def blank_preview_spans(text: str) -> str:
    """把 `@Preview(...)` 的参数与预览函数体抹成空格（换行保留，字符偏移不变）。

    **只抹这两段**：抹完不外溢，预览之外任何中文字面量照旧计数。
    配对失败时宁可不豁免——多抹会盖住真违规，少抹只会多报，多报是安全方向。
    """
    chars = list(text)
    n = len(text)

    def blank(from_index: int, to_exclusive: int) -> None:
        for k in range(from_index, min(to_exclusive, n)):
            if chars[k] != "\n":
                chars[k] = " "

    pos = 0
    while True:
        m = PREVIEW_ANNOTATION.search(text, pos)
        if not m:
            break
        at = m.start(1)
        pos = m.end(1)
        cursor = m.end(1)
        j = m.end(1)
        while j < n and text[j] in " \t":
            j += 1
        if j < n and text[j] == "(":
            close = matching_delimiter(text, j, "(", ")")
            if close < 0:
                continue  # 配对失败 ⇒ 不豁免，绝不靠猜
            blank(at, close + 1)
            cursor = close + 1
        fun_at = text.find("fun ", cursor)
        if fun_at >= 0:
            brace = text.find("{", fun_at)
            if brace >= 0:
                body_close = matching_delimiter(text, brace, "{", "}")
                if body_close > 0:
                    blank(brace, body_close + 1)
    return "".join(chars)


def scan(source_set: str = "composeP1") -> dict:
    src = SOURCE_SETS[source_set][0]
    counts = {}
    for path in sorted(src.rglob("*.kt")):
        rel = path.relative_to(src)
        if is_generated(rel) or is_copy_table(path.name):
            continue
        total = 0
        # `@Preview(...)` 参数与预览函数体先抹空白：那两段是 IDE 预览里的标签与假数据，永不上屏。
        for line in blank_preview_spans(path.read_text(encoding="utf-8")).splitlines():
            total += count_line(line)
        if total:
            counts[rel.as_posix()] = total
    return counts


def render(counts, title: str, preamble=None, comments=None, trailing=None) -> str:
    out = [
        f"# i18n 棘轮基线：{title}中文字面量计数",
        "# 生成：python scripts/i18n-cjk-baseline.py --write",
        "# 规则见 CjkLiteralGateTest.kt；修复某文件后必须下调该行数字，不得上调。",
        "# 已排除：i18n 文案表（*Strings*.kt / *Arb*.kt / *ServiceMessages.kt / "
        "*LogMessages.kt / *Localizer.kt）与生成代码；Log.* 行整行跳过。",
    ]
    # 手写前言（第一条数据行之前、且不是表头那 4 行）原样排在表头后面。
    out.extend(preamble or ())
    comments = comments or {}
    for name, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        # 手写注释跟着它解释的那条数据行走；条目没了，注释一起走。
        out.extend(comments.get(name, ()))
        out.append(f"{name}:{n}")
    # 文件末尾那段没有后续数据行的注释（总述性质）原样留到最后。
    out.extend(trailing or ())
    return "\n".join(out) + "\n"


def baseline_read_path(name: str) -> Path:
    """读基线用哪个文件：`CJK_LITERAL_BASELINE[_MAIN]` 可换成历史副本，只影响读取。"""
    env_name = "CJK_LITERAL_BASELINE" if name == "composeP1" else "CJK_LITERAL_BASELINE_MAIN"
    override = os.environ.get(env_name)
    return Path(override) if override else SOURCE_SETS[name][1]


# 每次重生成都会改写这 4 行表头；其余 `#` 行一律算人写的，必须原样带走。
HEADER_PREFIXES = (
    "# i18n 棘轮基线：",
    "# 生成：python scripts/i18n-cjk-baseline.py",
    "# 规则见 CjkLiteralGateTest.kt",
    "# 已排除：i18n 文案表",
)


def collect_comment_blocks(path: Path):
    """读旧基线里的手写注释，返回 (前言, 按条目归属的注释块, 文件末尾悬挂注释)。

    * 只丢**那 4 行真表头**（按 `HEADER_PREFIXES` 逐条认，不是「前 N 行」——
      2026-11-11 实测：composeP1 有 38 行手写前言就排在第一条数据行之前，
      按行数切会把它们当表头一起抹掉）；
    * 其余每段连续 `#` 行：第一条数据行之前的算前言，之后的归属于紧随其后的那条数据行；
    * 没有后续数据行的（文件末尾总述）作为 trailing 原样保留。
    """
    preamble = []
    blocks = {}
    pending = []
    seen_data = False
    if not path.is_file():
        return preamble, blocks, []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line.lstrip().startswith("#"):
            if not seen_data and line.strip().startswith(HEADER_PREFIXES):
                continue
            if not seen_data:
                preamble.append(line)
            else:
                pending.append(line)
            continue
        if not line.strip():
            continue
        seen_data = True
        if pending:
            blocks[line.strip()[: line.strip().rfind(":")]] = pending
            pending = []
    return preamble, blocks, pending


def load_baseline(path: Path) -> dict:
    """读旧基线。文件不存在时返回空字典（= 尚无基线，棘轮无从比较）。

    格式与 CjkLiteralGateTest.loadBaseline 一致：`<相对路径>:<计数>`，`#` 注释，取**最后**一个冒号。
    """
    if not path.is_file():
        return {}
    result = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        sep = line.rfind(":")
        if sep <= 0:
            raise SystemExit(f"基线行格式非法（应为 <路径>:<计数>）：{path.name} → {raw}")
        result[line[:sep]] = int(line[sep + 1 :].strip())
    return result


def compare(old: dict, new: dict):
    """逐文件比新旧计数，返回 (blockers, lowers)。

    blockers = 新增文件 / 计数上调（棘轮**必须**拒绝）
    lowers   = 计数下降 / 文件退出扫描面（--write 允许落盘，--check 判红要求下调）
    """
    blockers = []
    lowers = []
    for rel in sorted(set(old) | set(new)):
        before = old.get(rel, 0)
        after = new.get(rel, 0)
        if after > before:
            blockers.append((rel, before, after))
        elif after < before:
            lowers.append((rel, before, after))
    return blockers, lowers


def describe(rel: str, before: int, after: int) -> str:
    """一条「文件：旧 → 新」。新增与退出扫描面单独标出来，人一眼能看懂方向。"""
    if before == 0:
        return f"  + {rel}：0 → {after}（新增文件）"
    if after == 0:
        return f"  - {rel}：{before} → 0（退出扫描面）"
    arrow = "↑" if after > before else "↓"
    return f"  {arrow} {rel}：{before} → {after}"


def main() -> int:
    argv = sys.argv[1:]
    known = {"--write", "--check", "--source-set"}
    unknown = [a for a in argv if a.startswith("--") and a not in known]
    if unknown:
        print(f"未知参数：{' '.join(unknown)}\n{USAGE}")
        return 2

    write = "--write" in argv
    check = "--check" in argv
    if write and check:
        print(f"--write 与 --check 不能同时用（前者落盘、后者只读预检）。\n{USAGE}")
        return 2

    selected = None
    if "--source-set" in argv:
        idx = argv.index("--source-set")
        if idx + 1 >= len(argv):
            print(f"--source-set 需要跟一个源集名。\n{USAGE}")
            return 2
        selected = argv[idx + 1]
        if selected not in SOURCE_SETS:
            print(f"未知源集：{selected}，可选：{', '.join(SOURCE_SETS)}")
            return 2

    names = [selected] if selected else list(SOURCE_SETS)

    # 无开关 = 统计视图（只读，不改文件）
    if not write and not check:
        for name in names:
            counts = scan(name)
            total = sum(counts.values())
            print(f"[{name}] 中文字面量总计 {total} 条，分布 {len(counts)} 个文件")
            for rel, n in sorted(counts.items(), key=lambda kv: -kv[1]):
                print(f"  {n:>3}  {rel}")
        return 0

    # ── 第一阶段：全量校验（两个源集都判完再决定落不落盘，绝不写一半）──
    per_set = {}
    blocked = False
    for name in names:
        read_path = baseline_read_path(name)
        old = load_baseline(read_path)
        new = scan(name)
        blockers, lowers = compare(old, new)
        per_set[name] = (old, new, blockers, lowers)
        if blockers:
            blocked = True

    if blocked:
        print("拒绝：棘轮只降不升，检测到新增 / 上调（一处都不放行）：")
        for name in names:
            _, _, blockers, _ = per_set[name]
            if not blockers:
                continue
            print(f"[{name}]")
            for rel, before, after in blockers:
                print(describe(rel, before, after))
        print("一个字节都没写。屏上文案改走 ArbText，不要靠重写基线放行。")
        return 1

    # ── 只读门禁：已修复但基线没下调也要红（与 CjkLiteralGateTest 口径一致）──
    if check:
        problems = [
            (name, rel, before, after)
            for name in names
            for rel, before, after in per_set[name][3]
        ]
        if problems:
            print(f"i18n 棘轮门禁失败（{len(problems)} 处已修复但基线未下调）：")
            for name, rel, before, after in problems:
                print(f"[{name}]")
                print(describe(rel, before, after))
            print(
                "棘轮只许收不许放：跑 `python scripts/i18n-cjk-baseline.py --write` 把基线调到实测值。"
            )
            return 1
        total = sum(sum(per_set[name][1].values()) for name in names)
        print(
            f"i18n 棘轮门禁通过：{len(names)} 个源集 / 中文字面量 {total} 条，"
            "未发现新增、上调或未下调。"
        )
        return 0

    # ── 落盘：全部校验通过后统一写，两源集谁都别抢先 ──
    for name in names:
        baseline_path = SOURCE_SETS[name][1]
        title = SOURCE_SETS[name][2]
        _, new, _, lowers = per_set[name]
        # 手写注释从「读的那份」继承：`--write` 不该抹掉人写下来的理由。
        preamble, comments, trailing = collect_comment_blocks(baseline_read_path(name))
        baseline_path.parent.mkdir(parents=True, exist_ok=True)
        baseline_path.write_text(
            render(new, title, preamble, comments, trailing), encoding="utf-8"
        )
        total = sum(new.values())
        kept = sum(1 for k in new if k in comments)
        kept_lines = len(preamble) + sum(len(v) for k, v in comments.items() if k in new) + len(trailing)
        msg = f"已写入 {baseline_path.relative_to(ROOT)}：{len(new)} 个文件 / {total} 条"
        if lowers:
            msg += f"（同时下调 {len(lowers)} 处）"
        if kept_lines:
            msg += f"；保留手写注释 {kept_lines} 行（前言 {len(preamble)} + 条目 {kept} 段）"
        print(msg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
