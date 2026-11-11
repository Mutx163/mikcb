package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.app.AppLocaleRuntime
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 导出日期的 pattern 覆盖守卫（2026-11-11 补）。
 *
 * 为什么需要：`IcsExportModel.EXPORT_DATE_FORMATTERS` 是**手写 pattern 表**（刻意不用
 * `ofLocalizedDate(MEDIUM)`，避免随 JDK 的 CLDR 版本漂，见该表注释）。手写表只覆盖
 * 已登记的语言：界面新增一种（`AppLocaleRuntime.SUPPORTED_TAGS` 多一项）而这里没跟上时，
 * `formatDate` 会**静默回落中文**——界面出了新语言、日期还是「2026年9月1日」，
 * 而且现有测试（逐语言断言）不会红，因为它们断言的是已登记的那些。
 *
 * 本类把两边的集合钉成相等（双向）：
 * - 少一项 ⇒ 该语言界面下的日期会静默回落中文（防止的正是这种「未来新增语言」）；
 * - 多一项 ⇒ 表里登记了界面根本不支持的语言（死条目）。
 *
 * 注意：这条守卫**不是**「日期必须本地化」的主张——它只保证覆盖，不改变格式选择。
 */
class IcsExportLocaleCoverageTest {

    @Test
    fun `日期 pattern 集合必须等于界面支持语言集合`() {
        val supported = AppLocaleRuntime.SUPPORTED_TAGS.toSet()
        val formatted = IcsExportLogic.EXPORT_DATE_FORMATTERS.keys

        assertEquals(
            "导出日期 pattern 与界面支持语言不一致：多出 ${formatted - supported}，" +
                "缺少 ${supported - formatted}。新增语言时必须同步补 " +
                "IcsExportModel.EXPORT_DATE_FORMATTERS 的一条 pattern，" +
                "否则该语言界面下的日期会静默回落中文（且没有任何测试会红）。",
            supported,
            formatted,
        )
    }
}
