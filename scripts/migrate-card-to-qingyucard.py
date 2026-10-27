#!/usr/bin/env python3
"""把 composeP1 页面里的官方 Card( 调用机械替换为 QingyuCard(。

背景：官方 Card 的 pressFeedbackType / showIndication 默认全是关的，
迁移时按默认值抄导致可点卡片没有按压反馈。详见
`docs/reference/miuix-demo/我们的差距与修法.md`（发现二）。
组件本体：`android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuCard.kt`。

只做两件事，逐文件独立处理：
  1. `\\bCard(` -> `QingyuCard(`（用负向后顾避免碰到 BasicCard( / xxxCard(）
  2. 增 `import com.mutx163.qingyu.components.QingyuCard`；
     若替换后 `Card` 不再被引用，删掉 `import top.yukonga.miuix.kmp.basic.Card`

**不重排其余 import**——有些文件的 import 本来就不是字典序，整体 sort 会带出
与本次改动无关的 diff（2026-10-27 实测 `SettingsPageRenderers.kt`）。
只插一行、删一行，保持「最小补丁」。

**不动别人正在改的文件**：脚本自己读 `git status`，凡是已脏（有未提交改动）的
目标文件一律跳过并列出，避免把并发会话的在途工作卷进来。

用法：
    python scripts/migrate-card-to-qingyucard.py           # 干跑，只列清单
    python scripts/migrate-card-to-qingyucard.py --write   # 实际写入
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "android/app/src/composeP1/kotlin/com/mutx163/qingyu"
NEW_IMPORT = "import com.mutx163.qingyu.components.QingyuCard"
OLD_IMPORT = "import top.yukonga.miuix.kmp.basic.Card"

CALL_RE = re.compile(r"(?<![A-Za-z_])Card\(")
BARE_RE = re.compile(r"(?<![A-Za-z_])Card\b")
IMPORT_RE = re.compile(r"^import .+$")

DRY = "--write" not in sys.argv


def dirty_files():
    out = subprocess.run(
        ["git", "status", "--short", "--", "android/app/src/composeP1"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    names = set()
    for line in out.splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            names.add((ROOT / parts[1].strip()).resolve())
    return names


def rewrite(text):
    if OLD_IMPORT not in text or not CALL_RE.search(text):
        return None

    # 按文件自身的行尾切分，最后再原样接回去——仓库里是 CRLF，
    # 用 read_text/write_text 会把换行归一化成 LF，产生整文件假 diff。
    eol = "\r\n" if "\r\n" in text else "\n"
    body = CALL_RE.sub("QingyuCard(", text)

    # import 块：取第一段连续的 import 行
    lines = body.split(eol)
    idx = [i for i, l in enumerate(lines) if IMPORT_RE.match(l)]
    if not idx:
        return None
    lo, hi = idx[0], idx[-1]
    if idx != list(range(lo, hi + 1)):
        return None  # import 不连续，交给人工，别猜

    # 只动两行：删掉不再需要的旧 import、插入一行新 import。
    # **不重排其余 import**——仓库里有些文件的 import 本来就不是字典序，
    # 整体 sort 会带出与本次改动无关的 diff（2026-10-27 实测 SettingsPageRenderers.kt）。
    rest = eol.join(lines[:lo] + lines[hi + 1:])
    card_still_used = bool(BARE_RE.search(rest))

    out = []
    for l in lines[lo:hi + 1]:
        if l == OLD_IMPORT and not card_still_used:
            continue
        out.append(l)
    if NEW_IMPORT not in out:
        pos = len(out)
        for i, l in enumerate(out):
            if l > NEW_IMPORT:
                pos = i
                break
        out = out[:pos] + [NEW_IMPORT] + out[pos:]

    return eol.join(lines[:lo] + out + lines[hi + 1:])


def main():
    dirty = dirty_files()
    changed, skipped_dirty, untouched = [], [], []

    for path in sorted(SRC.rglob("*.kt")):
        text = path.read_bytes().decode("utf-8")
        if not CALL_RE.search(text):
            continue
        if path.resolve() in dirty:
            skipped_dirty.append(path)
            continue
        new = rewrite(text)
        if new is None:
            untouched.append(path)
            continue
        if not DRY:
            path.write_bytes(new.encode("utf-8"))
        changed.append(path)

    rel = lambda p: str(p.relative_to(ROOT)).replace("\\", "/")
    mode = "DRY-RUN（未写入）" if DRY else "已写入"
    print(f"== {mode} ==")
    print(f"将改写 {len(changed)} 个文件：")
    for p in changed:
        print("   ", rel(p))
    print(f"\n跳过（别的会话正在改）{len(skipped_dirty)} 个：")
    for p in skipped_dirty:
        print("   ", rel(p))
    if untouched:
        print(f"\n需人工看 {len(untouched)} 个（import 块不连续）：")
        for p in untouched:
            print("   ", rel(p))


if __name__ == "__main__":
    main()
