#!/usr/bin/env python3
"""`tool/` 下几个「会写文件」的脚本的咬合探针（**只在临时目录跑，不碰真文件**）。

用法：
    python tool/selftest_destructive_scripts.py

## 为什么需要它

2026-09-26 的代码审计发现 `tool/` 下有 4 个脚本会把仓库文件写坏（其中最狠的
`gen_app_log_l10n.dart` 会抹掉约 700 行、直接让 App 编译不过）。这些脚本都改成
「默认只检查 + 写盘前强制校验」之后，**守卫本身有没有牙齿**就成了新的问题：
如果校验永远通过，等于没有校验。

所以这里逐个验证三件事：
1. **合法输入 → 放行**（脚本不是永远拒绝的摆设）；
2. **会毁文件的输入 → 拦下**（校验真的会红）；
3. **真文件一个字节不动**（跑完 `md5` 与跑前一致）。

覆盖：
- `fix_arb_placeholder_commas.py`
- `append_service_msg_arb.py`
- `fix_zh_service_msg_arb.py`

`gen_app_log_l10n.dart` 是 Dart 脚本，探针在它的 `--root` 副本上手动跑
（见文件末尾说明），不在这里做。
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"
RESULTS: list[tuple[str, bool, str]] = []


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def record(name: str, ok: bool, detail: str) -> None:
    RESULTS.append((name, ok, detail))


def run(script: Path, cwd: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(script), *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


# ---------------------------------------------------------------------------
# 1. fix_arb_placeholder_commas.py —— 只删「逗号后紧跟闭合括号」的多余逗号
# ---------------------------------------------------------------------------

def test_arb_commas() -> None:
    script = ROOT / "tool" / "fix_arb_placeholder_commas.py"

    # A. 真·多余尾逗号 → 应删掉且改完合法
    bad = '{\n  "a": "1",\n  "b": {\n    "x": { "type": "String" },\n  },\n  "c": [\n    "y",\n  ]\n}\n'
    # B. 必需的分隔逗号 → 一个都不许动（上一版会误删的就是这些）
    good = (
        '{\n  "k": "v",\n  "@k": {\n    "placeholders": {\n'
        '      "delta": { "type": "String" },\n      "busiest": { "type": "String" }\n'
        '    }\n  },\n  "next": "x"\n}\n'
    )

    for label, content, expect_changed, expect_valid in (
        ("多余尾逗号应被删掉", bad, True, True),
        ("必需分隔逗号不许动", good, False, True),
    ):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib/l10n").mkdir(parents=True)
            (root / "tool").mkdir()
            shutil.copy(script, root / "tool" / script.name)
            target = root / "lib/l10n/app_zh.arb"
            target.write_text(content, encoding="utf-8")
            before = target.read_text(encoding="utf-8")
            run(root / "tool" / script.name, root, "--write")
            after = target.read_text(encoding="utf-8")
            try:
                json.loads(after)
                valid = True
            except json.JSONDecodeError:
                valid = False
            ok = (after != before) == expect_changed and valid == expect_valid
            record(f"arb-commas: {label}", ok, f"变了={after != before} 合法={valid}")

    # C. 真实 ARB 副本跑一遍 → 逐字节不变
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "lib/l10n").mkdir(parents=True)
        (root / "tool").mkdir()
        shutil.copy(script, root / "tool" / script.name)
        originals = {}
        for p in sorted(L10N.glob("app_*.arb")):
            dst = root / "lib/l10n" / p.name
            shutil.copy(p, dst)
            originals[p.name] = dst.read_bytes()
        run(root / "tool" / script.name, root, "--write")
        changed = [n for n, b in originals.items() if (root / "lib/l10n" / n).read_bytes() != b]
        record("arb-commas: 真实 ARB 逐字节不变", not changed, f"变了={changed}")


# ---------------------------------------------------------------------------
# 2. append_service_msg_arb.py —— 幂等：已有键一律跳过
# ---------------------------------------------------------------------------

def test_append_service_msg() -> None:
    script = ROOT / "tool" / "append_service_msg_arb.py"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "lib/l10n").mkdir(parents=True)
        (root / "tool").mkdir()
        shutil.copy(script, root / "tool" / script.name)
        for p in sorted(L10N.glob("app_*.arb")):
            shutil.copy(p, root / "lib/l10n" / p.name)
        before = {p.name: md5(p) for p in (root / "lib/l10n").glob("app_*.arb")}

        # 真实 ARB 里这 195 个键**全已存在**，所以跑两遍都必须零改动。
        first = run(root / "tool" / script.name, root, "--write")
        second = run(root / "tool" / script.name, root, "--write")
        after = {p.name: md5(p) for p in (root / "lib/l10n").glob("app_*.arb")}

        record(
            "append-service-msg: 幂等（跑两遍零改动）",
            before == after,
            f"rc={first.returncode}/{second.returncode} 变动={[k for k in before if before[k] != after[k]]}",
        )

        # 反向：删掉一个键，脚本应该把它补回来（证明它真会干活，不是永远跳过）
        ja = root / "lib/l10n" / "app_ja.arb"
        data = json.loads(ja.read_text(encoding="utf-8"))
        victim = next((k for k in data if k.startswith("serviceMsg")), None)
        if victim is None:
            record("append-service-msg: 能补回缺键", False, "找不到 serviceMsg 键做样本")
            return
        del data[victim]
        ja.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        run(root / "tool" / script.name, root, "--write")
        back = json.loads(ja.read_text(encoding="utf-8"))
        record(
            "append-service-msg: 能补回缺键（不是永远跳过）",
            victim in back,
            f"键 {victim} 是否补回={victim in back}",
        )


# ---------------------------------------------------------------------------
# 3. fix_zh_service_msg_arb.py —— 不许把中文回退成英文
# ---------------------------------------------------------------------------

def test_fix_zh() -> None:
    script = ROOT / "tool" / "fix_zh_service_msg_arb.py"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "lib/l10n").mkdir(parents=True)
        (root / "tool").mkdir()
        shutil.copy(script, root / "tool" / script.name)
        for p in sorted(L10N.glob("app_*.arb")):
            shutil.copy(p, root / "lib/l10n" / p.name)
        zh = root / "lib/l10n" / "app_zh.arb"
        before = md5(zh)

        # 现状：149 条 serviceMsg 全已有中文 → 应当零改动
        proc = run(root / "tool" / script.name, root, "--write")
        record(
            "fix-zh: 已是中文时零改动",
            md5(zh) == before,
            f"rc={proc.returncode} 变动={md5(zh) != before}",
        )

        # 反向：把一条中文换成英文，脚本应把它修回中文
        data = json.loads(zh.read_text(encoding="utf-8"))
        victim = next(
            (k for k in data
             if k.startswith("serviceMsg") and not k.startswith("@")
             and any("\u4e00" <= c <= "\u9fff" for c in str(data[k]))),
            None,
        )
        if victim is None:
            record("fix-zh: 能把英文改回中文", False, "找不到中文样本")
            return
        original = data[victim]
        data[victim] = "English placeholder text"
        zh.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        run(root / "tool" / script.name, root, "--write")
        after = json.loads(zh.read_text(encoding="utf-8"))
        fixed = any("\u4e00" <= c <= "\u9fff" for c in str(after[victim]))
        record(
            "fix-zh: 能把英文改回中文（不是永远跳过）",
            fixed,
            f"{victim}: {after[victim]!r}（原 {original!r}）",
        )


# ---------------------------------------------------------------------------

def main() -> int:
    # 先记真文件指纹，最后核对——任何一步碰了真文件都要报出来。
    real_before = {p.name: md5(p) for p in sorted(L10N.glob("app_*.arb"))}

    test_arb_commas()
    test_append_service_msg()
    test_fix_zh()

    real_after = {p.name: md5(p) for p in sorted(L10N.glob("app_*.arb"))}
    touched = [k for k in real_before if real_before[k] != real_after.get(k)]
    record("真文件零改动（lib/l10n/*.arb）", not touched, f"被改动={touched}")

    print()
    for name, ok, detail in RESULTS:
        print(f"{'PASS' if ok else 'FAIL'}  {name}  |  {detail}")
    failed = [n for n, ok, _ in RESULTS if not ok]
    print()
    if failed:
        print(f"有 {len(failed)} 项失败：{failed}")
        return 1
    print(f"全部通过（{len(RESULTS)} 项）")
    print()
    print("gen_app_log_l10n.dart 另测（Dart，需 --root 指向副本）：")
    print("  cp -r lib tool /tmp/genprobe && cd /tmp/genprobe")
    print("  dart run tool/gen_app_log_l10n.dart --write --root /tmp/genprobe")
    print("  期望：行数不缩水、AppLogMessages.* 一个不少、注释减少会打印警告")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
