package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 排课记录「时间模板」行的接线契约（发布版 `_buildEntryTimeSchemeField`；
 * 模型层 `timeSchemeIdOverride` 早已原样穿透，缺的只是界面行与壳传参）。
 *
 * 断言三件事：
 * 1. 页面拿到候选（`timeSchemes`）与生效模板名；
 * 2. 每条排课行都能开模板弹层，选择写回 `timeSchemeIdOverride`（null = 跟随当前课表）；
 * 3. 壳把这些参数从快照真正传进来（不传就是死行）。
 */
class AddCourseTimeSchemeWiringGuardTest {

    @Test
    fun `排课行有模板行 选择写回 timeSchemeIdOverride`() {
        val source = pageSource("AddCoursePage.kt")
        assertTrue("缺少 timeSchemes 入参", source.contains("timeSchemes: List<TimeScheme>"))
        assertTrue("缺少 activeTimeSchemeName 入参", source.contains("activeTimeSchemeName: String?"))
        assertTrue("模板行标题必须走 timeSchemeLabel", source.contains("AddCourseStrings.timeSchemeLabel.text"))
        assertTrue("必须走共享模板弹层", source.contains("AddCourseTimeSchemeSheet("))
        assertTrue(
            "选择必须写回 timeSchemeIdOverride（null = 跟随当前课表）",
            source.contains("it.copy(timeSchemeIdOverride = schemeId)"),
        )
        assertTrue(
            "「跟随当前课表」行的文案必须带生效模板名",
            source.contains("AddCourseStrings.followCurrentTimetableWithName"),
        )
        assertTrue("条目行必须能打开模板弹层", source.contains("onOpenTimeSchemePicker"))
    }

    @Test
    fun `壳把时间模板候选与生效模板名传进加课页`() {
        val shell = shellIndexSource()
        assertTrue("壳必须传 timeSchemes", shell.contains("timeSchemes = snapshot.timeSchemes"))
        assertTrue(
            "壳必须按 activeTimeSchemeId 解析生效模板名",
            shell.contains("activeTimeSchemeName = snapshot.timeSchemes.firstOrNull { it.id == snapshot.activeTimeSchemeId }?.name"),
        )
        assertFalse("不许把模板候选写成空表冒充接线", shell.contains("timeSchemes = emptyList()"))
    }

    private fun pageSource(name: String): String {
        val file = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/pages/course/$name")
        assertTrue("${file.path} 不存在", file.isFile)
        return file.readText().replace("\r\n", "\n")
    }

    private fun shellIndexSource(): String {
        val file = File(androidSrc(), "main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
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
