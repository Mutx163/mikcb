#!/usr/bin/env python3
"""文案缺口棘轮：挡住「该语种没翻译」与「非中文语种混入中文」。

用法（仓库根）：
    python scripts/i18n-copy-gap.py              # 打印统计 + 与基线的差异
    python scripts/i18n-copy-gap.py --check      # 只比对基线，有新增缺口 / 该降未降则 exit 1
    python scripts/i18n-copy-gap.py --write      # 重写基线（只在缺口减少时用）
    python scripts/i18n-copy-gap.py --probe      # 跑三条咬合探针（判据自检）

基线：android/app/src/test/kotlin/com/mutx163/qingyu/i18n/copy-gap-baseline.txt
Kotlin 侧：CopyGapGateTest.kt —— 判据必须与本文逐字一致，改一边必须改另一边。

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
    return "\n".join([
        "# i18n 文案缺口基线（棘轮：只许降不许升）",
        "# 生成：python scripts/i18n-copy-gap.py --write（判据见脚本头注释）",
        "# 规则版本 RULES_VERSION=%d，白名单版本 WHITELIST_VERSION=%d" % (RULES_VERSION, WHITELIST_VERSION),
        "# 格式：<规则>|<语种>|<ARB 键>；A=未翻译（ja/ko 值逐字等于 en 且无本地文字、过白名单后 ≥%d 个英文词）" % MIN_WORDS,
        "#       B=中文污染（en/ko 值里出现汉字）。ja 不走 B（日语本来用汉字）。",
        "# 白名单（v%d）：品牌 %d 个（%s…）；技术标识 %s；剥掉后英文词 < %d 的短标签不判。"
        % (WHITELIST_VERSION, len(BRANDS), "、".join(BRANDS[:6]), "扩展名/URL/缩写词", MIN_WORDS),
        "# 修好一条要同步删掉对应行；新增缺口会直接让 CopyGapGateTest 变红。",
        "",
    ])


def do_write(arb: dict[str, dict[str, str]]) -> int:
    lines = flatten(violations(arb))
    BASELINE.write_text(header() + "\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print("已写入基线：%s（%d 条）" % (BASELINE.relative_to(ROOT), len(lines)))
    return 0


def do_check(arb: dict[str, dict[str, str]]) -> int:
    actual = flatten(violations(arb))
    baseline = load_baseline()
    added = [x for x in actual if x not in set(baseline)]
    removed = [x for x in baseline if x not in set(actual)]
    if not added and not removed:
        print("文案缺口基线一致：%d 条（RULES v%d / WHITELIST v%d）"
              % (len(actual), RULES_VERSION, WHITELIST_VERSION))
        return 0
    print("文案缺口门禁失败：新增 %d 条、该降未降 %d 条" % (len(added), len(removed)))
    for x in added[:40]:
        print("  新增：", x)
    for x in removed[:40]:
        print("  已修复但基线未下调：", x)
    print("修复后请执行：python scripts/i18n-copy-gap.py --write")
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


def main() -> int:
    arb = {lang: load(lang) for lang in LANGS}
    args = sys.argv[1:]
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
