#!/usr/bin/env python3
"""从 `i18n/app_zh.arb` 导出 `MonthViewStrings.kt`（月视图文案表）。

**唯一目的是保证逐字一致**：ARB 改了要重新跑本脚本，别手改生成物。
用法：`PYTHONIOENCODING=utf-8 python tool/gen_month_view_strings.py`
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB = ROOT / "i18n/app_zh.arb"
OUT = ROOT / "android/app/src/main/kotlin/com/mutx163/qingyu/pages/timetable/month/MonthViewStrings.kt"

# 上屏顺序：工具行/标题 → 议程/空态 → 概览 → 无障碍语义
ORDER = [
    "monthViewTitle", "monthViewPreviousMonth", "monthViewNextMonth",
    "monthViewBackToCurrentMonthShort", "monthViewYearSegment", "monthViewMonthSegment",
    "monthViewHolidayBadge", "monthViewAdjustedWorkdayBadge",
    "monthViewAgendaTitle", "monthViewAgendaEmpty", "monthViewAgendaAddCourse",
    "monthViewEmptyMonthTitle", "monthViewEmptyMonthHint",
    "monthOverviewTitle", "monthOverviewDaysTitle", "monthOverviewScheduledDays",
    "monthOverviewMoreDays",
    "monthViewDaySemantics", "monthViewCourseCountSemantics",
    "monthViewExamCountSemantics", "monthViewScheduleCountSemantics",
]


def esc(text: str) -> str:
    """Kotlin 字符串字面量转义。"""
    return (text.replace("\\", "\\\\").replace('"', '\\"')
            .replace("$", "\\$").replace("\n", "\\n"))


def main():
    arb = json.loads(ARB.read_text(encoding="utf-8"))
    month_keys = [k for k in arb
                  if not k.startswith("@") and ("monthView" in k or k.startswith("monthOverview"))]
    unclassified = [k for k in month_keys if k not in ORDER]
    if unclassified:
        raise SystemExit(f"ARB 出现未归类的新键，先补进 ORDER：{unclassified}")
    absent = [k for k in ORDER if k not in arb]
    if absent:
        raise SystemExit(f"ARB 里缺少这些键：{absent}")

    rows = []
    vals = []
    names = []
    for key in ORDER:
        name = key[0].lower() + key[1:]
        vals.append(f'    val {name} = ArbText("{key}", "{esc(arb[key])}")')
        names.append(name)
    # allTexts 直接复用逐键对象，**不重抄字面量**：否则两份字符串可能漂，
    # 而对拍测试只扫 allTexts 那一份（2026-10-27 month-calendar 提出的坑）。
    body = "\n".join(f"        {n}," for n in names)
    accessors = "\n".join(vals)

    kotlin = f'''package com.mutx163.qingyu.pages.timetable.month

/**
 * 月视图用到的全部 ARB 文案（`i18n/app_zh.arb`）。
 *
 * **逐字抄录，不许改写**：每一条都在 [MonthViewStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。表里只收录月视图真正上屏的 `monthView*` / `monthOverview*` 键。
 *
 * ⚠️ 本文件由 `tool/gen_month_view_strings.py` 从 ARB 直接生成，**不要手改**；
 * ARB 改了要重新生成，否则对拍测试会指出差异。
 */
object MonthViewStrings {{

{accessors}

    /** ARB 里的原始键值对：`(键, 中文原文)`，供逐字对拍测试扫全集。 */
    val allTexts: List<ArbText> = listOf(
{body}
    )
}}

/**
 * ARB 文本句柄：键名 + 中文原文 + 占位符填充。
 *
 * 与 `pages/timetable/TimetableStrings.kt` 里那份同构（那边是周视图的）。之所以不跨包
 * 复用：两边各自的对拍测试按包定位 ARB 键，共用会让「谁漏了键」变模糊。
 */
data class ArbText(val key: String, val zh: String) {{
    /** 替换模板中的单占位符（`{{name}}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{{$name}}", value)

    /** 替换模板中的多个占位符。 */
    fun filled(vararg pairs: Pair<String, String>): String {{
        var result = zh
        for ((name, value) in pairs) {{
            result = result.replace("{{$name}}", value)
        }}
        return result
    }}
}}
'''
    OUT.write_text(kotlin, encoding="utf-8")
    print(f"已生成 {OUT.relative_to(ROOT)}（{len(ORDER)} 条文案）")


if __name__ == "__main__":
    main()
