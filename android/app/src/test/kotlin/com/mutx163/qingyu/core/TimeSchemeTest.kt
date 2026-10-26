package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 时间模板移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/models/time_scheme_test.dart（断言值逐条翻成 Kotlin）；
 * - [Dart推演]：对照 lib/models/time_scheme.dart 实现逐行推演；
 * - [人推]：边界值。
 */
class TimeSchemeTest {

    // ---------- buildQuickSectionTimes [Dart抄录] ----------

    @Test
    fun quickBuilder_fullSchedule_byPeriods() {
        val sections = buildQuickSectionTimes(
            morningCount = 2,
            afternoonCount = 2,
            eveningCount = 1,
            morningStartTime = "08:00",
            afternoonStartTime = "14:00",
            eveningStartTime = "19:00",
            classDurationMinutes = 45,
            breakDurationMinutes = 10,
        )
        assertEquals(
            listOf("08:00-08:45", "08:55-09:40", "14:00-14:45", "14:55-15:40", "19:00-19:45"),
            sections.map { it.displayText },
        )
    }

    @Test
    fun quickBuilder_overridesLongBreaks() { // [Dart抄录]
        val sections = buildQuickSectionTimes(
            morningCount = 3,
            afternoonCount = 0,
            eveningCount = 0,
            morningStartTime = "08:00",
            afternoonStartTime = null,
            eveningStartTime = null,
            classDurationMinutes = 45,
            breakDurationMinutes = 10,
            breakOverrideRules = listOf(BreakOverrideRule(afterSection = 2, breakDurationMinutes = 25)),
        )
        assertEquals(
            listOf("08:00-08:45", "08:55-09:40", "10:05-10:50"),
            sections.map { it.displayText },
        )
    }

    @Test
    fun quickBuilder_rejectsCrossingMidnight() { // [Dart抄录] section_crosses_midnight
        val e = assertThrows(DartFormatException::class.java) {
            buildQuickSectionTimes(
                morningCount = 1,
                afternoonCount = 0,
                eveningCount = 0,
                morningStartTime = "23:30",
                afternoonStartTime = null,
                eveningStartTime = null,
                classDurationMinutes = 45,
                breakDurationMinutes = 10,
            )
        }
        assertTrue(e.message!!.contains("section_crosses_midnight"))
        assertTrue(e.message!!.contains("sectionNumber=1"))
    }

    @Test
    fun quickBuilder_validatesArguments() { // [Dart抄录/推演]
        // classDuration <= 0
        assertThrows(DartFormatException::class.java) {
            buildQuickSectionTimes(1, 0, 0, "08:00", null, null, 0, 10)
        }
        // breakDuration < 0
        assertThrows(DartFormatException::class.java) {
            buildQuickSectionTimes(1, 0, 0, "08:00", null, null, 45, -1)
        }
        // 全 0 节
        assertThrows(DartFormatException::class.java) {
            buildQuickSectionTimes(0, 0, 0, null, null, null, 45, 10)
        }
        // 有节数但没给开始时间
        val e = assertThrows(DartFormatException::class.java) {
            buildQuickSectionTimes(1, 0, 0, null, null, null, 45, 10)
        }
        assertEquals("period_start_time_required", e.message)
    }

    // ---------- validateSectionTimes [Dart抄录] ----------

    @Test
    fun validation_rejectsEndBeforeStart() {
        val msg = validateSectionTimes(listOf(SectionTime("23:30", "00:15")))
        assertTrue(msg!!.contains("section_end_must_after_start"))
        assertTrue(msg.contains("sectionNumber=1"))
    }

    @Test
    fun validation_rangeGuard_rejectsImpossibleClock() { // [Dart抄录] 范围守卫组
        for (bad in listOf("25:00" to "26:00", "08:00" to "08:75", "-1:00" to "02:00", "08:00" to "09:60")) {
            // JUnit4 的 assertThrows 无 reason 参数；消息用 try/catch 自证。
            val thrown = runCatching {
                validateSectionTimes(listOf(SectionTime(bad.first, bad.second)))
            }.exceptionOrNull()
            assertTrue(
                "${bad.first}-${bad.second} 应抛 DartFormatException，实际=${thrown?.javaClass?.simpleName ?: "未抛"}",
                thrown is DartFormatException,
            )
        }
    }

