#!/usr/bin/env python3
"""lint 棘轮：把两条「已知违规很多、暂时开不了」的 lint 钉住，只降不升。

用法：
    python tool/audit_lint_ratchet.py              # 检查（超过基线则退出 1）
    python tool/audit_lint_ratchet.py --update     # 重测并写基线
    python tool/audit_lint_ratchet.py --print      # 只打印当前分布

## 为什么是棘轮而不是「直接打开」

`analysis_options.yaml` 里两条 lint 被注释着（`discarded_futures` /
`cascade_invocations`），注释自述「现存 127 处 / 195 处」。2026-10-27 实测：

    cascade_invocations  510
    discarded_futures    238

（注释里的数字早就过期了，这正是「注释当账本」的典型失效。）
两条都开会让全仓多出 748 条 info，而 CI 与 pre-commit 都跑
`--fatal-infos` —— 直接打开等于全仓红，没人能提交，最后一定是被整体
`--no-verify` 绕过。所以走棘轮：**先钉住现状，再只许降**。

## 为什么脚本要临时改 analysis_options.yaml

`dart analyze` 没有「指定配置文件」的参数，lint 开关只能写在包根的
`analysis_options.yaml` 里。所以本脚本：

1. **先确认这个文件是干净的**（`git diff --quiet`）——工作区里它被别人改过时
   直接拒绝运行，绝不覆盖别人的在途改动；
2. 用 `try/finally` 把它换成「打开两条 lint」的版本、跑分析、**无论成败都还原**；
3. 再把结果与基线比对。

因此在多 Agent 共享工作区里跑它是安全的：它只碰这一个文件，碰之前先验证干净，
碰完立刻还原。CI 里（全新 checkout）更是无风险。

## 基线是待办清单，不是豁免记录

降下来了就 `--update` 把基线压下去；**不许为了让检查变绿往上加**。
"""
from __future__ import annotations

import json
import os
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
OPTIONS = ROOT / "analysis_options.yaml"
BASELINE = ROOT / "tool" / "lint_ratchet_baseline.txt"

# 这两条就是 analysis_options.yaml 里被注释掉的那两条。
TRACKED_LINTS = ("discarded_futures", "cascade_invocations")

# 要打开它们时，把注释行换成启用行。
_ENABLE = {
    "    # - discarded_futures": "    - discarded_futures",
    "    # - cascade_invocations": "    - cascade_invocations",
}


def find_dart() -> str | None:
    for candidate in ("dart", "dart.bat"):
        found = shutil.which(candidate)
        if found:
            return found
    # Windows 上 PATH 里常没有 dart，退回 Flutter SDK 自带的那份。
    for guess in (
        Path("/d/Flutter/flutter/bin/dart"),
        Path("C:/Flutter/flutter/bin/dart.bat"),
    ):
        if guess.exists():
            return str(guess)
    return None


def git_clean(path: Path) -> bool:
    """这个文件相对 HEAD 没有未提交改动？"""
    try:
        out = subprocess.run(
            ["git", "diff", "--quiet", "--", str(path.relative_to(ROOT))],
            cwd=ROOT,
            capture_output=True,
        )
        return out.returncode == 0
    except OSError:
        return False


