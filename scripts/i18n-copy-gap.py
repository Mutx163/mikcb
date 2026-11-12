#!/usr/bin/env python3
"""文案缺口棘轮：挡住「该语种没翻译」与「非中文语种混入中文」。

用法（仓库根）：
    python scripts/i18n-copy-gap.py              # 打印统计 + 与基线的差异
    python scripts/i18n-copy-gap.py --check      # 只比对基线，有新增缺口 / 该降未降则 exit 1
    python scripts/i18n-copy-gap.py --write      # 重写基线（**只许降不许升**，见下）
    python scripts/i18n-copy-gap.py --probe      # 三条咬合探针（判据自检）
    python scripts/i18n-copy-gap.py --probe-write # 端到端探针：造一次上调，验证 --write 拒绝且基线不变

基线：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/copy-gap-baseline.txt
Kotlin 侧：CopyGapGateTest.kt —— 判据必须与本文逐字一致，改一边必须改另一边。

## `--write` 的棘轮保护（与 `scripts/i18n-cjk-baseline.py` 同口径）

`--write` **不是**无条件重写：它会先逐行比对新旧缺口集合。

- 任何**新增**缺口（新集合里有、旧集合里没有）→ **拒绝写、一个字节都不动、非零退出**，
  并打印每个「上调」的键。否则「改 ARB → `--write` → 绿」就成了合法的自我洗白路径。
- 只允许**下降与删行**（修好的缺口从基线里去掉）。
- `--check` 仍是只读校验：新增缺口红、已修复但基线未下调也红（要求执行者 `--write` 下调）。

两道合起来才是棘轮：制造缺口会被 `--check` 判红，想偷偷洗白会被 `--write` 拒绝。

## 三条规则（RULES_VERSION = 1）

- **A 未翻译**：`ja` / `ko` 的值与 `en` **逐字相同**、且不含假名（ja）或谚文（ko）、
  且过白名单后仍有 **≥ 2 个英文词**。短标签（品牌名、`WebDAV URL`、纯占位符）不算。
- **B 中文污染**：`en` 或 `ko` 的值里出现汉字（U+4E00..U+9FFF）。
- **ja 不走 B**：日语本来就用汉字（当前 2061 条含汉字），用「含汉字」判会全线误报。
  「ja 等于中文且无假名」的漏译（约 39 条）**故意不做**：大半是 `保存`/`更新` 这类日文
  同形词，收益低、误报高。

## 为什么是棘轮而不是「一开就红」

当前存量有 1200+ 条缺口。门禁按「基线只许降不许升」执行：存量登记在基线里，
新增缺口立刻红；修好一条要求同步下调基线（与 `CjkLiteralGateTest` 同一套路）。

## 已知限制

本门禁是 Kotlin 测试，L0 的跨域守卫覆盖不到，只在 L2/CI 生效——与 CJK 棘轮同样处境。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RULES_VERSION = 1
# 白名单版本：改了 BRANDS / TECH / 最短词数就要 +1，并重跑 --write。
WHITELIST_VERSION = 1

ROOT = Path(__file__).resolve().parent.parent
ARB_DIR = ROOT / "i18n"
BASELINE = (
    ROOT / "android" / "app" / "src" / "test" / "kotlin"
    / "com" / "mutx163" / "qingyu" / "i18n" / "copy-gap-baseline.txt"
)

# 品牌 / 产品名：出现即视为「本来就用拉丁字母」，不判未翻译。
BRANDS = [
    "MiSans", "HarmonyOS", "OPPO", "PingFang", "Noto", "Bing", "GitHub", "Gitee",
    "WeChat", "Alipay", "Coolapk", "Bilibili", "Xiaohongshu", "WebDAV", "Jianguoyun",
    "HyperOS", "MIUI", "Android", "iOS", "Windows", "macOS", "Linux", "Flutter",
    "Dart", "Kotlin", "Compose", "Miuix", "ClassIn", "Zoom", "Teams", "DingTalk", "QQ",
]
# 技术标识：扩展名、URL、缩写词。
TECH = (
    r"\.(ics|csv|xlsx|json|pdf|zip|apk|mikcb|png|jpg)|https?://|"
    r"\b(URL|API|SDK|HTTP|HTTPS|DNS|ID|UID|IP|PSS|MB|GB|KB|ms|OK|CSV|ICS|XLSX|JSON|PDF|ZIP|APK)\b"
)
# 一个「英文词」：至少两个字母，允许中间撇号与连字符。
WORD = re.compile(r"[A-Za-z][A-Za-z'\-]{1,}")
KANA = re.compile(r"[\u3040-\u30ff]")
HANGUL = re.compile(r"[\uac00-\ud7af]")
CJK = re.compile(r"[\u4e00-\u9fff]")
PLACEHOLDER = re.compile(r"\{[^}]*\}")
BRANDS_RE = re.compile("|".join(re.escape(b) for b in BRANDS))
TECH_RE = re.compile(TECH)
MIN_WORDS = 2

LANGS = ("zh", "zh_HK", "zh_TW", "en", "ja", "ko")

# 刻意例外：基线里这些行**不是未翻译**，是引用了别的资源文件里的字面量。
# 写明在基线头注释里，是为了挡住「半年后的清理者」把它当漏翻删掉。
# 值 = 为什么它是例外（一句话，要能独立看懂）。
DELIBERATE_EXCEPTIONS = {
    "B|ko|spreadsheetStep1Subtitle":
        "引用了模板 CSV 的中文列名（assets/templates/mikcb_course_import_template.csv："
        "课程名/星期/开始节/结束节/上课周…）。韩国用户下载到的就是这份中文表头，"
        "把列名译成韩文会让人在文件里找不到那一列；en / ja 同口径。改这一条必须同时改模板本体。",
}



def load(lang: str) -> dict[str, str]:
    raw = json.loads((ARB_DIR / ("app_%s.arb" % lang)).read_text(encoding="utf-8"))
    return {k: v for k, v in raw.items() if not k.startswith("@") and isinstance(v, str)}


def word_count(value: str) -> int:
    """剥掉占位符 / 品牌 / 技术标识后剩下的英文词数。"""
    rest = PLACEHOLDER.sub("", value)
    rest = BRANDS_RE.sub("", rest)
    rest = TECH_RE.sub("", rest)
    return len(WORD.findall(rest))


def rule_a(lang: str, value: str, en_value: str) -> bool:
    """未翻译：等于英文、无本地文字、过白名单后仍有 ≥2 词。"""
    if lang not in ("ja", "ko"):
        return False
    if value != en_value or not value.strip():
        return False
    native = KANA if lang == "ja" else HANGUL
    if native.search(value):
        return False
    return word_count(value) >= MIN_WORDS


def rule_b(lang: str, value: str) -> bool:
    """中文污染：en / ko 里出现汉字。"""
    if lang not in ("en", "ko"):
        return False
    return bool(CJK.search(value))


def violations(arb: dict[str, dict[str, str]]) -> dict[str, list[str]]:
    """{'A|ja': [keys...], 'B|en': [keys...]} —— 排序稳定，供基线与测试使用。

    两条规则各自独立判定：一条值既可能「未翻译」又「混入中文」（例如 en 里带中文的
    那句被 ja/ko 原样抄过去），这种会同时出现在 A 和 B 下，不去重。
    """
    en = arb["en"]
    out: dict[str, list[str]] = {}
    for lang in ("en", "ja", "ko"):
        for key, value in arb[lang].items():
            if rule_a(lang, value, en.get(key, "")):
                out.setdefault("A|" + lang, []).append(key)
            if rule_b(lang, value):
                out.setdefault("B|" + lang, []).append(key)
    for k in out:
        out[k].sort()
    return out


def flatten(found: dict[str, list[str]]) -> list[str]:
    return sorted("%s|%s" % (group, key) for group, keys in found.items() for key in keys)


def load_baseline() -> list[str]:
    if not BASELINE.is_file():
        print("基线文件不存在：%s（先跑 --write）" % BASELINE.relative_to(ROOT))
        return []
    lines = []
    for line in BASELINE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        lines.append(line)
    return lines


def header() -> str:
    out = [
        "# i18n 文案缺口基线（棘轮：只许降不许升）",
        "# 生成：python scripts/i18n-copy-gap.py --write（判据见脚本头注释）",
        "# 规则版本 RULES_VERSION=%d，白名单版本 WHITELIST_VERSION=%d" % (RULES_VERSION, WHITELIST_VERSION),
        "# 格式：<规则>|<语种>|<ARB 键>；A=未翻译（ja/ko 值逐字等于 en 且无本地文字、过白名单后 ≥%d 个英文词）" % MIN_WORDS,
        "#       B=中文污染（en/ko 值里出现汉字）。ja 不走 B（日语本来用汉字）。",
        "# 白名单（v%d）：品牌 %d 个（%s…）；技术标识 %s；剥掉后英文词 < %d 的短标签不判。"
        % (WHITELIST_VERSION, len(BRANDS), "、".join(BRANDS[:6]), "扩展名/URL/缩写词", MIN_WORDS),
        "# 修好一条要同步删掉对应行；新增缺口会直接让 CopyGapGateTest 变红。",
    ]
    if DELIBERATE_EXCEPTIONS:
        out.append("#")
        out.append("# ⚠ 刻意例外（不是未翻译，别当漏翻删掉）：")
        for line, why in DELIBERATE_EXCEPTIONS.items():
            out.append("#   %s" % line)
            out.append("#     → %s" % why)
        out.append("#   清理基线的正确姿势：只删「已翻译好」的行；上面这些行若要删，必须同时改掉它引用的资源本体。")
    out.append("")
    return "\n".join(out)


def compare(old: list[str], new: list[str]):
    """逐行比对新旧缺口集合，返回 (blockers, lowers)。

    blockers = 新增缺口（新里有、旧里没有）→ 棘轮**必须**拒绝，否则「改 ARB → --write → 绿」
               就是一条合法的自我洗白路径。
    lowers   = 缺口消失（旧里有、新里没有）→ 允许落盘，`--check` 会要求执行者下调。

    与 `scripts/i18n-cjk-baseline.py` 的 `compare()` 同口径：那边按文件计数比，这边按
    「规则|语种|键」逐行进退，判据都是「只许降不许升」。
    """
    old_set, new_set = set(old), set(new)
    blockers = [x for x in new if x not in old_set]
    lowers = [x for x in old if x not in new_set]
    return blockers, lowers


def describe(line: str, before: int, after: int) -> str:
    """一条「键：旧 → 新」。新增/退出单独标出来，人一眼能看懂方向。"""
    if before == 0:
        return "  + %s：0 → 1（新增缺口）" % line
    if after == 0:
        return "  - %s：1 → 0（已修复）" % line
    arrow = "↑" if after > before else "↓"
    return "  %s %s：%d → %d" % (arrow, line, before, after)


def do_write(arb: dict[str, dict[str, str]]) -> int:
    """重写基线。**先把上调全部挡下来，挡完才落盘**——绝不写一半。"""
    new_lines = flatten(violations(arb))
    old_lines = load_baseline()
    blockers, lowers = compare(old_lines, new_lines)

    if blockers:
        print("拒绝：棘轮只降不升，检测到新增缺口 %d 条（一处都不放行）：" % len(blockers))
        for line in blockers[:60]:
            print(describe(line, 0, 1))
        if len(blockers) > 60:
            print("  …还有 %d 条" % (len(blockers) - 60))
        print("一个字节都没写。新文案要六份 ARB 同步；修好了缺口才降基线，"
              "不要靠重写基线放行。")
        return 1

    # 刻意例外必须「还在缺口集合里」：若某条例外已不成立（被人修好/删了），
    # 基线里那句「为什么」就成了假话——要求改代码把它摘掉，而不是让它悄悄残留。
    stale = stale_exceptions(new_lines)
    if stale:
        print("拒绝：基线头里的刻意例外已不成立 %d 条（它们不再是缺口）：" % len(stale))
        for line in stale:
            print("  - %s" % line)
        print("请从 scripts/i18n-copy-gap.py 的 DELIBERATE_EXCEPTIONS 里删掉这些条目"
              "（这是代码改动，应当出现在 diff 里），再重跑 --write。一个字节都没写。")
        return 1

    BASELINE.write_text(header() + "\n".join(new_lines) + "\n", encoding="utf-8", newline="\n")
    msg = "已写入基线：%s（%d 条）" % (BASELINE.relative_to(ROOT), len(new_lines))
    if lowers:
        msg += "；同时下调 %d 条" % len(lowers)
    else:
        msg += "；无升降（内容未变）"
    if DELIBERATE_EXCEPTIONS:
        msg += "；刻意例外 %d 条已写进头注释" % len(DELIBERATE_EXCEPTIONS)
    print(msg)
    return 0


def stale_exceptions(current: list[str]) -> list[str]:
    """返回已经不再是缺口的「刻意例外」条目。

    它们仍挂在 DELIBERATE_EXCEPTIONS 里，基线头就会继续断言一个不成立的事实。
    处理方式只有一种：改代码把条目摘掉（可 review），不允许基线悄悄分叉。
    """
    present = set(current)
    return [line for line in DELIBERATE_EXCEPTIONS if line not in present]


def do_check(arb: dict[str, dict[str, str]]) -> int:
    actual = flatten(violations(arb))
    baseline = load_baseline()
    blockers, lowers = compare(baseline, actual)  # blockers = 新增缺口（红）
    if not blockers and not lowers:
        stale = stale_exceptions(actual)
        if stale:
            print("文案缺口门禁失败：基线头的「刻意例外」已不成立 %d 条：" % len(stale))
            for line in stale:
                print("  - %s" % line)
            print("请从 scripts/i18n-copy-gap.py 的 DELIBERATE_EXCEPTIONS 里删掉它们。")
            return 1
        print("文案缺口基线一致：%d 条（RULES v%d / WHITELIST v%d，刻意例外 %d 条）"
              % (len(actual), RULES_VERSION, WHITELIST_VERSION, len(DELIBERATE_EXCEPTIONS)))
        return 0
    print("文案缺口门禁失败：新增 %d 条、该降未降 %d 条" % (len(blockers), len(lowers)))
    for line in blockers[:40]:
        print(describe(line, 0, 1))
    for line in lowers[:40]:
        print(describe(line, 1, 0))
    print("缺口消除后请执行：python scripts/i18n-copy-gap.py --write"
          "（它只允许下调，新增缺口会被拒）")
    return 1


def do_probe() -> int:
    """三条咬合探针：两条必须咬、一条必须不咬。"""
    cases = [
        ("ja 塞英文", rule_a("ja", "This course is still running", "This course is still running"), True),
        ("ko 塞中文", rule_b("ko", "轻屿课表·{profileName}"), True),
        ("en 塞中文", rule_b("en", "Supports 上课周 import"), True),
        ("ja 同形词 保存", rule_a("ja", "保存", "保存"), False),
        ("ja 短标签 WebDAV URL", rule_a("ja", "WebDAV URL", "WebDAV URL"), False),
        ("ja 正常日文", rule_a("ja", "この壁紙は使用中です", "この壁紙は使用中です"), False),
    ]
    bad = 0
    for name, got, want in cases:
        ok = got == want
        bad += 0 if ok else 1
        print("%s %s：期望 %s，实际 %s" % ("PASS" if ok else "FAIL", name, want, got))
    print("探针 %d/%d 通过" % (len(cases) - bad, len(cases)))
    return 1 if bad else 0


def do_stats(arb: dict[str, dict[str, str]]) -> int:
    found = violations(arb)
    total = sum(len(v) for v in found.values())
    print("规则 v%d / 白名单 v%d，共 %d 条缺口：" % (RULES_VERSION, WHITELIST_VERSION, total))
    for group in sorted(found):
        print("  %-6s %4d" % (group, len(found[group])))
    prefix: dict[str, int] = {}
    for key in found.get("A|ja", []):
        m = re.match(r"[a-z]+", key)
        if m:
            prefix[m.group(0)] = prefix.get(m.group(0), 0) + 1
    print("  A|ja 前缀分布：", ", ".join("%s %d" % (k, v) for k, v in
                                        sorted(prefix.items(), key=lambda x: -x[1])[:10]))
    return 0


def do_probe_write() -> int:
    """端到端探针：人为造一次上调 → `--write` 必须拒绝且基线字节不变；还原后 → 允许。

    做法：挑一条「ja 有假名、en 是多词且不同」的键，把 ja 的值**就地**改成 en 的值
    （只替换那一行，文件其余部分逐字节不动），于是多出一条基线里没有的 `A|ja|键`。
    然后跑真正的 CLI `--write`：
      · 必须 exit 1、输出含「拒绝」与该键、基线 sha256 不变；
    再按字节还原 ja，跑 `--write`：
      · 必须 exit 0，且基线 sha256 仍不变（没有缺口下降就不该动字节）。
    """
    import hashlib
    import shutil
    import subprocess
    import tempfile

    def sha(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    ja_path = ARB_DIR / "app_ja.arb"
    base_sha0, ja_sha0 = sha(BASELINE), sha(ja_path)
    backup = tempfile.NamedTemporaryFile(delete=False, suffix=".arb")
    backup.close()
    shutil.copy2(ja_path, backup.name)

    failures = 0

    def check(ok: bool, label: str, detail: str = "") -> None:
        nonlocal failures
        failures += 0 if ok else 1
        print("%s %s%s" % ("PASS" if ok else "FAIL", label, ("：" + detail) if detail else ""))

    try:
        ja = json.loads(ja_path.read_text(encoding="utf-8"))
        en = json.loads((ARB_DIR / "app_en.arb").read_text(encoding="utf-8"))
        target = None
        for key, value in ja.items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            if not KANA.search(value):
                continue
            en_value = en.get(key)
            if isinstance(en_value, str) and en_value != value and word_count(en_value) >= MIN_WORDS:
                target = (key, value, en_value)
                break
        if target is None:
            print("FAIL 找不到可用于造缺口的键（探针失效，不是门禁问题）")
            return 1
        key, old_value, en_value = target

        # 只替换那一行，其余字节不动
        raw = ja_path.read_text(encoding="utf-8")
        old_line = '"%s": %s,' % (key, json.dumps(old_value, ensure_ascii=False))
        new_line = '"%s": %s,' % (key, json.dumps(en_value, ensure_ascii=False))
        assert raw.count(old_line) == 1, "注入行不唯一，换一个样本"
        ja_path.write_text(raw.replace(old_line, new_line), encoding="utf-8", newline="\n")

        run = subprocess.run([sys.executable, str(Path(__file__)), "--write"],
                             cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8")
        check(run.returncode != 0, "造出上调后 --write 拒绝", "exit %d" % run.returncode)
        check("拒绝" in run.stdout, "拒绝信息可读", run.stdout.strip().splitlines()[0] if run.stdout.strip() else "（无输出）")
        check(("A|ja|" + key) in run.stdout, "拒绝信息点名到键", "A|ja|%s" % key)
        check(sha(BASELINE) == base_sha0, "拒绝后基线 sha256 不变", sha(BASELINE)[:16])
    finally:
        shutil.copy2(backup.name, ja_path)
        Path(backup.name).unlink(missing_ok=True)

    check(sha(ja_path) == ja_sha0, "还原后 ja ARB sha256 与注入前一致", sha(ja_path)[:16])
    run2 = subprocess.run([sys.executable, str(Path(__file__)), "--write"],
                          cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8")
    check(run2.returncode == 0, "还原后 --write 允许执行", "exit %d" % run2.returncode)
    check(sha(BASELINE) == base_sha0, "无缺口下降时基线字节不变", sha(BASELINE)[:16])

    print("端到端探针 %s（失败 %d 项）" % ("全部通过" if failures == 0 else "有失败", failures))
    return 1 if failures else 0


def main() -> int:
    arb = {lang: load(lang) for lang in LANGS}
    args = sys.argv[1:]
    if "--probe-write" in args:
        return do_probe_write()
    if "--probe" in args:
        return do_probe()
    if "--write" in args:
        return do_write(arb)
    if "--check" in args:
        return do_check(arb)
    do_stats(arb)
    return do_check(arb)


if __name__ == "__main__":
    raise SystemExit(main())
