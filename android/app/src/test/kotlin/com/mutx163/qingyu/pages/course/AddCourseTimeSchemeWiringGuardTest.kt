package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 排课记录「时间模板」行的接线契约（发布版 `_buildEntryTimeSchemeField`；
 * 模型层 `timeSchemeIdOverride` 早已原样穿透，缺的只是界面行与壳传参）。
 *
 * 断言三件事：
 * 1. 页面拿到候选（`timeSchemes`）与生效模板名；
 * 2. 每条排课行都能开模板弹层，选择写回 `timeSchemeIdOverride`（null = 跟随当前课表）；
 * 3. 壳把这些参数从快照真正传进来（不传就是死行）。
 *
 * 读源码走 `testutil` 共享剥离 [readKotlinSourceNoStrings]（2026-11-11 迁移）：
 * 全是接线/结构判据，字符串内容一并中性化——日志或提示语里写同名片段骗不过去。
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
        // C1：行内必须显示保存后真正会用的钟点 + 三种来源文案；
        // 弹层必须带来源副题（地点组 / 课表默认）。
        assertTrue("行内钟点必须来自生效解析", source.contains("entryTimeSchemeValue("))
        assertTrue("地点组命中文案必须接上", source.contains("locationTimeMatchedSchemeHint"))
        assertTrue("课表默认来源文案必须接上", source.contains("locationTimeAutoResolvedByTimetable"))
        assertTrue("地点组来源文案必须接上", source.contains("locationTimeAutoResolvedByGroup"))
        assertTrue("弹层必须有来源副题参数", source.contains("autoSubtitle ="))
        // C2：页面必须把解析出的节数交给候选（壳侧负责注入）。
        assertTrue("候选节数必须走生效解析", source.contains("info = entryTimeSchemeInfo(entry, entry.location)"))
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
        // C2：壳必须注入「解析模板的节数」与生效解析，不能只传全局节数。
        assertTrue("壳必须接 entrySchemeSectionCount", shell.contains("entrySchemeSectionCount = {"))
        assertTrue("壳必须接 entryTimeSchemeInfo", shell.contains("entryTimeSchemeInfo = {"))
        assertTrue("壳必须用同一个解析器", shell.contains("AddCourseEntryTimeSchemeLogic.resolve("))
    }

    private fun pageSource(name: String): String =
        readKotlinSourceNoStrings("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/$name")

    private fun shellIndexSource(): String =
        readKotlinSourceNoStrings("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt")
}
