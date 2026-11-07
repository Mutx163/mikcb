package com.mutx163.qingyu.pages.statistics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * 周报开关写路径的**顺序与补偿**（2026-11-05）。
 *
 * 背景（GLM成员2 复核指出、Chief 定方案）：
 * 1. 原先「先写 settings、再排调度」——调度抛错时偏好已写、界面回滚 ⇒ 界面「关」、盘上「开」，
 *    下次进页面跳回「开」；
 * 2. 更值钱的一条：`scheduleNext` 几乎不抛，真正的失败源是 Android 13+ 通知不可达，
 *    `notify()` 被系统**静默丢弃** ⇒ 用户「开了周报永远收不到」，界面还显示已开启。
 *
 * 这里用注入的副作用把顺序、拒绝打开、两条补偿路径钉成**运行时**断言（比读源码的守卫强）；
 * 另加一条源码守卫防壳里内联重排顺序。真机投递行为仍需 L2 / 真机确认。
 */
class WeeklyReportToggleLogicTest {

    private val planned = WeeklyReportToggleLogic.Plan(
        fireAtMillis = 1_760_000_000_000L,
        title = "本周课程小结",
        body = "第 7 周 · 共 18 节",
    )

    private val events = mutableListOf<String>()
    private var scheduled: WeeklyReportToggleLogic.Plan? = null
    private var writeValue: Boolean? = null

    private fun reset() {
        events.clear()
        scheduled = null
        writeValue = null
    }

    /** 默认全成功的接线；各用例只替换自己要改坏的那一条副作用。 */
    private fun apply(
        enabled: Boolean,
        plan: () -> WeeklyReportToggleLogic.Plan = { planned },
        canDeliver: () -> Boolean = { events += "canDeliver"; true },
        scheduleNext: (WeeklyReportToggleLogic.Plan) -> Unit = { p -> events += "scheduleNext"; scheduled = p },
        cancel: () -> Unit = { events += "cancel" },
        writeSettings: (Boolean) -> Unit = { value ->
            events += "writeSettings($value)"
            writeValue = value
        },
    ) {
        reset()
        WeeklyReportToggleLogic.applyToggle(
            enabled = enabled,
            plan = plan,
            canDeliver = canDeliver,
            scheduleNext = scheduleNext,
            cancel = cancel,
            writeSettings = writeSettings,
        )
    }

    // ── 打开 ────────────────────────────────────────────────────────────

    @Test
    fun `打开成功时顺序是先查可达再排调度最后写 settings`() {
        apply(enabled = true)
        assertEquals(
            listOf("canDeliver", "scheduleNext", "writeSettings(true)"),
            events,
        )
        assertEquals(planned, scheduled)
        assertEquals(true, writeValue)
    }

    @Test
    fun `通知不可达时拒绝打开 一个字都不写`() {
        try {
            apply(
                enabled = true,
                plan = { throw AssertionError("不可达时连 plan 都不该算") },
                canDeliver = { events += "canDeliver"; false },
            )
            fail("通知不可达必须抛异常，不能假装成功")
        } catch (expected: WeeklyReportNotificationUnavailableException) {
            // 期望
        }
        assertEquals("只有可达性检查，别的副作用一个都不许有", listOf("canDeliver"), events)
        assertNull("不许排调度", scheduled)
        assertNull("不许写 settings", writeValue)
    }

    @Test
    fun `打开时 settings 写失败要撤销刚排上的调度`() {
        try {
            apply(
                enabled = true,
                writeSettings = { value ->
                    events += "writeSettings($value)"
                    throw IllegalStateException("settings boom")
                },
            )
            fail("settings 写失败必须抛出（页面要回滚 UI）")
        } catch (expected: IllegalStateException) {
            assertEquals("settings boom", expected.message)
        }
        assertEquals(
            "先调度成功 → 写 settings 失败 → 撤销调度（不能留「偏好关、闹钟还在」）",
            listOf("canDeliver", "scheduleNext", "writeSettings(true)", "cancel"),
            events,
        )
    }

    // ── 关闭 ────────────────────────────────────────────────────────────

    @Test
    fun `关闭成功时顺序是先撤再写 settings`() {
        apply(enabled = false)
        assertEquals(listOf("cancel", "writeSettings(false)"), events)
        assertEquals(false, writeValue)
        assertNull("关闭不排调度", scheduled)
    }

    @Test
    fun `关闭时 settings 写失败用开头同一组值补偿回写`() {
        try {
            apply(
                enabled = false,
                writeSettings = { value ->
                    events += "writeSettings($value)"
                    throw IllegalStateException("settings boom")
                },
            )
            fail("settings 写失败必须抛出")
        } catch (expected: IllegalStateException) {
            assertEquals("settings boom", expected.message)
        }
        assertEquals(
            "撤销 → 写 settings 失败 → 用开头算好的那组值排回去",
            listOf("cancel", "writeSettings(false)", "scheduleNext"),
            events,
        )
        assertEquals("补偿回写复用的是同一组值", planned, scheduled)
    }

    // ── 反馈文案按异常类型选 ────────────────────────────────────────────

    @Test
    fun `通知不可达 与 普通失败 分别给不同文案`() {
        assertEquals(
            "通知不可达要告诉用户去哪开，不能说「保存失败」",
            StatisticsStrings.weeklyReportPermissionMissing.zh,
            StatisticsSettingsLogic.failureMessage(WeeklyReportNotificationUnavailableException()),
        )
        assertEquals(
            "落盘/调度失败仍是「保存失败」",
            StatisticsStrings.saveFailed.zh,
            StatisticsSettingsLogic.failureMessage(IllegalStateException("boom")),
        )
    }

    // ── 壳不许绕过共享逻辑 ──────────────────────────────────────────────

    @Test
    fun `壳的周报开关必须委派给共享逻辑 不许内联重排顺序`() {
        val source = stripKotlinComments(
            readSource("android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"),
        )
        assertTrue(
            "`e.statisticsSettings` 的开关回调必须走 WeeklyReportToggleLogic.applyToggle(...)",
            source.contains("WeeklyReportToggleLogic.applyToggle("),
        )
        assertTrue(
            "「打开前先查通知可达性」必须调 WeeklyReportScheduler.canDeliver(...)",
            source.contains("WeeklyReportScheduler.canDeliver("),
        )
    }

    // ── 工具 ────────────────────────────────────────────────────────────

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlock = false
        var depth = 0
        var quote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlock -> {
                    if (ch == '/' && next == '*') {
                        depth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        depth--
                        i += 2
                        if (depth == 0) inBlock = false
                    } else {
                        i++
                    }
                }
                quote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == quote) quote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlock = true
                    depth = 1
                    i += 2
                }
                ch == '"' -> {
                    quote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }
}
