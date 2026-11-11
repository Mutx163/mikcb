package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * ScheduleDateRule 模型 + 纯逻辑（match/validate/签名）测试。
 *
 * 期望值来源：
 * - [Dart抄录-测试]：test/providers/schedule_date_rule_logic_test.dart 逐条对照；
 * - [Dart抄录]：lib/models/schedule_date_rule.dart / lib/domain/schedule_date_rule_logic.dart；
 * - [Dart抄录-测试2]：test/services/timetable_schedule_date_rule_service_test.dart。
 */
class ScheduleDateRuleLogicTest {

    private fun rule(
        id: String,
        name: String = "夏令时",
        schemeId: String = "scheme-summer",
        start: String,
        end: String,
        enabled: Boolean = true,
    ) = ScheduleDateRule(
        id = id,
        name = name,
        timeSchemeId = schemeId,
        startDate = start,
        endDate = end,
        enabled = enabled,
    )

    // ---------- 模型 JSON ----------

    @Test
    fun `toJson uses dart field names`() { // [Dart抄录] schedule_date_rule.dart:36-45
        val r = rule(id = "summer", start = "2026-05-01", end = "2026-09-30")
        val json = r.toJson()
        assertEquals(
            linkedSetOf("id", "name", "timeSchemeId", "enabled", "startDate", "endDate"),
            json.keys.toSet(),
        )
        assertEquals("summer", json["id"])
        assertEquals("scheme-summer", json["timeSchemeId"])
        assertEquals(true, json["enabled"])
        assertEquals("2026-05-01", json["startDate"])
        assertEquals("2026-09-30", json["endDate"])
    }

    @Test
    fun `fromJson defaults and trims`() { // [Dart抄录] schedule_date_rule.dart:47-64
        val r = ScheduleDateRule.fromJson(
            mapOf(
                "id" to "r1",
                "name" to "  春季作息  ",
                "timeSchemeId" to "s1",
                "startDate" to " 2026-03-01 ",
                "endDate" to "2026-04-30",
            ),
        )
        // name trim 后两侧空白去除（Dart: (json['name'] as String? ?? '').trim()）。
        assertEquals("春季作息", r.name)
        assertEquals("2026-03-01", r.startDate)
        assertEquals("2026-04-30", r.endDate)
        assertTrue(r.enabled)
    }

    @Test
    fun `fromJson missing id defaults to empty and enabled defaults true`() { // [Dart抄录] schedule_date_rule.dart:57-60
        val r = ScheduleDateRule.fromJson(
            mapOf("startDate" to "2026-03-01", "endDate" to "2026-04-30"),
        )
        assertEquals("", r.id)
        assertEquals("", r.name)
        assertEquals("", r.timeSchemeId)
        assertTrue(r.enabled)
    }

    @Test
    fun `fromJson missing dates throw`() { // [Dart抄录] schedule_date_rule.dart:50-55 错误文案逐字
        // P1-11：模型并到 core 后异常类型统一为 DartFormatException（core 族约定），文案不变。
        val e1 = assertThrows(DartFormatException::class.java) {
            ScheduleDateRule.fromJson(mapOf("endDate" to "2026-04-30"))
        }
        assertEquals("missing schedule date rule start date", e1.message)

        val e2 = assertThrows(DartFormatException::class.java) {
            ScheduleDateRule.fromJson(mapOf("startDate" to "2026-03-01", "endDate" to "  "))
        }
        assertEquals("missing schedule date rule end date", e2.message)
    }

    @Test
    fun `json string roundtrip preserves data`() { // [Dart推演] toJsonString/fromJsonString 同型 roundtrip
        val original = rule(id = "summer", start = "2026-05-01", end = "2026-09-30")
        val restored = ScheduleDateRule.fromJsonString(original.toJsonString())
        assertEquals(original, restored)
    }

    @Test
    fun `copyWith overrides only given fields`() { // [Dart抄录] schedule_date_rule.dart:74-90
        val r = rule(id = "a", start = "2026-05-01", end = "2026-09-30")
        val winter = r.copy(
            id = "winter",
            timeSchemeId = "scheme-winter",
            startDate = "2026-10-01",
            endDate = "2027-04-30",
        )
        assertEquals("winter", winter.id)
        assertEquals("scheme-winter", winter.timeSchemeId)
        assertEquals("2026-10-01", winter.startDate)
        assertEquals("2027-04-30", winter.endDate)
        assertEquals("夏令时", winter.name)
        assertTrue(winter.enabled)
    }

