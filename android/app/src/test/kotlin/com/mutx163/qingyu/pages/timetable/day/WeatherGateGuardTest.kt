package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 课卡天气门槛守卫（2026-11-04，Lead 例外科改授权）。
 *
 * ## 防的是哪类回退
 *
 * Dart 只在 `course.isActiveInWeek(week)` 为真时挂天气：
 * - 周卡 `timetable_home_page_assembly.dart:456`
 * - 日卡 `day_view_course_agenda_card_variants.dart:166-169`
 *
 * 停课周 / 单双周错位 / 尚未开课的那一周并不上课，挂当天的天气会误导用户。
 * Kotlin 两处曾经都只判「有没有日期 / 有没有 provider」，漏了这道门；本守卫读源码
 * 文本锁住门槛位置——门槛写在装配分支里，编译产物与反射都不保留这个事实，
 * 与 `pages/shell/DayViewWiringGuardTest` 同一套做法。
 */
class WeatherGateGuardTest {

    @Test
    fun `周卡天气必须按 isActiveInWeek 挂载`() {
        val source = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt",
        )
        val block = slice(source, "val weatherOf", "// ── 首页壁纸背景")
        assertTrue(
            "TimetableHost 的 weatherOf 找不到（守卫解析可能坏了）",
            block.length > 100,
        )
        assertTrue(
            "周卡天气取数器没有 `!course.isActiveInWeek(week) -> null` 这道门：" +
                "停课周的课卡会挂上那天的天气（Dart `timetable_home_page_assembly.dart:456`）。",
            HOST_GATE.find(block) != null,
        )
    }

    @Test
    fun `日卡天气必须按 isActiveInWeek 挂载`() {
        val source = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewWeather.kt",
        )
        assertTrue(
            "DayViewWeather 的取数器签名没有 week 参数（`return { week, date, course ->`）：" +
                "拿不到 week 就判不了停课周。",
            DAY_SIGNATURE.find(source) != null,
        )
        assertTrue(
            "日卡天气没有 `!course.isActiveInWeek(week)` 这道门：" +
                "停课周的课卡会挂上那天的天气（Dart `day_view_course_agenda_card_variants.dart:166-169`）。",
            DAY_GATE.find(source) != null,
        )
        assertTrue(
            "日卡天气在停课周应整行不挂（返回 null），不得返回空字符串冒充「挂载」。",
            DAY_NULL.find(source) != null,
        )
    }

    @Test
    fun `壳必须把当前页周次传给日卡天气取数器`() {
        val source = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        val block = slice(source, "dataProvider = { week, dayOfWeek ->", "onCloseToWeekView")
        assertTrue(
            "ShellPageIndex 的日视图 dataProvider 块解析太短（守卫可能坏了）",
            block.length > 200,
        )
        assertTrue(
            "壳没有把当前页的 week 传进天气取数器（找不到 `resolve(week, date, course)`）：" +
                "`weatherOf` 只收 (date, course)，停课周门槛无从判断。",
            SHELL_WEEK.find(block) != null,
        )
        assertTrue(
            "壳仍然把原始 `weatherOf` 直接交给装配器（`weatherOf = weatherOf,`）：" +
                "少了带 week 的包装层，门槛等于没加。",
            "weatherOf = weatherOf," !in block,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        val host = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimetableHost.kt",
        )
        assertTrue(
            "TimetableHost 源码读取太短（${host.length} 字符），路径解析可能坏了",
            host.length > 1000,
        )
    }

    // ------------------------------------------------------------------ 解析

    private fun slice(source: String, from: String, to: String): String {
        val start = source.indexOf(from)
        assertTrue("源码里找不到起点 `$from`", start >= 0)
        val end = source.indexOf(to, start)
        assertTrue("源码里找不到终点 `$to`（在 `$from` 之后）", end > start)
        return source.substring(start, end)
    }

    /**
     * 从工作目录向上找仓库根再定位文件：L0 脚本与 Gradle 的工作目录不同，
     * 按「向上找标志文件」而不是写死相对路径；**找不到仍判失败**。
     */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        /**
         * 门槛必须写在**真正的代码行**上：正则锚定行首，注释掉的 `// !course...`
         * 不会命中。否则探针（把门注释掉）会假绿。
         */
        val HOST_GATE = Regex("""^[ \t]*![ \t]*course\.isActiveInWeek\(week\)[ \t]*->[ \t]*null""", RegexOption.MULTILINE)
        val DAY_SIGNATURE = Regex("""^[ \t]*return \{ week, date, course ->""", RegexOption.MULTILINE)
        val DAY_GATE = Regex("""^[ \t]*if \(!course\.isActiveInWeek\(week\)\) \{""", RegexOption.MULTILINE)
        val DAY_NULL = Regex("""^[ \t]*null[ \t]*$""", RegexOption.MULTILINE)
        val SHELL_WEEK = Regex("""^[ \t]*\{ date, course -> resolve\(week, date, course\) \}""", RegexOption.MULTILINE)
    }
}
