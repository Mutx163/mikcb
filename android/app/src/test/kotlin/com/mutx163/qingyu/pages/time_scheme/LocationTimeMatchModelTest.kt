package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 地点作息匹配页模型层测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/location_time_match_screen.dart`）：
 * - 卡片副标题：`'${boundScheme(schemeName)} · ${keywordsLine(keywordText)}'`（:116-118）；
 * - 未知模板兜底：`firstOrNull ?? l10n.locationTimeMatchUnknownScheme`（:100-104）；
 * - 无关键词兜底：`group.keywordSummary.isEmpty ? l10n.locationTimeMatchNoKeywords : …`（:105-107）；
 * - 重新匹配三种结果：`matched == 0` / `updated == 0` / 正常改写；
 * - 关键词过短：归一化后长度 < 2；关键词冲突：同名字面上被别的组占用。
 *
 * 归一化与命中判定本身由 [com.mutx163.qingyu.core.LocationTimeMatchLogic] 承担（Phase 2 已迁、
 * 已有独立测试），这里只钉「这一页把结果拼成什么字」。
 */
class LocationTimeMatchModelTest {

    // ── 1. 卡片副标题 ──

    @Test
    fun `副标题是模板名加关键词两段`() {
        val model = LocationTimeMatchModel(
            groups = listOf(
                group(id = "g1", name = "主教学楼", schemeId = "s1", keywords = listOf("A1", "A主")),
            ),
            schemeNames = mapOf("s1" to "夏季作息"),
        )
        val card = model.card("g1")!!
        assertEquals("主教学楼", card.title)
        assertEquals("时间模板：夏季作息 · 关键词：A1, A主", card.subtitle)
        assertFalse(card.keywordsEmpty)
        assertTrue(card.enabled)
    }

    @Test
    fun `绑定的模板被删了显示未知时间模板`() {
        // schemeNames 里没有 s1 → Dart 的 firstOrNull ?? unknownScheme 分支
        val model = LocationTimeMatchModel(
            groups = listOf(group(id = "g1", name = "主教学楼", schemeId = "s1", keywords = listOf("A1"))),
            schemeNames = emptyMap(),
        )
        val card = model.card("g1")!!
        assertEquals("未知时间模板", card.boundSchemeName)
        assertTrue("副标题里也要带出来", card.subtitle.contains("未知时间模板"))
    }

    @Test
    fun `没有关键词时显示未设置关键词`() {
        val model = LocationTimeMatchModel(
            groups = listOf(group(id = "g1", name = "主教学楼", schemeId = "s1", keywords = emptyList())),
            schemeNames = mapOf("s1" to "夏季作息"),
        )
        val card = model.card("g1")!!
        assertTrue(card.keywordsEmpty)
        assertEquals("未设置关键词", card.keywordText)
        assertEquals("时间模板：夏季作息 · 关键词：未设置关键词", card.subtitle)
    }

    @Test
    fun `卡片顺序与组顺序一致`() {
        val model = LocationTimeMatchModel(
            groups = listOf(
                group(id = "a", name = "一组", schemeId = "s1", keywords = listOf("A1")),
                group(id = "b", name = "二组", schemeId = "s1", keywords = listOf("B1")),
            ),
            schemeNames = mapOf("s1" to "作息"),
        )
        assertEquals(listOf("一组", "二组"), model.cards().map { it.title })
    }

    // ── 2. 空态 ──

    @Test
    fun `一组规则都没有时为空态`() {
        assertTrue(LocationTimeMatchModel().isEmpty)
        assertFalse(
            LocationTimeMatchModel(groups = listOf(group(id = "g", name = "x", schemeId = "s"))).isEmpty,
        )
    }

    // ── 3. 试匹配预览 ──

    @Test
    fun `输入为空时没有预览文本`() {
        val model = LocationTimeMatchModel(groups = listOf(group(id = "g1", name = "主楼", schemeId = "s1")))
        assertNull(model.previewText(""))
        assertNull(model.previewText("   "))
    }

    @Test
    fun `命中时给出组名模板名与关键词`() {
        val model = LocationTimeMatchModel(
            groups = listOf(
                group(
                    id = "g1",
                    name = "主教学楼",
                    schemeId = "s1",
                    keywords = listOf("A1"),
                ),
            ),
            schemeNames = mapOf("s1" to "夏季作息"),
        )
        val text = model.previewText("A1062")
        assertEquals("将匹配：主教学楼 · 夏季作息，关键词 A1", text)
    }

    @Test
    fun `未命中时给出未命中提示`() {
        val model = LocationTimeMatchModel(
            groups = listOf(group(id = "g1", name = "主楼", schemeId = "s1", keywords = listOf("A1"))),
            schemeNames = mapOf("s1" to "作息"),
        )
        assertEquals("未命中任何地点组，将使用课表默认时间模板", model.previewText("Z999"))
    }

    @Test
    fun `命中的组模板被删也按未知模板显示不吞后半截`() {
        val model = LocationTimeMatchModel(
            groups = listOf(group(id = "g1", name = "主楼", schemeId = "gone", keywords = listOf("A1"))),
            schemeNames = emptyMap(),
        )
        assertEquals("将匹配：主楼 · 未知时间模板，关键词 A1", model.previewText("A1062"))
    }

    // ── 4. 重新匹配的三种结果 ──

    @Test
    fun `一门都没命中`() {
        val model = LocationTimeMatchModel()
        assertEquals("没有匹配到可套用的课程", model.applyResultMessage(matched = 0, updated = 0))
    }

    @Test
    fun `命中但钟点无需改写`() {
        val model = LocationTimeMatchModel()
        assertEquals("已重新匹配 3 门，钟点无需改写", model.applyResultMessage(matched = 3, updated = 0))
    }

    @Test
    fun `命中且改写了钟点`() {
        val model = LocationTimeMatchModel()
        assertEquals("已重新匹配 3 门，更新 2 门钟点", model.applyResultMessage(matched = 3, updated = 2))
    }

    @Test
    fun `超出节数的附加提示带示例`() {
        val model = LocationTimeMatchModel()
        val text = model.applyOverflowMessage(
            matched = 5,
            overflowCount = 2,
            examples = listOf("体育", "实验"),
        )
        assertTrue("应含匹配门数：$text", text.contains("已匹配 5 门课程"))
        assertTrue("应含超出数：$text", text.contains("另有 2 门"))
        assertTrue("应含示例：$text", text.contains("体育、实验"))
    }

    @Test
    fun `没有示例时只要主句`() {
        val model = LocationTimeMatchModel()
        assertEquals(
            "已匹配 5 门课程。另有 2 门超出模板节数，已取消套用",
            model.applyOverflowMessage(matched = 5, overflowCount = 2, examples = emptyList()),
        )
    }

    @Test
    fun `确认弹层正文带课程门数`() {
        val model = LocationTimeMatchModel()
        val text = model.applyMessage(4)
        assertTrue("应含门数：$text", text.contains("4 门课程"))
        assertEquals("重新匹配当前课表？", model.applyTitle)
        assertEquals("重新匹配", model.applyConfirmLabel)
    }

    // ── 5. 删除确认 ──

    @Test
    fun `删除文案带组名`() {
        val model = LocationTimeMatchModel()
        assertEquals("删除地点组？", model.deleteTitle())
        val message = model.deleteMessage("主教学楼")
        assertTrue("应含组名：$message", message.contains("主教学楼"))
    }

    // ── 6. 编辑页校验 ──

    @Test
    fun `组名为空要报必填`() {
        val model = LocationTimeMatchModel()
        assertEquals("请填写地点组名称", model.validateName(""))
        assertEquals("请填写地点组名称", model.validateName("   "))
        assertNull(model.validateName("主教学楼"))
    }

    @Test
    fun `一个关键词都没有要报必填`() {
        val model = LocationTimeMatchModel()
        assertEquals("请至少添加一个关键词", model.validateKeywords(emptyList()))
        assertEquals("请至少添加一个关键词", model.validateKeywords(listOf("", "  ")))
        assertNull(model.validateKeywords(listOf("A1")))
    }

    @Test
    fun `关键词过短要提示容易误匹配`() {
        val model = LocationTimeMatchModel()
        // 归一化后 1 个字符 → 过短
        assertEquals("关键词过短，容易误匹配", model.keywordTooShortHint("A"))
        // 两个字符是底线，不算过短
        assertNull(model.keywordTooShortHint("A1"))
        assertNull(model.keywordTooShortHint("主楼"))
    }

    @Test
    fun `关键词被别的组占用时指出组名`() {
        val model = LocationTimeMatchModel(
            groups = listOf(
                group(id = "g1", name = "主教学楼", schemeId = "s1", keywords = listOf("A1")),
                group(id = "g2", name = "第二楼", schemeId = "s1", keywords = listOf("B1")),
            ),
        )
        assertEquals("关键词已被 主教学楼 使用", model.keywordOwnerHint("A1", editingGroupId = "g2"))
        // 编辑自己那一组时不该说自己占用自己
        assertNull(model.keywordOwnerHint("A1", editingGroupId = "g1"))
        // 没人用
        assertNull(model.keywordOwnerHint("Z9", editingGroupId = "g2"))
    }

    // ── 7. 匹配方式显示名 ──

    @Test
    fun `三种匹配方式各有 ARB 名称`() {
        val model = LocationTimeMatchModel()
        assertEquals("前缀", model.modeLabel(LocationKeywordMatchMode.PREFIX))
        assertEquals("包含", model.modeLabel(LocationKeywordMatchMode.CONTAINS))
        assertEquals("精确", model.modeLabel(LocationKeywordMatchMode.EXACT))
    }

    // ── 夹具 ──

    private fun group(
        id: String,
        name: String,
        schemeId: String,
        keywords: List<String> = emptyList(),
        enabled: Boolean = true,
    ) = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = schemeId,
        enabled = enabled,
        keywords = keywords.map { LocationKeyword(pattern = it) },
    )
}
