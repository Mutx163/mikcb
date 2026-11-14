package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.QingyuAdaptiveRules
import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页限宽内容列接线守卫（R17 收尾，2026-11-14）。
 *
 * 口径：**中宽档与宽屏档都收宽**（内容区宽 ≥600dp，与全站 `shouldLimitContentWidth` 同口径），
 * 把星期栏与周 / 日 / 月三个视图收进**同一个**居中宽列；紧凑档（<600dp，手机竖屏）通栏，
 * 手机上零变化。五件缺一件，首页就与全站别页分叉：
 *
 * 1. 宽窄取值必须走壳层注入的 seam（`rememberQingyuWindowAdaptive`）——Rail 占掉左侧后
 *    窗口宽 ≠ 内容区宽，页内自算断点会把限宽列对着 Rail 底下居中；
 * 2. 页面**直接取** `maxContentWidth`，不许再自己加档位门：注入层已算好「紧凑 ⇒ null /
 *    限宽 ⇒ 640dp」，页内再判一次就是第二套口径。此前用 `isWideScreen` 门（只在 ≥840dp
 *    或 ≥600dp 横扁时收宽）被否——600–840dp 竖屏平板会漏限，首页成为全站唯一「某一档通栏」
 *    的页（2026-11-14 拍板改直取）；
 * 3. 宽列值只有**一个**（`wideContentCap`），星期栏与正文列各取一份必然错位；
 * 4. 收宽必须在 `fillMaxWidth` **之前**——反过来 `widthIn` 只夹得住子节点，夹不住自己；
 * 5. 正文列收宽后要居中（`Alignment.CenterHorizontally`），否则整块正文贴左。
 *
 * 判据读法：接线/结构类，走中性化档（剥注释 + 抹字符串），注释里提到 `wideContentCap`
 * 不算数——「把目标行注释掉」必须变红（见 `docs/reference/source-guard-writing.md` §四）。
 */
class TimetableWideContentColumnGuardTest {

    private val weekPageSource: String by lazy {
        readKotlinSourceNoStrings(WEEK_PAGE_PATH)
    }

    @Test
    fun `限宽取值必须走壳层注入 seam，不许页内再判档位`() {
        assertSourceContains(weekPageSource, "rememberQingyuWindowAdaptive()", WEEK_PAGE_PATH)
        assertSourceContains(
            weekPageSource,
            "val wideContentCap: Dp? = rememberQingyuWindowAdaptive().maxContentWidth",
            WEEK_PAGE_PATH,
        )
        // 直调判据对象 = 按窗口宽算；Rail 在场时内容区宽 ≠ 窗口宽，限宽列会对着 Rail 居中。
        assertSourceLacks(weekPageSource, "QingyuAdaptiveRules", WEEK_PAGE_PATH)
        // 断点数值只许待在 core/QingyuAdaptiveRules（全仓唯一事实源）。
        assertSourceLacks(weekPageSource, "840", WEEK_PAGE_PATH)
        assertSourceLacks(weekPageSource, "640", WEEK_PAGE_PATH)
    }

    @Test
    fun `限宽不许再按宽屏档加门：出现 isWideScreen 即红`() {
        // 反向咬死：无论用 `if (…) … else null` 还是 `takeIf { … }` 把宽屏门加回来，
        // 600–840dp 竖屏平板都会重新变成通栏（2026-11-14 被否掉的写法）。
        assertSourceLacks(weekPageSource, "isWideScreen", WEEK_PAGE_PATH)
    }

    @Test
    fun `手机紧凑档零变化：不到 600dp 时限宽上限必须是 null`() {
        // 页面直接取 maxContentWidth，「null = 通栏」由注入层保证 ⇒ 钉住注入层的两件事：
        // ① 判据是 shouldLimitContentWidth（<600 为 false，手机竖屏零变化）；
        // ② seam 里 maxContentWidth = 判据 ? 640dp : null。
        assertEquals(
            "599dp 不该限宽：紧凑档必须保持通栏，否则手机竖屏首页会突然变窄",
            false,
            QingyuAdaptiveRules.shouldLimitContentWidth(599f),
        )
        assertEquals(
            "600dp 应当开始限宽：中宽档与全站页面同口径",
            true,
            QingyuAdaptiveRules.shouldLimitContentWidth(600f),
        )
        assertSourceContains(
            readKotlinSourceNoStrings(COMPONENT_PATH),
            "maxContentWidth = if (QingyuAdaptiveRules.shouldLimitContentWidth(widthDp))",
            COMPONENT_PATH,
        )
    }

    @Test
    fun `同一个宽列值必须喂给星期栏与正文列`() {
        assertEquals(
            "wideContentCap 必须恰好五处（声明 1 + 星期栏「判空 1 / widthIn 1」+ " +
                "正文列「判空 1 / widthIn 1」）：多一处就是第二套宽度，两块会错位",
            5,
            countOf("wideContentCap"),
        )
        assertEquals(
            "星期栏与正文列都要过同一个限宽门（if (wideContentCap != null)）",
            2,
            countOf("wideContentCap != null"),
        )
        assertSourceContains(weekPageSource, "Modifier.widthIn(max = wideContentCap)", WEEK_PAGE_PATH)
    }

    @Test
    fun `正文列收宽必须在 fillMaxWidth 之前，并且居中`() {
        val alignAt = weekPageSource.indexOf(".align(Alignment.CenterHorizontally)")
        assertTrue(
            "正文内容盒子没有 .align(Alignment.CenterHorizontally) —— 收宽后整块正文会贴在左边",
            alignAt >= 0,
        )
        val widthInAt = weekPageSource.lastIndexOf(".widthIn(max = wideContentCap)", alignAt)
        val fillAt = weekPageSource.lastIndexOf(".fillMaxWidth()", alignAt)
        val weightAt = weekPageSource.lastIndexOf(".weight(1f)", alignAt)
        assertTrue(
            "正文内容盒子缺 .widthIn(max = wideContentCap)（或在 .fillMaxWidth 之后）—— " +
                "fillMaxWidth 先拉满时 widthIn 只夹得住子节点、夹不住自己，宽档不生效",
            weightAt in 0 until widthInAt && fillAt > widthInAt,
        )
    }

    @Test
    fun `周 日 月三个视图必须跟着同一个内容盒子走`() {
        // 日视图展开层两支 + 月视图层都是内容盒子的 matchParentSize 孩子：谁改成自己算宽，
        // 宽档上就与星期栏错位。
        assertTrue(
            "内容盒子里只数到 ${countOf(".matchParentSize()")} 处 matchParentSize —— " +
                "周 / 日 / 月三层不全，至少有一层改成了自己算宽",
            countOf(".matchParentSize()") >= 3,
        )
        // 顶栏本批不动：顶栏调用的参数区里不许出现宽列值。
        val topBarAt = weekPageSource.indexOf("TimetableTopBar(")
        val headerAt = weekPageSource.indexOf("TimetableWeekdayHeader(")
        assertTrue("找不到顶栏 / 星期栏的调用点，判据无效", topBarAt >= 0 && topBarAt < headerAt)
        assertSourceLacks(
            weekPageSource.substring(topBarAt, headerAt),
            "wideContentCap",
            "顶栏参数区",
        )
    }

    private fun countOf(needle: String): Int =
        weekPageSource.split(needle).size - 1

    private companion object {
        const val WEEK_PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt"
        const val COMPONENT_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuAdaptive.kt"
    }
}
