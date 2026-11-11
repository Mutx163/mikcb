package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日程页「颜色快捷行」契约（2026-11-10 回到发布版形态）。
 *
 * 发布版 v2.1.4.1 `add_schedule_item_screen.dart` 的 `_buildColorPalette`：
 * 32dp 方块、圆角 8、间距 8 的**横向滚动**快捷行，行尾跟一颗调色盘入口
 * （点开全色取色）；选中态是 2dp 前景色描边 + 勾。
 *
 * 此前这里被改成 FlowRow 自动换行的一整片色阵，与发布版不一致，用户对照能看出来；
 * 现在回到「一行横滚 + 行尾调色盘」，色块仍用共享组件、尺寸走 `QuickRow`（32dp）。
 *
 * 读源码走 `testutil` 共享剥离（2026-11-11 迁移）：结构/门控类判据用
 * [readKotlinSourceNoStrings]；`item(key = "presets")` 这个锚点**靠字符串字面量**，
 * 只能从保留字面量的 [readKotlinSourceNormalized] 上找，再按下标到中性化文本里判门控
 * （两档剥法长度一致，下标可互通，本文件有断言钉住这个前提）。
 */
class ScheduleColorEntryGuardTest {

    @Test
    fun `颜色快捷行是发布版形态 横滚 + 行尾调色盘`() {
        val source = structuralSource()
        assertFalse(
            "加日程的颜色行回到了发布版的一行横滚，不再用自动换行的 FlowRow 容器",
            source.contains("QingyuColorChips("),
        )
        assertTrue(
            "快捷行必须横向滚动（发布版 SingleChildScrollView + Row）",
            source.contains("horizontalScroll(rememberScrollState())"),
        )
        assertTrue(
            "色块尺寸必须走共享档位 QuickRow（发布版 swatchSize = 32）；" +
                "行首锚定，注释里提到档位名不算数",
            Regex("""^\s*size = QingyuColorChipSize\.QuickRow,""", RegexOption.MULTILINE).containsMatchIn(source),
        )
        assertTrue(
            "行尾必须有调色盘入口（发布版 `_buildPaletteSwatch(colorHex = null)`）",
            source.contains("colorPickerOpen = true"),
        )
        assertTrue(
            "调色盘入口的读屏名走既有 ARB 键 customPaletteAction",
            source.contains("ScheduleStrings.customPaletteAction.text"),
        )
    }

    @Test
    fun `取色弹层必须常驻组合 显隐只由 show 驱动`() {
        val source = structuralSource()
        assertTrue(
            "取色弹层必须常驻组合，显隐由 `show = colorPickerOpen` 驱动",
            source.contains("show = colorPickerOpen"),
        )
        assertFalse(
            "禁止条件挂载：`if (colorPickerOpen) { OverlayDialog(show = true) }` " +
                "会在关闭那一帧把整棵弹层摘出组合，官方退场动画一次都播不出来",
            Regex("""^\s*if \(colorPickerOpen\) \{""", RegexOption.MULTILINE).containsMatchIn(source),
        )
        assertTrue(
            "确认取色后把颜色写回同一处状态（selectedColor），不新增第二条写路径",
            source.contains("selectedColor = hex"),
        )
    }

    @Test
    fun `快捷模板在编辑态也展示 不再按 isEditing 门控`() {
        val literal = literalSource()
        val structural = structuralSource()
        assertEquals(
            "两档剥法必须长度一致（中性化只换字符、不删字符），否则下面的下标复用了错位",
            literal.length,
            structural.length,
        )

        val anchor = "item(key = \"presets\")"
        assertTrue(
            "快捷模板条目必须还在（有意保留的超出发布版能力）",
            literal.contains(anchor),
        )
        // 只锚在 presets 条目块内判门控：页面别处有 `if (!isEditing)` 属正常逻辑，不该被这条误伤。
        val presetsStart = literal.indexOf(anchor)
        assertTrue("找不到 presets 条目", presetsStart >= 0)
        val nextItem = literal.indexOf("item(key = ", presetsStart + 1)
        val end = if (nextItem > presetsStart) nextItem else literal.length
        val presetsBlock = structural.substring(presetsStart, end)
        assertFalse(
            "快捷模板块不许再被 `if (!isEditing)` 门控——用户在预览验收时要求编辑态也能用",
            presetsBlock.contains("if (!isEditing)"),
        )
    }

    /** 接线/结构类判据：剥注释 + 中性化字符串。 */
    private fun structuralSource(): String = readKotlinSourceNoStrings(PAGE)

    /** 需要看字符串字面量的判据：剥注释、保留字面量。 */
    private fun literalSource(): String = readKotlinSourceNormalized(PAGE)

    private companion object {
        const val PAGE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt"
    }
}
