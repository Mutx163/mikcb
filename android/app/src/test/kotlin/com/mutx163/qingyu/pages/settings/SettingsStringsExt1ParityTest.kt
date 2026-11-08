package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `SettingsStringsExt1` 的文案逐条等于 `i18n/app_zh.arb`（模板语言 zh）。
 *
 * ## 为什么补这一条（一轮审核 P2）
 *
 * 设置族的文案表分成 `SettingsStrings` + `Ext1..Ext5`。其中 Ext3 / Ext4 / Ext5 与
 * `Ext2` 都有逐字对拍，**只有 Ext1 没有**（它是外观页/外观编辑页的文案来源，
 * 2026-10-29 的外观编辑页批次又往里面加了 30 余条）。没有对拍 = 「文案被改写、
 * 键被写错」只能靠人眼，正是本仓最忌讳的那种漏。
 *
 * ## 为什么用反射而不是像 Ext2 那样列一份清单
 *
 * Ext1 不像 Ext2 有 `all()`，而它正被另一条泳道持续追加。手写清单会立刻过期，
 * 过期清单比没有清单更糟（它会把新加的键静默排除在对拍之外）。反射读
 * **所有返回 `ArbText` 的无参 getter**，新加一条自动纳入；条数下限兜住「反射失效 ⇒ 空跑绿」。
 */
class SettingsStringsExt1ParityTest {

    private fun entries(): List<ArbText> =
        SettingsStringsExt1::class.java.methods
            .filter { it.parameterCount == 0 && ArbText::class.java.isAssignableFrom(it.returnType) }
            .mapNotNull { method ->
                runCatching { method.invoke(SettingsStringsExt1) as? ArbText }.getOrNull()
            }
            .distinctBy { it.key }

    @Test
    fun `反射真的读到了 Ext1 的文案表`() {
        val table = entries()
        assertTrue(
            "只读到 ${table.size} 条 —— 反射失效会让下面那条空跑成绿",
            table.size >= 40,
        )
    }

    @Test
    fun `Ext1 的每条文案都与 ARB 逐字一致`() {
        val table = entries()
        val bad = table.filter { !matchesArb(it.key, it.zh) }
            .map { "${it.key}: kotlin=`${it.zh}` arb=`${ArbZh.value(it.key)}`" }
        assertEquals("这些 Ext1 文案与 app_zh.arb 不一致：", emptyList<String>(), bad)
    }

    @Test
    fun `Ext1 的键都在 ARB 里存在`() {
        val missing = entries().map { it.key }.filter { it !in ArbZh.strings }
        assertEquals("这些键在 app_zh.arb 里不存在：", emptyList<String>(), missing)
    }

    /** 占位符模板按「片段按序出现」判定（与 Ext3/Ext4 的 helper 同口径）。 */
    private fun matchesArb(key: String, text: String): Boolean {
        val template = ArbZh.strings[key] ?: return false
        if (!template.contains('{')) return template == text
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            if (idx < 0) return false
            cursor = idx + segment.length
        }
        return true
    }
}