    @Test
    fun validation_endOfDay24_isLegal_butNot24_30() { // [Dart抄录]
        assertNull(validateSectionTimes(listOf(SectionTime("22:00", "24:00"))))
        assertThrows(DartFormatException::class.java) {
            validateSectionTimes(listOf(SectionTime("22:00", "24:30")))
        }
    }

    @Test
    fun validation_normalAndOrderRules() { // [Dart抄录]
        assertNull(
            validateSectionTimes(
                listOf(SectionTime("08:00", "08:45"), SectionTime("09:00", "09:45")),
            ),
        )
        val msg = validateSectionTimes(
            listOf(SectionTime("08:00", "09:00"), SectionTime("08:30", "09:30")),
        )
        assertTrue(msg!!.contains("section_start_before_previous_end"))
    }

    @Test
    fun validation_emptyAndAllPlaceholder() { // [Dart推演 time_scheme.dart:96-139]
        assertEquals("at_least_one_section_required", validateSectionTimes(emptyList()))
        // 整条空 = 补位形状，放过；但全是占位 = 没有可用节次表
        assertEquals(
            "at_least_one_section_required",
            validateSectionTimes(listOf(SectionTime("", ""), SectionTime("", ""))),
        )
        // 半空（只填一半）是真错误：endTime 空 → clockMinutes("") 抛
        assertThrows(DartFormatException::class.java) {
            validateSectionTimes(listOf(SectionTime("08:00", "")))
        }
        // 有占位也有真实节次 → 校验通过
        assertNull(validateSectionTimes(listOf(SectionTime("", ""), SectionTime("08:00", "08:45"))))
    }

    // ---------- isSectionTimeSpanValid [Dart抄录] ----------

    @Test
    fun spanValidity_endOfDay24_evenWhenOnlyChangingStart() {
        assertTrue(isSectionTimeSpanValid("08:00", "24:00"))
        assertTrue(isSectionTimeSpanValid("23:00", "24:00"))
        assertFalse(isSectionTimeSpanValid("24:00", "24:00"))
    }

    @Test
    fun spanValidity_crossDayAndZeroLengthRejected() {
        assertFalse(isSectionTimeSpanValid("08:00", "00:00"))
        assertFalse(isSectionTimeSpanValid("08:00", "08:00"))
        assertFalse(isSectionTimeSpanValid("23:30", "24:30"))
    }

    @Test
    fun spanValidity_normalAndGarbageFallback() {
        assertTrue(isSectionTimeSpanValid("08:00", "08:45"))
        // 解析不出来的串按 0 分钟处理：畸形值不在这里猜语义
        assertFalse(isSectionTimeSpanValid("上午8点", ""))
    }

    // ---------- clockMinutes / minutesToClock [Dart推演] ----------

    @Test
    fun clockMinutes_boundaries() {
        assertEquals(0, clockMinutes("00:00"))
        assertEquals(1439, clockMinutes("23:59"))
        assertEquals(1440, clockMinutes("24:00"))
        assertEquals(480, clockMinutes("08:00"))
        assertThrows(DartFormatException::class.java) { clockMinutes("24:01") }
        assertThrows(DartFormatException::class.java) { clockMinutes("8") }
        assertThrows(DartFormatException::class.java) { clockMinutes("") }
        assertThrows(DartFormatException::class.java) { clockMinutes("08:00:00") }
    }

    @Test
    fun minutesToClock_endOfDayNotWrapped() { // [Dart抄录] 1440 必须写 "24:00"
        assertEquals("24:00", minutesToClock(1440))
        assertEquals("00:00", minutesToClock(0))
        assertEquals("08:45", minutesToClock(8 * 60 + 45))
        assertEquals("00:00", minutesToClock(1440 * 2)) // % 1440 回绕
    }

    // ---------- TimeScheme 序列化 [Dart抄录] ----------

