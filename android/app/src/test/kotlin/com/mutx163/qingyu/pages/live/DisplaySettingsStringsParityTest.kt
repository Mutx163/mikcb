package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「超级岛 · 显示设置页 + 超级岛预览」文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class DisplaySettingsStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = DisplaySettingsStrings.allTexts
        assertTrue("文案条数不应少于 110 条，当前 ${texts.size}", texts.size >= 110)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertEquals("ARB 键 `${item.key}` 的屏上文案与 arb 不一致", template!!, item.zh)
        }
    }

    @Test
    fun `与 LiveStrings 共用的键值不得漂移`() {
        // 同一 ARB 键在两处必须给同一个值：漂了说明有人在其中一处改了字。
        val shared = listOf(
            DisplaySettingsStrings.islandPreviewTitle to LiveStrings.liveIslandPreviewTitle,
            DisplaySettingsStrings.sampleCourse to LiveStrings.liveIslandPreviewSampleCourse,
            DisplaySettingsStrings.sampleCourseShort to LiveStrings.liveIslandPreviewSampleCourseShort,
            DisplaySettingsStrings.sampleLocation to LiveStrings.liveIslandPreviewSampleLocation,
            DisplaySettingsStrings.sampleTeacher to LiveStrings.liveIslandPreviewSampleTeacher,
            DisplaySettingsStrings.sampleNextClass to LiveStrings.liveIslandPreviewSampleNextClass,
            DisplaySettingsStrings.sampleNote to LiveStrings.liveIslandPreviewSampleNote,
            DisplaySettingsStrings.stageBeforeClass to LiveStrings.liveIslandPreviewStageBeforeClass,
            DisplaySettingsStrings.stageInClass to LiveStrings.liveIslandPreviewStageInClass,
            DisplaySettingsStrings.stageBeforeEnd to LiveStrings.liveIslandPreviewStageBeforeEnd,
            DisplaySettingsStrings.untilClassStart to LiveStrings.liveIslandPreviewUntilClassStart,
            DisplaySettingsStrings.untilClassEnd to LiveStrings.liveIslandPreviewUntilClassEnd,
            DisplaySettingsStrings.previewTitleBeforeClass to LiveStrings.liveIslandPreviewTitleBeforeClass,
            DisplaySettingsStrings.previewTitleBeforeEnd to LiveStrings.liveIslandPreviewTitleBeforeEnd,
            DisplaySettingsStrings.islandExpandedPreviewTitle to LiveStrings.liveIslandExpandedPreviewTitle,
            DisplaySettingsStrings.islandVisualTitle to LiveStrings.liveIslandVisualTitle,
            DisplaySettingsStrings.showCountdownTitle to LiveStrings.showCountdownTitle,
            DisplaySettingsStrings.showLocationTitle to LiveStrings.showLocationTitle,
            DisplaySettingsStrings.showCourseNameTitle to LiveStrings.showCourseNameTitle,
            DisplaySettingsStrings.preferShortNameTitle to LiveStrings.preferShortNameTitle,
        )
        for ((mine, theirs) in shared) {
            assertEquals("键 `${mine.key}` 与 LiveStrings 的同名键不一致", theirs.zh, mine.zh)
        }
    }

    @Test
    fun `倒计时十二样式名齐全`() {
        val styles = LiveCountdownTextStyle.entries
        assertEquals(12, styles.size)
        val labels = styles.map { DisplaySettingsStrings.countdownTextStyleLabel(it) }
        assertEquals("智能 中文", labels[0])
        assertEquals("纯秒 5/s", labels[11])
        // 每条都非空且互不重复（下拉里不能出现两个一样的项）。
        assertEquals(12, labels.toSet().size)
    }

    @Test
    fun `枚举文案映射与 ARB 对应`() {
        assertEquals(arbMap["miuiIslandLabelStyleTextOnly"], DisplaySettingsStrings.miuiIslandLabelStyleLabel(MiuiIslandLabelStyle.TEXT_ONLY))
        assertEquals(arbMap["miuiIslandLabelContentCourseNameAndLocation"], DisplaySettingsStrings.miuiIslandLabelContentLabel(MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION))
        assertEquals(arbMap["miuiIslandLabelFontWeightBold"], DisplaySettingsStrings.miuiIslandLabelFontWeightLabel(MiuiIslandLabelFontWeight.BOLD))
        assertEquals(arbMap["miuiIslandLabelRenderQualityUltra"], DisplaySettingsStrings.miuiIslandLabelRenderQualityLabel(MiuiIslandLabelRenderQuality.ULTRA))
        assertEquals(arbMap["miuiIslandExpandedIconCustomImage"], DisplaySettingsStrings.miuiIslandExpandedIconModeLabel(MiuiIslandExpandedIconMode.CUSTOM_IMAGE))
        assertEquals(arbMap["liveBeforeClassQuickActionDoNotDisturb"], DisplaySettingsStrings.liveBeforeClassQuickActionLabel(LiveBeforeClassQuickAction.DO_NOT_DISTURB))
        assertEquals(arbMap["liveExpandedDetailFieldNext"], DisplaySettingsStrings.liveExpandedDetailFieldLabel(LiveExpandedDetailField.NEXT_COURSE))
    }

    @Test
    fun `占位符格式化替换正确`() {
        assertEquals("上课前 15 分钟", DisplaySettingsStrings.autoMinutesLabel(15))
        assertEquals("左侧文字大小 18", DisplaySettingsStrings.fontSizeLabel("18"))
        assertEquals("左侧文字水平偏移 -1.5", DisplaySettingsStrings.offsetXLabel("-1.5"))
        assertEquals("左侧图标圆角 8", DisplaySettingsStrings.logoCornerRadiusLabel("8"))
        assertEquals("不自动执行", DisplaySettingsStrings.quickActionAutoMinuteLabel(0))
        assertEquals("上课前 10 分钟", DisplaySettingsStrings.quickActionAutoMinuteLabel(10))
        assertEquals("下一节：大学物理", DisplaySettingsStrings.detailLineNext.filled("value", "大学物理"))
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 i18n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
