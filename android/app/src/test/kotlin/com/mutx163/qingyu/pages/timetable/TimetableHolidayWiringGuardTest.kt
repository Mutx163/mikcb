package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 周视图假期接线的回归网（2026-11-05 修的两处「只在设置页生效」缺陷）。
 *
 * ## 修的是什么
 *
 * 1. **「今天放假」在周视图被写死关掉**：`TimetableHost` 里原本是
 *    `overrideEnabled = false, // holidayOverrideEnabled 尚未进 TimetableSettingsModel`。
 *    同一开关在月视图（`MonthHolidayHost`）、桌面卡片（`HomeWidgetHostPipeline`）、
 *    自检页（`LiveSelfCheckHost`）都认，只有周视图不认。
 * 2. **自定义假期是一次性快照**：`customHolidays` 只 `remember(holidayPrefs)` 读一次，
 *    设置页加/改/删之后已挂载的周视图不会更新，要重启才看见。
 *
 * ## 为什么读源码文本
 *
 * `src/test` 只挂 `main` 源集，composeP1 的 Compose 源码编不进来（与
 * `SettingsResetConfirmationGuardTest` / `SettingsHostIntentWiringGuardTest` 同一套做法）。
 * 找不到文件**判失败而不是跳过**——守卫宁可红，不能静默失效。
 *
 * 咬合探针：把 `overrideEnabled = holidayOverrideEnabled` 改回 `overrideEnabled = false`，
 * 本文件第一条断言立刻红（已实测）。
 */
class TimetableHolidayWiringGuardTest {

    @Test
    fun `overrideEnabled 透传真值而不是写死 false`() {
        val block = holidayBlock()
        assertFalse(
            "周视图不许再写死 overrideEnabled = false（「今天放假」会在周视图永久失效）",
            "overrideEnabled = false" in block,
        )
        assertTrue(
            "overrideEnabled 必须来自读盘真值（holidayOverrideEnabled）",
            "overrideEnabled = holidayOverrideEnabled" in block,
        )
    }

    @Test
    fun `override 真值来自 timetable_settings 的同名键`() {
        val block = holidayBlock()
        assertTrue(
            "真值口径必须复用 MonthHolidaySettings（与月视图/桌面卡片同一份读取规则，不要另写一份）",
            "MonthHolidaySettings.fromSettingsJson(" in block,
        )
        assertTrue(
            "读设置用仓储快照里的 settingsJson（与 LiveSelfCheckHost 的读取口径一致）",
            "repository.settingsJson()" in block,
        )
    }

    @Test
    fun `假期数据跟着 prefs 变化重读 而不是一次性快照`() {
        val source = hostSource()
        assertTrue(
            "必须订阅同一份 SharedPreferences，拿不到 HolidayProvider 实例也能被通知到",
            "registerOnSharedPreferenceChangeListener" in source,
        )
        assertTrue(
            "自定义假期的键（custom_holidays）必须在监听判据里",
            "HolidayPreferences.CUSTOM_HOLIDAYS_KEY" in source,
        )
        assertTrue(
            "官方年度缓存的键前缀（holiday_data_）必须在监听判据里",
            "HolidayPreferences.DATA_KEY_PREFIX" in source,
        )
        assertTrue(
            "重启回主线程再改 Compose 状态（监听回调跑在写入线程上）",
            "holidayScope.launch" in source,
        )
        assertTrue(
            "customHolidays 的 remember 必须带上 revision 依赖，否则重读不会被触发",
            "remember(holidayPrefs, holidayRevision)" in holidayBlock(),
        )
    }

    // ------------------------------------------------------------ 工具

    /**
     * 截出「假期判定」这一段：从分节注释到下一节「天气」分节注释为止。
     *
     * ⚠️ 收尾标记必须用**下一节的分节注释**，不能用 `val semesterStart`：真正消费
     * `overrideEnabled` 的 `holidayOf` lambda 排在 `semesterStart` **之后**，
     * 早收会让「透传真值」那条断言永远找不到目标行（本地实测踩过）。
     */
    private fun holidayBlock(): String {
        val source = hostSource()
        val start = source.indexOf("// ── 假期判定（P1-7）──")
        assertTrue("TimetableHost.kt 里找不到假期判定分节注释", start >= 0)
        val end = source.indexOf("// ── 天气", start)
        assertTrue("假期判定分节没有找到天气分节收尾", end > start)
        return source.substring(start, end)
    }

    private fun hostSource(): String {
        val file = File(androidSrc(), "composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt")
        assertTrue("${file.path} 不存在", file.isFile)
        // Windows 上是 CRLF；断言里有跨行片段时 CR 会让匹配失败，这里统一成 LF。
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
