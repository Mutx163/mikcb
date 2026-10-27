#!/usr/bin/env python3
"""把 composeP1 页面里 `Text(fontSize = N.sp)` 机械替换为官方字阶 `style = MiuixTheme.textStyles.X`。

背景：官方 `Text` 默认 `style = MiuixTheme.textStyles.main`，一旦显式传 `fontSize`，
就整体覆盖掉主题样式（字族、字重、行高），用户字重 / 系统粗体 / 自定义字族全都挂不上，
而且实测散成 14 种字号（含 10/15/22/28 这些刻度里没有的）。详见
`docs/reference/miuix-demo/我们的差距与修法.md` 发现一。

只做三件事，逐文件独立处理：
  1. `fontSize = N.sp` -> `style = MiuixTheme.textStyles.<槽位>`（映射见 SCALE_MAP）
  2. 增 `import top.yukonga.miuix.kmp.theme.MiuixTheme`
  3. 若文件里再也没有 `.sp` 了，删掉 `import androidx.compose.ui.unit.sp`

**只动真正的字阶调用**：先做括号配平找到 `fontSize` 所在的实参列表，取它的被调用名，
只有 `Text(` / `MiuixText(`（后者是本仓 `import ... as MiuixText` 的别名，同一个组件）才替换。
同一调用里已经有 `style = ` 的一律跳过并列出——那说明调用方自己接管了样式，机械替换会撞出重复具名参数。

**不动别人正在改的文件**：默认读 `git status`，凡是已脏的目标文件一律跳过并列出，
避免把并发会话的在途工作卷进来。

用法：
    python scripts/migrate-fontsize-to-textstyles.py                       # 干跑，只列清单
    python scripts/migrate-fontsize-to-textstyles.py --write               # 实际写入（跳过脏文件）
    python scripts/migrate-fontsize-to-textstyles.py --write --only a/b.kt c/d.kt
    python scripts/migrate-fontsize-to-textstyles.py --write --allow-dirty  # 连脏文件一起（谨慎）
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "android/app/src/composeP1/kotlin/com/mutx163/qingyu"

MIUIX_THEME_IMPORT = "import top.yukonga.miuix.kmp.theme.MiuixTheme"
SP_IMPORT = "import androidx.compose.ui.unit.sp"
IMPORT_RE = re.compile(r"^import .+$", re.MULTILINE)
NUMERIC_SIZE_RE = re.compile(r"fontSize\s*=\s*(\d+)\.sp")
# 另一类写法直接用语义常量（`QingyuTypography.FOOTNOTE1.sp`）：数值本来就在刻度上，
# 但传 fontSize 依然会整体覆盖主题样式，所以同样要换成 style。
CONST_SIZE_RE = re.compile(r"fontSize\s*=\s*QingyuTypography\.([A-Z0-9_]+)\.sp")
TEXT_CALLS = {"Text", "MiuixText"}

# QingyuTypography 的语义别名 -> 官方字阶槽位（对照 QingyuTypography.kt 的取值）。
CONST_TO_SLOT = {
    "MAIN": "main",
    "PARAGRAPH": "paragraph",
    "BODY1": "body1",
    "BODY2": "body2",
    "BUTTON": "button",
    "FOOTNOTE1": "footnote1",
    "FOOTNOTE2": "footnote2",
    "HEADLINE1": "headline1",
    "HEADLINE2": "headline2",
    "SUBTITLE": "subtitle",
    "TITLE1": "title1",
    "TITLE2": "title2",
    "TITLE3": "title3",
    "TITLE4": "title4",
    # 下列别名的取值与某个官方槽位相同（见 QingyuTypography.kt 注释）
    "PREFERENCE_TITLE": "headline1",
    "LIST_DETAIL": "body2",
    "SECTION_LABEL": "footnote1",
    "SECTION_DESCRIPTION": "footnote1",
    "NESTED_HEADER_TITLE": "title3",
    "METRIC_LARGE": "title2",
    "METRIC_MEDIUM": "title4",
}

# 字号 -> 官方字阶槽位。刻度只有 11/13/14/16/17/18/20/24/32，
# 不在刻度上的就近归档（与 2026-10-27 另一会话已落地的映射一致：
# 14/15 -> body2、13 -> footnote1、11 -> footnote2、16 -> body1、17 -> main、22 -> title3）。
SCALE_MAP = {
    10: "footnote2",
    11: "footnote2",
    12: "footnote1",
    13: "footnote1",
    14: "body2",
    15: "body2",
    16: "body1",
    17: "main",
    18: "title4",
    20: "title3",
    22: "title3",
    24: "title2",
    28: "title1",
}


def dirty_paths() -> set:
    """当前工作区里所有已修改/已删除/未跟踪的路径（相对仓库根，正斜杠）。"""
    out = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True
    ).stdout
    paths = set()
    for line in out.splitlines():
        if len(line) < 4:
            continue
        p = line[3:].strip().strip('"')
        if " -> " in p:  # 重命名
            p = p.split(" -> ", 1)[1]
        paths.add(p.replace("\\", "/"))
    return paths


def enclosing_call(text: str, pos: int):
    """返回 (被调用名, 左括号下标)。从 pos 往前配平括号，找到包住它的那层 `(`。"""
    depth = 0
    i = pos - 1
    while i >= 0:
        ch = text[i]
        if ch == ")":
            depth += 1
        elif ch == "(":
            if depth == 0:
                break
            depth -= 1
        i -= 1
    if i < 0:
        return None, None
    j = i - 1
    while j >= 0 and (text[j].isalnum() or text[j] in "_."):
        j -= 1
    return text[j + 1: i], i


def matching_paren(text: str, open_idx: int) -> int:
    """返回与 open_idx 处 `(` 配对的 `)` 下标；找不到返回 -1。"""
    depth = 0
    i = open_idx
    while i < len(text):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def migrate(path: Path, write: bool):
    """返回 (替换条数, 跳过说明列表)。"""
    text = path.read_text(encoding="utf-8")
    replacements = []  # (start, end, new_text)
    skipped = []

    # 统一成 (match, 槽位) 的序列：数字字号与语义常量两类写法一起处理
    candidates = []
    for m in NUMERIC_SIZE_RE.finditer(text):
        size = int(m.group(1))
        slot = SCALE_MAP.get(size)
        if slot is None:
            skipped.append(f"字号 {size}.sp 不在映射表里，人工判断")
            continue
        candidates.append((m, slot))
    for m in CONST_SIZE_RE.finditer(text):
        const = m.group(1)
        slot = CONST_TO_SLOT.get(const)
        if slot is None:
            skipped.append(f"QingyuTypography.{const} 没有对应槽位，人工判断")
            continue
        candidates.append((m, slot))

    for m, slot in sorted(candidates, key=lambda c: c[0].start()):
        if any(s <= m.start() < e for s, e, _ in replacements):
            continue  # 已被更早的匹配覆盖
        call, open_idx = enclosing_call(text, m.start())
        if call not in TEXT_CALLS:
            skipped.append(f"`{call}(...)` 里的 fontSize（不是 Text 调用），人工判断")
            continue
        close_idx = matching_paren(text, open_idx)
        if close_idx < 0:
            skipped.append("括号不配平，人工判断")
            continue
        args = text[open_idx: close_idx]
        if re.search(r"(?<![A-Za-z0-9_.])style\s*=", args):
            skipped.append("该调用已有 style = 参数，跳过")
            continue
        replacements.append((m.start(), m.end(), f"style = MiuixTheme.textStyles.{slot}"))

    if not replacements:
        return 0, skipped

    # 从后往前替换，避免下标漂移
    for start, end, new in sorted(replacements, reverse=True):
        text = text[:start] + new + text[end:]

    # 补 import（插在最后一条 import 之后）
    if MIUIX_THEME_IMPORT not in text:
        imports = list(IMPORT_RE.finditer(text))
        if imports:
            last = imports[-1]
            text = text[: last.end()] + "\n" + MIUIX_THEME_IMPORT + text[last.end():]
        else:
            # 没有任何 import 的极端情况：放在 package 行之后
            pkg = re.search(r"^package .+$", text, re.MULTILINE)
            anchor = pkg.end() if pkg else 0
            text = text[:anchor] + "\n\n" + MIUIX_THEME_IMPORT + text[anchor:]

    # 文件里已经没有 .sp 了才删 sp 的 import（避免误删仍在用的量纲）
    if SP_IMPORT in text and not re.search(r"\.sp\b", IMPORT_RE.sub("", text)):
        text = text.replace(SP_IMPORT + "\n", "").replace("\n" + SP_IMPORT, "")

    if write:
        path.write_text(text, encoding="utf-8")
    return len(replacements), skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="实际写入（默认干跑）")
    ap.add_argument("--only", nargs="*", default=None,
                    help="只处理这些文件（相对 android/app/src/composeP1/kotlin/com/mutx163/qingyu/ 或仓库根）")
    ap.add_argument("--allow-dirty", action="store_true", help="连有未提交改动的文件一起改（默认跳过）")
    args = ap.parse_args()

    dirty = set() if args.allow_dirty else dirty_paths()

    if args.only:
        targets = []
        for item in args.only:
            cand = Path(item)
            if not cand.is_absolute():
                for base in (SRC, ROOT, SRC / "pages"):
                    if (base / item).exists():
                        cand = base / item
                        break
            targets.append(Path(cand))
    else:
        targets = sorted(SRC.rglob("*.kt"))

    changed_files = 0
    total = 0
    skipped_dirty = []
    notes = []

    for path in targets:
        if not path.exists() or path.suffix != ".kt":
            print(f"!! 跳过（不存在或非 .kt）: {path}", file=sys.stderr)
            continue
        rel = path.relative_to(ROOT).as_posix()
        if rel in dirty:
            skipped_dirty.append(rel)
            continue
        count, skipped = migrate(path, args.write)
        if count:
            changed_files += 1
            total += count
            print(f"{'改' if args.write else '可改'} {rel}: {count} 处")
        for note in skipped:
            notes.append(f"  {rel}: {note}")

    print()
    print(f"合计 {changed_files} 个文件、{total} 处字号 -> 字阶"
          + ("（已写入）" if args.write else "（干跑，加 --write 落地）"))
    if skipped_dirty:
        print(f"\n跳过 {len(skipped_dirty)} 个有未提交改动的文件（别人的在途工作）：")
        for rel in skipped_dirty:
            print(f"  {rel}")
    if notes:
        print(f"\n需人工判断 {len(notes)} 处：")
        for note in notes:
            print(note)


if __name__ == "__main__":
    main()
