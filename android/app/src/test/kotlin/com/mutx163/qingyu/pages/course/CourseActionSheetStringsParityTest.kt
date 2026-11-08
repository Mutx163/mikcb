package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.weather.CourseWeatherSummary
import com.mutx163.qingyu.weather.WeatherCategory
import com.mutx163.qingyu.weather.planWeatherLine
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程操作弹层文案逐字对拍 ARB（`i18n/app_zh.arb`）+ 格式化纯函数的口径。
 *
 * 两条门槛：
 * 1. **文案不许自拟**：每一处屏上文案都必须与 ARB 原文一致（占位符按模板片段比对）；
 * 2. **格式化可推**：周次描述 / 周次表压缩 / 日期 / 星期 / 天气拼接，期望值按 Dart 手推。
 *
 * `loadArbZh()` 从工作目录向上找仓库根定位 ARB，不写死绝对路径。
 */
class CourseActionSheetStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = CourseActionSheetStrings.allTexts
        assertTrue("文案条数不应少于 72 条，当前 ${texts.size}", texts.size >= 72)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `同一份文案清单里没有重复的 ARB 键`() {
        val keys = CourseActionSheetStrings.allTexts.map { it.key }
        assertEquals("文案清单里有重复键：$keys", keys.size, keys.toSet().size)
    }

    @Test
    fun `复用 app_CourseActionStrings 的九条文案仍在 ARB 里且值未漂移`() {
        // 这些键本模块**不重复声明**（见 CourseActionSheetStrings 的对象注释），
        // 但屏上直接用它们，所以这里钉住它们的值与 ARB 一致，防止另一方被改后弹层静默变形。
        val reused = mapOf(
            "courseActionEditPrimary" to com.mutx163.qingyu.app.CourseActionStrings.courseActionEditPrimary,
            "courseActionRescheduleSecondary" to
                com.mutx163.qingyu.app.CourseActionStrings.courseActionRescheduleSecondary,
            "courseActionSuspendSecondary" to
                com.mutx163.qingyu.app.CourseActionStrings.courseActionSuspendSecondary,
            "courseActionUnsuspend" to com.mutx163.qingyu.app.CourseActionStrings.courseActionUnsuspend,
            "courseActionDeleteSecondary" to
                com.mutx163.qingyu.app.CourseActionStrings.courseActionDeleteSecondary,
        )
        for ((key, text) in reused) {
            assertEquals(key, text.key)
            assertEquals("复用键 `$key` 的值与 ARB 不一致", arbMap[key], text.zh)
        }
        assertEquals("未知教师", arbMap["unknownTeacher"])
        assertEquals("未知地点", arbMap["unknownLocation"])
    }

    @Test
    fun `日期复用 monthViewAgendaTitle_输出与 zh 的 MMMd 一致`() {
        // Dart 用 `DateFormat.MMMd(locale).format(date)`，zh 输出「10月29日」。
        assertEquals("10月29日", CourseActionSheetStrings.dateLabel(10, 29))
        assertEquals("1月1日", CourseActionSheetStrings.dateLabel(1, 1))
        assertEquals("{month}月{day}日", arbMap["monthViewAgendaTitle"])
    }

    @Test
    fun `节次区间用全角波浪线而不是连字符`() {
        assertEquals("第 1～2 节", CourseActionSheetStrings.sectionRange(1, 2))
        assertEquals("第 5～6 节", CourseActionSheetStrings.sectionRange(5, 6))
    }

    @Test
    fun `星期全名与 ARB 严格对齐_越界退化成数字`() {
        val labels = CourseActionSheetStrings.weekdayLabels
        assertEquals(7, labels.size)
        assertEquals(listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日"), labels)
        for (day in 1..7) {
            assertEquals(labels[day - 1], CourseActionSheetStrings.weekdayLabel(day))
        }
        assertEquals("0", CourseActionSheetStrings.weekdayLabel(0))
        assertEquals("8", CourseActionSheetStrings.weekdayLabel(8))
    }

    @Test
    fun `周次表压缩成区间`() {
        assertEquals("", CourseActionSheetStrings.formatWeekList(emptyList()))
        assertEquals("3", CourseActionSheetStrings.formatWeekList(listOf(3)))
        assertEquals("1-3", CourseActionSheetStrings.formatWeekList(listOf(1, 2, 3)))
        assertEquals("1-3、5", CourseActionSheetStrings.formatWeekList(listOf(5, 1, 3, 2)))
        assertEquals("2、4、8-10", CourseActionSheetStrings.formatWeekList(listOf(2, 4, 8, 9, 10)))
    }

    @Test
    fun `周次描述三态_区间 单双周 自定义周次`() {
        assertEquals("第 1～16 周", CourseActionSheetStrings.weekDescription(course()))
        assertEquals(
            "第 1～16 周 单周",
            CourseActionSheetStrings.weekDescription(course(isOddWeek = true)),
        )
        assertEquals(
            "第 1～8 周 双周",
            CourseActionSheetStrings.weekDescription(course(isEvenWeek = true, endWeek = 8)),
        )
        assertEquals(
            "第 1-2、5 周",
            CourseActionSheetStrings.weekDescription(course(customWeeks = listOf(1, 2, 5))),
        )
        assertEquals(
            "第 7 周",
            CourseActionSheetStrings.weekDescription(course(customWeeks = listOf(7))),
        )
    }

    @Test
    fun `周次与节次的模板填充`() {
        assertEquals("第 9 周", CourseActionSheetStrings.weekLabel(9))
        assertEquals("简称：高数", CourseActionSheetStrings.shortName("高数"))
        assertEquals("冲突 2 节", CourseActionSheetStrings.conflictCount(2))
        assertEquals("还有 3 节情侣课表课程", CourseActionSheetStrings.coupleRelatedCount(3))
        assertEquals("还有 4 节相关课程", CourseActionSheetStrings.mixedRelatedCount(4))
        assertEquals("23°", CourseActionSheetStrings.temperatureValue(23))
        assertEquals("60%", CourseActionSheetStrings.probabilityValue(60))
    }

    @Test
    fun `天气现象名覆盖全部枚举值且与 ARB 一致`() {
        val expected = mapOf(
            WeatherCategory.CLEAR to "晴",
            WeatherCategory.MAINLY_CLEAR to "晴间多云",
            WeatherCategory.PARTLY_CLOUDY to "多云",
            WeatherCategory.OVERCAST to "阴",
            WeatherCategory.FOG to "雾",
            WeatherCategory.DRIZZLE to "毛毛雨",
            WeatherCategory.FREEZING_DRIZZLE to "冻毛毛雨",
            WeatherCategory.LIGHT_RAIN to "小雨",
            WeatherCategory.RAIN to "中雨",
            WeatherCategory.HEAVY_RAIN to "大雨",
            WeatherCategory.FREEZING_RAIN to "冻雨",
            WeatherCategory.RAIN_SHOWERS to "阵雨",
            WeatherCategory.HEAVY_RAIN_SHOWERS to "强阵雨",
            WeatherCategory.LIGHT_SNOW to "小雪",
            WeatherCategory.SNOW to "中雪",
            WeatherCategory.HEAVY_SNOW to "大雪",
            WeatherCategory.SNOW_GRAINS to "米雪",
            WeatherCategory.SNOW_SHOWERS to "阵雪",
            WeatherCategory.THUNDERSTORM to "雷阵雨",
            WeatherCategory.THUNDERSTORM_HAIL to "雷阵雨伴冰雹",
        )
        assertEquals("枚举值数量应与期望表一致", WeatherCategory.entries.size, expected.size)
        for ((category, label) in expected) {
            assertEquals(label, CourseActionSheetStrings.weatherCategoryLabel(category))
        }
    }

    @Test
    fun `天气一句话按 现象 温度 概率 的顺序用中点连接`() {
        val summary = CourseWeatherSummary(
            category = WeatherCategory.LIGHT_RAIN,
            temperatureC = 23,
            hourCount = 2,
            precipitationProbability = 60,
            showPrecipitationProbability = true,
            representativeWmoCode = 61,
        )
        val all = planWeatherLine(
            summary = summary,
            showPhenomenon = true,
            showTemperature = true,
            showProbability = true,
        )
        assertEquals("小雨 · 23° · 60%", CourseActionSheetStrings.weatherLineText(all!!))

        val noPhenomenon = planWeatherLine(
            summary = summary,
            showPhenomenon = false,
            showTemperature = true,
            showProbability = false,
        )
        assertEquals("23°", CourseActionSheetStrings.weatherLineText(noPhenomenon!!))
    }

    // ───────────────────────── 夹具与 ARB 读取 ─────────────────────────

    private fun course(
        startWeek: Int = 1,
        endWeek: Int = 16,
        isOddWeek: Boolean = false,
        isEvenWeek: Boolean = false,
        customWeeks: List<Int>? = null,
    ): Course = Course(
        id = "c1",
        name = "高等数学",
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
        isOddWeek = isOddWeek,
        isEvenWeek = isEvenWeek,
        customWeeks = customWeeks,
    )

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
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
