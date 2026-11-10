package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeMatchLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `LocationTimeMatchLogic` 的正则常量 + 归一化缓存（2026-11-10 性能修复）的**等价性**守卫。
 *
 * ## 为什么必须钉等价性
 *
 * 这次把「每次调用新建 `Regex`」改成文件级常量、并给归一化结果加了有界缓存——
 * 这是「时间模板页转圈很久 / 新建模板点确定卡住」的根因修复，但它动了**匹配判定本身**
 * 依赖的那个函数。缓存写错（例如把未 trim 的串当键、或命中后返回别的串）会让地点匹配
 * 静默错配：用户看不出红，只有某几门课悄悄换了作息。
 *
 * 所以这里不测「快不快」，只测「改了以后结果一模一样」：
 * 同一输入重复调用稳定、全角/空格/括号口径不变、命中结果与优先级不变。
 */
class LocationTimeMatchNormalizeEquivalenceTest {

    private fun group(
        id: String,
        name: String,
        priority: Int,
        timeSchemeId: String,
        enabled: Boolean = true,
        patterns: List<String>,
    ) = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = timeSchemeId,
        enabled = enabled,
        priority = priority,
        keywords = patterns.map { LocationKeyword(it, LocationKeywordMatchMode.CONTAINS) },
    )

    @Test
    fun `归一化口径没变：全角转半角、去空白、括号内容保留`() {
        assertEquals("a栋东区", LocationTimeMatchLogic.normalizeLocation("Ａ栋（东区）"))
        assertEquals("a栋东区", LocationTimeMatchLogic.normalizeLocation("  A栋( 东区 )  "))
        assertEquals("", LocationTimeMatchLogic.normalizeLocation("   "))
        assertNull("空串不参与匹配", LocationTimeMatchLogic.match("   ", emptyList()))
    }

    @Test
    fun `同一输入重复调用结果稳定（缓存透明）`() {
        val first = LocationTimeMatchLogic.normalizeLocation("教三（东）201")
        repeat(5) {
            assertEquals(
                "第 ${it + 1} 次调用与首次不一致，说明缓存改写了语义",
                first,
                LocationTimeMatchLogic.normalizeLocation("教三（东）201"),
            )
        }
        assertEquals(
            "首尾空白必须不影响结果（缓存键取 trim 后的串）",
            first,
            LocationTimeMatchLogic.normalizeLocation("  教三（东）201  "),
        )
    }

    @Test
    fun `长关键词优先、等长按优先级——缓存与预计算没有改变排序`() {
        val groups = listOf(
            group("g1", "短关键词组", priority = 10, timeSchemeId = "ts-short", patterns = listOf("教三")),
            group("g2", "长关键词组", priority = 1, timeSchemeId = "ts-long", patterns = listOf("教三东")),
        )
        val result = LocationTimeMatchLogic.match("教三东201", groups)
        assertNotNull(result)
        assertEquals(
            "长关键词（教三东）必须压过优先级更高但更短的（教三）",
            "ts-long",
            result!!.timeSchemeId,
        )
    }

    @Test
    fun `停用组与空该组的绑定一律不参与匹配`() {
        val groups = listOf(
            group("g1", "停用组", priority = 10, timeSchemeId = "ts-disabled", enabled = false, patterns = listOf("教三")),
            group("g2", "无绑定组", priority = 9, timeSchemeId = "", patterns = listOf("教三")),
            group("g3", "可用组", priority = 1, timeSchemeId = "ts-live", patterns = listOf("教三")),
        )
        val result = LocationTimeMatchLogic.match("教三201", groups)
        assertNotNull(result)
        assertEquals("ts-live", result!!.timeSchemeId)
    }
}