    @Test
    fun timeScheme_serializesCompleteState() {
        val scheme = TimeScheme(
            id = "summer",
            name = "夏季作息",
            sections = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")),
            createdAt = DartTime.parseIso("2026-03-22T09:00:00"),
            updatedAt = DartTime.parseIso("2026-03-22T10:00:00"),
        )
        val restored = TimeScheme.fromJson(scheme.toJson())
        assertEquals("summer", restored.id)
        assertEquals("夏季作息", restored.name)
        assertEquals(2, restored.sectionCount)
        assertEquals("08:00-08:45", restored.sections.first().displayText)
        assertEquals(DartTime.parseIso("2026-03-22T09:00:00"), restored.createdAt)
        assertEquals(DartTime.parseIso("2026-03-22T10:00:00"), restored.updatedAt)
        // 键名契约
        assertEquals(
            listOf("id", "name", "sections", "createdAt", "updatedAt"),
            scheme.toJson().keys.toList(),
        )
    }

    @Test
    fun timeScheme_fromJson_keepsSectionPositionsWhenEntryMalformed() { // [Dart抄录] 回归钉 A5
        val scheme = TimeScheme.fromJson(
            linkedMapOf(
                "id" to "scheme-align",
                "name" to "对齐测试",
                "sections" to listOf(
                    linkedMapOf<String, Any?>("startTime" to "08:00", "endTime" to "08:45"),
                    linkedMapOf<String, Any?>("startTime" to "09:00"), // 坏：缺 endTime
                    "not-a-map",
                    linkedMapOf<String, Any?>("startTime" to "10:00", "endTime" to "10:45"),
                ),
            ),
        )
        // 位置必须保持：第 4 节仍是第 4 节
        assertEquals(4, scheme.sections.size)
        assertEquals("08:00", scheme.sections[0].startTime)
        assertEquals("10:00", scheme.sections[3].startTime)
        assertEquals("10:45", scheme.sections[3].endTime)
        // 补出来的空洞留空时间（作息页渲染 `-`），不拿别处模板冒充真实铃点
        assertEquals("", scheme.sections[1].startTime)
        assertEquals("", scheme.sections[1].endTime)
        assertEquals("", scheme.sections[2].startTime)
    }

    @Test
    fun timeScheme_wellFormedRoundTrip() { // [Dart抄录]
        val original = TimeScheme.fromJson(
            linkedMapOf(
                "id" to "scheme-clean",
                "name" to "正常模板",
                "sections" to listOf(
                    linkedMapOf<String, Any?>("startTime" to "08:00", "endTime" to "08:45"),
                    linkedMapOf<String, Any?>("startTime" to "08:55", "endTime" to "09:40"),
                    linkedMapOf<String, Any?>("startTime" to "10:00", "endTime" to "10:45"),
                ),
            ),
        )
        assertEquals(3, original.sections.size)
        val restored = TimeScheme.fromJsonString(original.toJsonString())
        assertEquals(original.sections.map { it.displayText }, restored.sections.map { it.displayText })
    }

    @Test
    fun timeScheme_fromJson_rejectsMissingId_andDefaultsName() { // [Dart推演 time_scheme.dart:32-58]
        assertThrows(DartFormatException::class.java) {
            TimeScheme.fromJson(linkedMapOf("name" to "x"))
        }
        assertThrows(DartFormatException::class.java) {
            TimeScheme.fromJson(linkedMapOf("id" to "  "))
        }
        assertThrows(DartFormatException::class.java) {
            TimeScheme.fromJson(linkedMapOf("id" to 42))
        }
        // name 缺失 → 未命名时间模板；sections 缺失 → 空
        val bare = TimeScheme.fromJson(linkedMapOf<String, Any?>("id" to "a"))
        assertEquals(TimeScheme.DEFAULT_NAME, bare.name)
        assertEquals(0, bare.sectionCount)
        // sections 非 List → 空表
        val weird = TimeScheme.fromJson(linkedMapOf("id" to "a", "sections" to "bad"))
        assertEquals(0, weird.sectionCount)
    }

    // ---------- sectionsSignature [Dart推演] ----------

    @Test
    fun sectionsSignature_valueEquality() {
        val a = listOf(SectionTime("08:00", "08:45"))
        val b = listOf(SectionTime("08:00", "08:45"))
        assertEquals(sectionsSignature(a), sectionsSignature(b))
        assertFalse(sectionsSignature(a) == sectionsSignature(listOf(SectionTime("08:00", "09:00"))))
        // 与 Dart jsonEncode(sections.map(toJson).toList()) 同形
        assertEquals("""[{"startTime":"08:00","endTime":"08:45"}]""", sectionsSignature(a))
    }
}