def count_lints(dart: str) -> dict[str, int]:
    """临时打开两条 lint 跑一次分析，按 lint 名计数。"""
    original = OPTIONS.read_text(encoding="utf-8")
    enabled = original
    for old, new in _ENABLE.items():
        enabled = enabled.replace(old, new)
    if enabled == original:
        raise SystemExit(
            "ERROR: 没能在 analysis_options.yaml 里找到那两条被注释的 lint —— "
            "要么它们已被启用（那就删掉本脚本），要么写法变了（请同步 _ENABLE）"
        )

    # mkstemp 会返回一个**已打开**的文件描述符；不关掉它，Windows 上后面
    # `unlink` 会报 WinError 32（文件被占用）。2026-10-27 实测踩到过：
    # 配置其实已经还原，只是删临时文件失败把整个脚本带崩了。
    fd, backup_name = tempfile.mkstemp(suffix=".analysis_options.bak")
    os.close(fd)
    backup = Path(backup_name)
    backup.write_text(original, encoding="utf-8")
    counts: dict[str, int] = {}
    try:
        OPTIONS.write_text(enabled, encoding="utf-8")
        proc = subprocess.run(
            [dart, "analyze", "--format=json"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        payload = proc.stdout.strip()
        if not payload.startswith("{"):
            raise SystemExit(
                f"ERROR: dart analyze 没有返回 JSON（退出码 {proc.returncode}）：\n"
                f"{proc.stdout[:500]}\n{proc.stderr[:500]}"
            )
        for diag in json.loads(payload).get("diagnostics", []):
            code = diag.get("code") or ""
            if code in TRACKED_LINTS:
                counts[code] = counts.get(code, 0) + 1
    finally:
        # 无论成功、失败还是 Ctrl-C，都必须还原。
        OPTIONS.write_text(backup.read_text(encoding="utf-8"), encoding="utf-8")
        # 删临时文件失败不能影响「已还原」这个结果 —— Windows 上文件被占用时
        # `unlink` 会抛 PermissionError（2026-10-27 实测），而那时配置其实已经
        # 写回去了。所以这里吞掉异常，只在真删不掉时留一句提示。
        try:
            backup.unlink(missing_ok=True)
        except OSError as exc:  # pragma: no cover - 平台相关
            print(f"提示: 临时备份 {backup} 未能删除（{exc}），可手工清理", file=sys.stderr)
    return counts


def load_baseline() -> dict[str, int]:
    if not BASELINE.exists():
        return {}
    out: dict[str, int] = {}
    for raw in BASELINE.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        name, _, value = line.partition(":")
        out[name.strip()] = int(value.strip())
    return out


def render_baseline(counts: dict[str, int]) -> str:
    lines = [
        "# lint 棘轮基线：这两条 lint 暂时开着会全仓红，先把现存违规数钉住，只许降。",
        "# 生成：python tool/audit_lint_ratchet.py --update",
        "# 规则见 tool/audit_lint_ratchet.py；降下来就压基线，不许往上加。",
    ]
    for name in TRACKED_LINTS:
        lines.append(f"{name}: {counts.get(name, 0)}")
    return "\n".join(lines) + "\n"


def main() -> int:
    dart = find_dart()
    if dart is None:
        print("ERROR: 找不到 dart（PATH 与 Flutter SDK 都没有）", file=sys.stderr)
        return 2

    if not git_clean(OPTIONS):
        print(
            "ERROR: analysis_options.yaml 有未提交改动，拒绝运行 ——\n"
            "       本脚本要临时替换它，会覆盖掉你的在途修改。\n"
            "       请先提交/还原该文件，或等改它的人收工。",
            file=sys.stderr,
        )
        return 2

    counts = count_lints(dart)

    if "--print" in sys.argv:
        for name in TRACKED_LINTS:
            print(f"{name}: {counts.get(name, 0)}")
        return 0

    if "--update" in sys.argv:
        BASELINE.write_text(render_baseline(counts), encoding="utf-8")
        print(f"已写回 {BASELINE.relative_to(ROOT)}：")
        for name in TRACKED_LINTS:
            print(f"  {name}: {counts.get(name, 0)}")
        return 0

    baseline = load_baseline()
    if not baseline:
        print(
            f"ERROR: 基线文件 {BASELINE.relative_to(ROOT)} 不存在，先跑 --update",
            file=sys.stderr,
        )
        return 2

    problems: list[str] = []
    improved: list[str] = []
    for name in TRACKED_LINTS:
        now = counts.get(name, 0)
        allowed = baseline.get(name, 0)
        if now > allowed:
            problems.append(f"{name}: {allowed} → {now}（新增 {now - allowed} 处）")
        elif now < allowed:
            improved.append(f"{name}: {allowed} → {now}（降了 {allowed - now} 处，请 --update 压基线）")

    for line in improved:
        print(f"IMPROVED  {line}")
    if problems:
        print("", file=sys.stderr)
        for line in problems:
            print(f"ERROR  {line}", file=sys.stderr)
        print("", file=sys.stderr)
        print("这两条 lint 的存量是棘轮，只降不升。", file=sys.stderr)
        print("新代码请用 unawaited(...) 包住故意丢弃的 Future，或用 cascade（`..`）串调用。", file=sys.stderr)
        return 1

    print("OK: 两条 lint 的违规数都没超过基线")
    for name in TRACKED_LINTS:
        print(f"  {name}: {counts.get(name, 0)} / 基线 {baseline.get(name, 0)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
