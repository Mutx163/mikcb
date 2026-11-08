#!/usr/bin/env python3
"""从 i18n/app_*.arb 生成 Compose 壳使用的 Kotlin 文案表。

用法（仓库根）：
    python tool/gen_compose_arb_catalog.py            # 生成
    python tool/gen_compose_arb_catalog.py --check    # 只校验现有文件是否最新

为什么生成而不是运行时读 JSON：首帧不付 1MB JSON 解析成本，键缺失在编译期可见。
Kotlin 单方法 64KB 字节码上限：每 300 键一个 `when` 分块，块之间用 `?:` 串起来。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARB_DIR = ROOT / "i18n"
OUT = (
    ROOT / "android" / "app" / "src" / "main" / "kotlin"
    / "com" / "mutx163" / "qingyu" / "app" / "ArbCatalog.kt"
)

# tag（与 AppLocaleRuntime.SUPPORTED_TAGS 一致）→ ARB 文件名
LANGUAGES = [
    ("en", "app_en.arb"),
    ("ja", "app_ja.arb"),
    ("ko", "app_ko.arb"),
    ("zh", "app_zh.arb"),
    ("zh_HK", "app_zh_HK.arb"),
    ("zh_TW", "app_zh_TW.arb"),
]

CHUNK = 300


def load_arb(name: str) -> dict[str, str]:
    raw = json.loads((ARB_DIR / name).read_text(encoding="utf-8"))
    return {k: v for k, v in raw.items() if not k.startswith("@") and isinstance(v, str)}


def kt_string(value: str) -> str:
    out = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("$", "\\$")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f'"{out}"'


def fn_name(tag: str) -> str:
    return "lookup" + tag.replace("_", "")


def build() -> str:
    data = {tag: load_arb(name) for tag, name in LANGUAGES}
    keys = sorted(set().union(*(d.keys() for d in data.values())))

    out: list[str] = []
    out.append("package com.mutx163.qingyu.app")
    out.append("")
    out.append("/**")
    out.append(" * 由 `tool/gen_compose_arb_catalog.py` 从 `i18n/app_*.arb` 生成，**不要手改**。")
    out.append(" *")
    out.append(" * 每条 ARB 的键值原样搬过来。`ArbCatalogTest` 会拿 6 份 ARB 逐键对拍；")
    out.append(" * 手改或 ARB 更新后忘记重跑脚本都会红。重新生成：")
    out.append(" *")
    out.append(" * ```")
    out.append(" * python tool/gen_compose_arb_catalog.py")
    out.append(" * ```")
    out.append(" */")
    out.append("object ArbCatalog {")
    out.append("")
    out.append("    /** 按语言取文案；该语言没有这条键时返回 null（调用方回落中文原文）。 */")
    out.append("    fun text(language: String, key: String): String? = when (language) {")
    for tag, _ in LANGUAGES:
        out.append(f'        "{tag}" -> {fn_name(tag)}(key)')
    out.append("        else -> null")
    out.append("    }")

    for tag, _ in LANGUAGES:
        entries = [(k, data[tag][k]) for k in keys if k in data[tag]]
        name = fn_name(tag)
        chunks = [entries[i : i + CHUNK] for i in range(0, len(entries), CHUNK)]
        out.append("")
        out.append(f"    // ── {tag}（{len(entries)} 条）──")
        if len(chunks) == 1:
            out.append(f"    private fun {name}(key: String): String? = when (key) {{")
            for key, value in chunks[0]:
                out.append(f"        {kt_string(key)} -> {kt_string(value)}")
            out.append("        else -> null")
            out.append("    }")
            continue
        chain = " ?: ".join(f"{name}{i + 1}(key)" for i in range(len(chunks)))
        out.append(f"    private fun {name}(key: String): String? = {chain}")
        for index, chunk in enumerate(chunks, start=1):
            out.append(f"    private fun {name}{index}(key: String): String? = when (key) {{")
            for key, value in chunk:
                out.append(f"        {kt_string(key)} -> {kt_string(value)}")
            out.append("        else -> null")
            out.append("    }")

    out.append("}")
    return "\n".join(out) + "\n"


def main() -> int:
    content = build()
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != content:
            print(f"过期：{OUT}，请运行 python tool/gen_compose_arb_catalog.py")
            return 1
        print("ArbCatalog.kt 是最新的")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(content, encoding="utf-8", newline="\n")
    print(f"写入 {OUT}（{OUT.stat().st_size} 字节）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
