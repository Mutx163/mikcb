package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「课程颜色」入口契约（2026-11-10 十色点阵退役）。
 *
 * 发布版 v2.1.4.1 的加课页**没有十色点阵**：`add_course_screen.dart` 那行是
 * `HyperosPickerField(label: courseColorTitle, leading: 20dp 色块)`，点开
 * `showCoursePaletteSheet`（全色调色盘）。我们此前自造的「十色圆点 / 十色点阵」既不是
 * 发布版、也不是 miuix 组件，用户对照发布版会看出来。现在换成发布版的一行「课程颜色」
 * 选择行 + 官方 ColorPicker 弹层。
 *
 * 守护两条：
 * 1. 十色点阵不许回来（`QingyuColorChips` 不再出现在本页）；
 * 2. 取色弹层必须**常驻组合**、显隐只由 `show` 驱动（与 `AddCoursePageMountGuardTest`
 *    同一套弹层口径），否则官方退场动画一次都播不出来。
 *
 * composeP1 源集不进 `src/test` 编译单元，所以读源码文本；找不到文件判失败而不是跳过。
 */
class AddCourseColorEntryGuardTest {

    @Test
    fun `十色点阵退役 课程颜色改为发布版的一行选择器`() {
        val source = pageSource()
        assertFalse(
            "加课页没有十色点阵了（发布版是「课程颜色」选择行 + 全色取色）；" +
                "`QingyuColorChips` 若回来说明点阵又被拼上去了",
            source.contains("QingyuColorChips"),
        )
        assertTrue(
            "「课程颜色」必须是一行选择器（BasicComponent：标题 + 行尾色块/色值）",
            source.contains("AddCourseStrings.courseColorTitle.text"),
        )
        assertTrue(
            "点了这一行要打开官方取色弹层",
            source.contains("onClick = { colorPickerOpen = true }"),
        )
        assertTrue(
            "确认取色后把颜色写回同一处状态（selectedColor），不新增第二条写路径",
            source.contains("selectedColor = hex"),
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
        assertFalse(
            "弹层常驻后不许再写死 `show = true`",
            Regex("""^\s*show = true""", RegexOption.MULTILINE).containsMatchIn(source),
        )
    }

    private fun pageSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        return file.readText().replace("\r\n", "\n")
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
