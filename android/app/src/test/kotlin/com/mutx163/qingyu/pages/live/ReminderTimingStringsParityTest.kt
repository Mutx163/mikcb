package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「提醒时间」子屏文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符；
 * 且格式化纯函数、摘要/副标题映射都落在 ARB 原句上。
 */
class ReminderTimingStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = ReminderTimingStrings.allTexts
        assertTrue("文案条数不应少于 26 条，当前 ${texts.size}", texts.size >= 26)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertEquals("ARB 键 `${item.key}` 的屏上文案与 arb 不一致", template!!, item.zh)
        }
    }

    @Test
    fun `与 LiveStrings 共用的键值不得漂移`() {
        // 两张表各查各的，但同一个 ARB 键必须给同一个值：漂了说明有人在其中一处改了字。
        val shared = listOf(
            ReminderTimingStrings.beforeClassReminderTitle to LiveStrings.beforeClassReminderTitle,
            ReminderTimingStrings.beforeClassReminderSubtitle to LiveStrings.beforeClassReminderSubtitle,
            ReminderTimingStrings.duringClassReminderTitle to LiveStrings.duringClassReminderTitle,
            ReminderTimingStrings.liveClassReminderLeadTitle to LiveStrings.liveClassReminderLeadTitle,
            ReminderTimingStrings.liveClassReminderLeadOptionImmediate to
                LiveStrings.liveClassReminderLeadOptionImmediate,
            ReminderTimingStrings.liveClassReminderLeadOptionMinutes to
                LiveStrings.liveClassReminderLeadOptionMinutes,
            ReminderTimingStrings.beforeClassPopupLabel to LiveStrings.beforeClassPopupLabel,
            ReminderTimingStrings.beforeClassMinutesOption to LiveStrings.beforeClassMinutesOption,
            ReminderTimingStrings.enableIslandDisplayTitle to LiveStrings.enableIslandDisplayTitle,
        )
        for ((mine, theirs) in shared) {
            assertEquals("键 `${mine.key}` 与 LiveStrings 的同名键不一致", theirs.zh, mine.zh)
        }
    }

    @Test
    fun `上课前副标题占位符按分钟填充`() {
        // 手推：「课程开始前 {minutes} 分钟弹出」+ 20 -> 课程开始前 20 分钟弹出。
        assertEquals("课程开始前 20 分钟弹出", ReminderTimingStrings.formatBeforeClassReminderSubtitle(20))
        assertEquals(
            arbMap["beforeClassReminderSubtitle"]!!.replace("{minutes}", "5"),
            ReminderTimingStrings.formatBeforeClassReminderSubtitle(5),
        )
    }

    @Test
    fun `切入时机选项零走立即切换其余走分钟`() {
        // 0 -> immediate 标签；非 0 -> 「下课前 N 分钟」。
        assertEquals(
            arbMap["liveClassReminderLeadOptionImmediate"],
            ReminderTimingStrings.leadOptionText(0),
        )
        assertEquals("下课前 10 分钟", ReminderTimingStrings.leadOptionText(10))
        assertEquals(
            arbMap["liveClassReminderLeadOptionMinutes"]!!.replace("{minutes}", "30"),
            ReminderTimingStrings.leadOptionText(30),
        )
    }

    @Test
    fun `切入时机摘要四口径都对应 ARB`() {
        assertEquals(
            arbMap["liveClassReminderLeadSummaryImmediate"],
            ReminderTimingStrings.leadSummaryText(ReminderLeadSummary.IMMEDIATE),
        )
        assertEquals(
            arbMap["liveClassReminderLeadSummaryKeepNormal"],
            ReminderTimingStrings.leadSummaryText(ReminderLeadSummary.KEEP_NORMAL),
        )
        assertEquals(
            arbMap["liveClassReminderLeadSummaryIsland"],
            ReminderTimingStrings.leadSummaryText(ReminderLeadSummary.ISLAND),
        )
        assertEquals(
            arbMap["liveClassReminderLeadSummaryFocused"],
            ReminderTimingStrings.leadSummaryText(ReminderLeadSummary.FOCUSED),
        )
    }

    @Test
    fun `课中状态栏通知副标题三口径都对应 ARB`() {
        assertEquals(
            arbMap["duringClassStatusNotificationImmediate"],
            ReminderTimingStrings.duringClassStatusHintText(DuringClassStatusHint.KEEP_STATUS_NOTIFICATION),
        )
        assertEquals(
            arbMap["duringClassStatusNotificationBeforeEnd"],
            ReminderTimingStrings.duringClassStatusHintText(DuringClassStatusHint.NORMAL_THEN_LEAD),
        )
        assertEquals(
            arbMap["duringClassStatusNotificationPersistent"],
            ReminderTimingStrings.duringClassStatusHintText(DuringClassStatusHint.PERSISTENT),
        )
    }

    @Test
    fun `课中时间样式两枚举都对应 ARB`() {
        assertEquals(
            arbMap["liveDuringClassTimeNearest"],
            ReminderTimingStrings.displayModeText(LiveDuringClassTimeDisplayMode.NEAREST),
        )
        assertEquals(
            arbMap["liveDuringClassTimeTotal"],
            ReminderTimingStrings.displayModeText(LiveDuringClassTimeDisplayMode.TOTAL),
        )
    }

    @Test
    fun `分钟与秒选项占位符按值填充`() {
        assertEquals("20 分钟", ReminderTimingStrings.formatBeforeClassMinutesOption(20))
        assertEquals(
            arbMap["beforeClassMinutesOption"]!!.replace("{minutes}", "60"),
            ReminderTimingStrings.formatBeforeClassMinutesOption(60),
        )
        assertEquals("30 秒", ReminderTimingStrings.formatBeforeEndSecondsOption(30))
        assertEquals(
            arbMap["beforeEndSecondsOption"]!!.replace("{seconds}", "90"),
            ReminderTimingStrings.formatBeforeEndSecondsOption(90),
        )
    }

    @Test
    fun `时间矫正读数三档都对应 ARB`() {
        // 手推：0 → 不矫正；正 → 整体延后 N 秒；负 → 整体提前 |N| 秒（Dart `_formatLiveTimeCorrection`）。
        assertEquals(arbMap["liveTimeCorrectionNone"], ReminderTimingStrings.formatTimeCorrection(0))
        assertEquals("整体延后 5 秒", ReminderTimingStrings.formatTimeCorrection(5))
        assertEquals("整体提前 5 秒", ReminderTimingStrings.formatTimeCorrection(-5))
        assertEquals(
            arbMap["timeCorrectionLabel"]!!.replace("{value}", "整体延后 5 秒"),
            ReminderTimingStrings.formatTimeCorrectionLabel(5),
        )
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
