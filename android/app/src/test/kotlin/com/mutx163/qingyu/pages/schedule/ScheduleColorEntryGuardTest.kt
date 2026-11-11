package com.mutx163.qingyu.pages.schedule

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import com.mutx163.qingyu.testutil.stripKotlinComments

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
 * composeP1 源集不进 `src/test` 编译单元，所以读源码文本；找不到文件判失败而不是跳过。
 */
class ScheduleColorEntryGuardTest {

    @Test
    fun `颜色快捷行是发布版形态 横滚 + 行尾调色盘`() {
        val source = pageSource()
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
        val source = pageSource()
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
        val source = pageSource()
        assertTrue(
            "快捷模板条目必须还在（有意保留的超出发布版能力）",
            source.contains("item(key = \"presets\")"),
        )
        // 只锚在 presets 条目块内判门控：页面别处有 `if (!isEditing)` 属正常逻辑，不该被这条误伤。
        val presetsStart = source.indexOf("item(key = \"presets\")")
        assertTrue("找不到 presets 条目", presetsStart >= 0)
        val nextItem = source.indexOf("item(key = ", presetsStart + 1)
        val presetsBlock = if (nextItem > presetsStart) {
            source.substring(presetsStart, nextItem)
        } else {
            source.substring(presetsStart)
        }
        assertFalse(
            "快捷模板块不许再被 `if (!isEditing)` 门控——用户在预览验收时要求编辑态也能用",
            presetsBlock.contains("if (!isEditing)"),
        )
    }

    private fun pageSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        return stripKotlinComments(file.readText().replace("\r\n", "\n"))
    }

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }
}