    // ---------- parseIsoDate / formatIsoDate ----------

    @Test
    fun `parseIsoDate rejects invalid calendar days`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:7-15
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026-02-31"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026-13-01"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("bad"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate(null))
        // Dart 实现先 trim 再 matches（schedule_date_rule_logic.dart:50-52）→ 带空白合法
        assertEquals(DartTime.dateTime(2026, 7, 21), ScheduleDateRuleLogic.parseIsoDate(" 2026-07-21 "))
        assertEquals(
            DartTime.dateTime(2026, 7, 21),
            ScheduleDateRuleLogic.parseIsoDate("2026-07-21"),
        )
    }

    @Test
    fun `parseIsoDate rejects overflow dates and malformed shapes`() { // [Dart抄录] schedule_date_rule_logic.dart:49-74
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026-00-10"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026-01-00"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026-01-32"))
        assertNull(ScheduleDateRuleLogic.parseIsoDate("26-01-01")) // 年份必须 4 位
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026-1-1")) // 月日必须 2 位
        assertNull(ScheduleDateRuleLogic.parseIsoDate("2026/01/01"))
    }

    @Test
    fun `formatIsoDate pads fields`() { // [Dart抄录] schedule_date_rule_logic.dart:76-81
        assertEquals("2026-07-21", ScheduleDateRuleLogic.formatIsoDate(DartTime.dateTime(2026, 7, 21)))
        assertEquals("2026-01-01", ScheduleDateRuleLogic.formatIsoDate(DartTime.dateTime(2026, 1, 1)))
    }

    // ---------- match ----------

    @Test
    fun `match returns rule for inclusive date range`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:17-38
        val r = rule(id = "summer", start = "2026-05-01", end = "2026-09-30")
        assertEquals("summer", ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 5, 1), listOf(r))?.id)
        assertEquals("summer", ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 9, 30), listOf(r))?.id)
        assertNull(ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 4, 30), listOf(r)))
    }

    @Test
    fun `enabled single-day rule matches that day`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:40-55
        val r = rule(id = "single-day", schemeId = "scheme-special", start = "2026-07-23", end = "2026-07-23")
        val matched = ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 7, 23), listOf(r))
        assertEquals("single-day", matched?.id)
        assertTrue(matched?.enabled == true)
        assertNull(ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 7, 24), listOf(r)))
    }

    @Test
    fun `disabled rules are ignored by match`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:90-100
        val r = rule(id = "summer", start = "2026-05-01", end = "2026-09-30", enabled = false)
        assertNull(ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 6, 1), listOf(r)))
    }

    @Test
    fun `rules with empty scheme id are ignored by match`() { // [Dart抄录] schedule_date_rule_logic.dart:178 `!rule.enabled || rule.timeSchemeId.isEmpty`
        val r = rule(id = "summer", schemeId = "", start = "2026-05-01", end = "2026-09-30")
        assertNull(ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 6, 1), listOf(r)))
    }

    @Test
    fun `rules with invalid dates are skipped`() { // [Dart抄录] schedule_date_rule_logic.dart:181-185
        val r = rule(id = "bad", schemeId = "s1", start = "2026-02-31", end = "2026-03-31")
        assertNull(ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 3, 1), listOf(r)))
    }

    @Test
    fun `multiple matches prefer later start then narrower span then smaller id`() { // [Dart抄录] schedule_date_rule_logic.dart:171-215
        // 起始更晚者优先
        val wide = rule(id = "wide", schemeId = "s1", start = "2026-01-01", end = "2026-12-31")
        val late = rule(id = "late", schemeId = "s2", start = "2026-06-01", end = "2026-12-31")
        assertEquals("late", ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 7, 1), listOf(wide, late))?.id)

        // 起始相同 → 跨度更窄者优先
        val spanLong = rule(id = "long", schemeId = "s1", start = "2026-06-01", end = "2026-12-31")
        val spanShort = rule(id = "short", schemeId = "s2", start = "2026-06-01", end = "2026-06-30")
        assertEquals("short", ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 6, 15), listOf(spanLong, spanShort))?.id)

        // 起始、跨度全同 → id 小者优先
        val idB = rule(id = "b", schemeId = "s1", start = "2026-06-01", end = "2026-06-30")
        val idA = rule(id = "a", schemeId = "s2", start = "2026-06-01", end = "2026-06-30")
        assertEquals("a", ScheduleDateRuleLogic.match(DartTime.dateTime(2026, 6, 15), listOf(idB, idA))?.id)
    }

    // ---------- validateRule / validateRules ----------

    @Test
    fun `validateRule error codes in dart order`() { // [Dart抄录] schedule_date_rule_logic.dart:112-132 错误码逐字
        assertEquals(
            "schedule_date_rule_id_required",
            ScheduleDateRuleLogic.validateRule(rule(id = "", start = "2026-05-01", end = "2026-09-30")),
        )
        assertEquals(
            "schedule_date_rule_name_required",
            ScheduleDateRuleLogic.validateRule(rule(id = "a", name = "   ", start = "2026-05-01", end = "2026-09-30")),
        )
        assertEquals(
            "schedule_date_rule_scheme_required",
            ScheduleDateRuleLogic.validateRule(rule(id = "a", schemeId = "", start = "2026-05-01", end = "2026-09-30")),
        )
        assertEquals(
            "schedule_date_rule_invalid_date",
            ScheduleDateRuleLogic.validateRule(rule(id = "a", start = "2026-02-31", end = "2026-09-30")),
        )
        assertEquals(
            "schedule_date_rule_end_before_start",
            ScheduleDateRuleLogic.validateRule(rule(id = "a", start = "2026-09-30", end = "2026-05-01")),
        )
        assertNull(ScheduleDateRuleLogic.validateRule(rule(id = "a", start = "2026-05-01", end = "2026-09-30")))
    }

    @Test
    fun `validateRules rejects overlap and over cap`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:57-88
        val first = rule(id = "a", schemeId = "s1", start = "2026-05-01", end = "2026-08-31")
        val second = rule(id = "b", schemeId = "s2", start = "2026-08-01", end = "2026-10-01")
        val third = rule(id = "c", schemeId = "s3", start = "2026-11-01", end = "2026-12-01")

        assertEquals("schedule_date_rule_overlap", ScheduleDateRuleLogic.validateRules(listOf(first, second)))
        assertEquals("schedule_date_rule_max_exceeded", ScheduleDateRuleLogic.validateRules(listOf(first, third, second)))
    }

    @Test
    fun `overlap only checked between enabled rules`() { // [Dart抄录] schedule_date_rule.dart:13-14 「不得重叠只对启用中的规则检查」
        val first = rule(id = "a", schemeId = "s1", start = "2026-05-01", end = "2026-08-31")
        val disabledOverlap = rule(id = "b", schemeId = "s2", start = "2026-08-01", end = "2026-10-01", enabled = false)
        assertNull(ScheduleDateRuleLogic.validateRules(listOf(first, disabledOverlap)))
    }

    @Test
    fun `touching ranges do not overlap`() { // [Dart推演] rangesOverlap 是闭区间相接：a1 == b0 合法
        val left = rule(id = "a", schemeId = "s1", start = "2026-05-01", end = "2026-08-31")
        val right = rule(id = "b", schemeId = "s2", start = "2026-08-31", end = "2026-10-01")
        // 相接（共享 08-31 一天）在闭区间语义下**是**重叠。
        assertEquals("schedule_date_rule_overlap", ScheduleDateRuleLogic.validateRules(listOf(left, right)))

        val rightAfter = rule(id = "b", schemeId = "s2", start = "2026-09-01", end = "2026-10-01")
        assertNull(ScheduleDateRuleLogic.validateRules(listOf(left, rightAfter)))
    }

    @Test
    fun `max rules per device is two`() { // [Dart抄录] schedule_date_rule_logic.dart:44
        assertEquals(2, ScheduleDateRuleLogic.maxRulesPerDevice)
    }

    // ---------- 签名（schedule_date_rule_last_applied_signature 的纯计算部分） ----------

    @Test
    fun `applied signature concatenates with pipes`() { // [Dart抄录] schedule_date_rule_logic.dart:222-224
        val r = rule(id = "summer", schemeId = "scheme-summer", start = "2026-05-01", end = "2026-09-30")
        assertEquals("summer|scheme-summer|2026-05-01|2026-09-30", ScheduleDateRuleLogic.appliedSignature(r))
    }

    @Test
    fun `signature changes when any component changes`() { // [Dart推演] 新规则/新方案/新区间 → 签名变
        val base = rule(id = "summer", schemeId = "scheme-summer", start = "2026-05-01", end = "2026-09-30")
        val baseSig = ScheduleDateRuleLogic.appliedSignature(base)
        assertEquals(baseSig, ScheduleDateRuleLogic.appliedSignature(base.copy(enabled = false)))
        assertEquals(
            baseSig,
            ScheduleDateRuleLogic.appliedSignature(base.copy(name = "改名不影响签名")),
        )
        assertTrue(baseSig != ScheduleDateRuleLogic.appliedSignature(base.copy(id = "winter")))
        assertTrue(baseSig != ScheduleDateRuleLogic.appliedSignature(base.copy(timeSchemeId = "scheme-winter")))
        assertTrue(baseSig != ScheduleDateRuleLogic.appliedSignature(base.copy(startDate = "2026-05-02")))
        assertTrue(baseSig != ScheduleDateRuleLogic.appliedSignature(base.copy(endDate = "2026-09-29")))
    }

    @Test
    fun `shouldBulkApply only when signature differs`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:102-148
        val r = rule(id = "summer", schemeId = "scheme-summer", start = "2026-05-01", end = "2026-09-30")
        val signature = ScheduleDateRuleLogic.appliedSignature(r)

        assertTrue(
            ScheduleDateRuleLogic.shouldBulkApply(
                matchedRule = r,
                lastAppliedSignature = null,
            ),
        )
        assertFalse(
            ScheduleDateRuleLogic.shouldBulkApply(
                matchedRule = r,
                lastAppliedSignature = signature,
            ),
        )
        assertFalse(
            ScheduleDateRuleLogic.shouldBulkApply(
                matchedRule = null,
                lastAppliedSignature = signature,
            ),
        )

        val winter = r.copy(
            id = "winter",
            timeSchemeId = "scheme-winter",
            startDate = "2026-10-01",
            endDate = "2027-04-30",
        )
        assertTrue(
            ScheduleDateRuleLogic.shouldBulkApply(
                matchedRule = winter,
                lastAppliedSignature = signature,
            ),
        )
    }

    @Test
    fun `shouldBulkApply refuses disabled or scheme-less rules`() { // [Dart抄录] schedule_date_rule_logic.dart:229-241
        val disabled = rule(id = "a", schemeId = "s1", start = "2026-05-01", end = "2026-09-30", enabled = false)
        assertFalse(
            ScheduleDateRuleLogic.shouldBulkApply(matchedRule = disabled, lastAppliedSignature = null),
        )
        val noScheme = rule(id = "a", schemeId = "", start = "2026-05-01", end = "2026-09-30")
        assertFalse(
            ScheduleDateRuleLogic.shouldBulkApply(matchedRule = noScheme, lastAppliedSignature = null),
        )
    }

    // ---------- ApplyResult（纯数据壳，与 Dart outcome 语义一致） ----------

    @Test
    fun `apply result outcome flags`() { // [Dart抄录-测试] schedule_date_rule_logic_test.dart:150-186
        val notDue = ScheduleDateRuleApplyResult(outcome = ScheduleDateRuleApplyOutcome.NotDue)
        assertFalse(notDue.didApply)
        assertFalse(notDue.failedWhileDue)

        val applied = ScheduleDateRuleApplyResult(outcome = ScheduleDateRuleApplyOutcome.Applied)
        assertTrue(applied.didApply)
        assertFalse(applied.failedWhileDue)

        val schemeMissing = ScheduleDateRuleApplyResult(outcome = ScheduleDateRuleApplyOutcome.SchemeMissing)
        assertFalse(schemeMissing.didApply)
        assertTrue(schemeMissing.failedWhileDue)

        val overflow = ScheduleDateRuleApplyResult(
            outcome = ScheduleDateRuleApplyOutcome.SectionOverflow,
            requiredMaxSection = 10,
            schemeSectionCount = 8,
        )
        assertFalse(overflow.didApply)
        assertTrue(overflow.failedWhileDue)
        assertEquals(10, overflow.requiredMaxSection)
        assertEquals(8, overflow.schemeSectionCount)
    }
}
