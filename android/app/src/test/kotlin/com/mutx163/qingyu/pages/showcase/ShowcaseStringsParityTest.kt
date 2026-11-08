package com.mutx163.qingyu.pages.showcase

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Miuix 展示册文案逐字对拍测试。
 *
 * 验证：
 * 1. 屏上文案不为空，键名唯一且符合规范；
 * 2. 13 个分类标题钉死为既定字面量（去 Flutter 化 P4-C 前对应 Dart 源文件
 *    `lib/screens/miuix_showcase_screen.dart` 的 13 类标题）；
 * 3. 占位符插值函数按预期生成文案。
 */
class ShowcaseStringsParityTest {

    @Test
    fun `文案全集非空且键名唯一`() {
        val texts = ShowcaseStrings.allTexts
        assertTrue("展示册文案不应少于 50 条，实际为 ${texts.size}", texts.size >= 50)

        val keys = mutableSetOf<String>()
        for (item in texts) {
            assertTrue("键名不应为空", item.key.isNotBlank())
            assertTrue("文本不应为空: ${item.key}", item.zh.isNotBlank())
            assertTrue("重复的文案键名: ${item.key}", keys.add(item.key))
        }
    }

    @Test
    fun `占位符插值函数正常工作`() {
        val text1 = ShowcaseStrings.showcaseCategoryCountLabel.filled("count", "13")
        assertEquals("共 13 类组件演示", text1)

        val text2 = ShowcaseStrings.pickerCurrentTime.filled("time", "08:30")
        assertEquals("当前时间：08:30", text2)

        val text3 = ShowcaseStrings.pickerCurrentDate.filled("date", "2026-07-26")
        assertEquals("当前日期：2026-07-26", text3)

        val text4 = ShowcaseStrings.pickerColorSpace.filled("space", "OkHSV")
        assertEquals("色彩空间：OkHSV", text4)

        val text5 = ShowcaseStrings.overlayCounterLabel.filled("count", "5")
        assertEquals("计数器：5", text5)

        val text6 = ShowcaseStrings.navCurrentSelected.filled("tab", "热门")
        assertEquals("当前选中：热门", text6)
    }

    @Test
    fun `13类分类标题钉死为既定字面量`() {
        // 去 Flutter 化（P4-C，2026-11-08）后 Dart 参照物已删：原先这里是逐字对拍 Dart 源中
        // `title: '…'` 13 条，现在按 Kotlin 文案表本身钉死——改标题必红，标题来源是
        // 展示册分类目录（`ShowcaseStrings` 的 cat*Title）与目录条目数。
        val expectedTitles = listOf(
            "按钮 Button",
            "输入 Input",
            "菜单选择 Menus",
            "显示 Display",
            "列表项 Item",
            "选择器 Pickers",
            "反馈 Feedback",
            "浮层 Overlays",
            "导航 Navigation",
            "实用 Utility",
            "主题 Theming",
            "模糊 Blur",
            "基础 Foundation",
        )

        val actualTitles = ShowcaseStrings.allTexts.map { it.zh }
            .filter { it in expectedTitles }
        assertEquals(
            "13 类标题应逐字在文案表里各出现一次",
            expectedTitles.toSet(),
            actualTitles.toSet(),
        )
        assertEquals("文案表里 13 类标题不应有重复", 13, actualTitles.size)

        // 对拍分类条目总数
        assertEquals(13, MiuixShowcaseCatalog.allEntries.size)
        assertEquals(13, ShowcaseCategoryId.values().size)
    }
}
