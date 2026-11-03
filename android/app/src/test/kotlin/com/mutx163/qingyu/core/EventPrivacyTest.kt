package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 隐私闸门纯函数的行为测试（口径见 [EventPrivacy] 的 KDoc）。
 *
 * 咬合探针（2026-11-03 做过）：把 [EventPrivacy.allows] 里的黑名单判断注释掉
 * （放行 `course_name`）→ `敏感键无论值是什么类型都剥` 红 → 还原。
 * 证明本测试真的钉住了黑名单。
 */
class EventPrivacyTest {

    @Test
    fun `数值与布尔放行（计数_布尔_耗时_错误码_枚举编码）`() {
        assertTrue(EventPrivacy.allows("day_of_week", 1))
        assertTrue(EventPrivacy.allows("remaining_course_count", 42L))
        assertTrue(EventPrivacy.allows("duration_millis", 3.5))
        assertTrue(EventPrivacy.allows("has_short_name", false))
        assertTrue(EventPrivacy.allows("error_code", 500))
    }

    @Test
    fun `String 一律剥（白名单为空集_含存量随机id与日期）`() {
        // 白名单机制存在，但初始口径从紧：空集 ⇒ 任何 String 都不放行。
        assertTrue("SAFE_STRING_KEYS 应保持空集（放宽须同步改本测试并写明理由）", EventPrivacy.SAFE_STRING_KEYS.isEmpty())
        // 2026-11-03 盘点的存量 String 参数：随机 id 可关联单用户、日期是行为时间线。
        assertFalse(EventPrivacy.allows("schedule_item_id", "8f3c..."))
        assertFalse(EventPrivacy.allows("occurrence_date", "2026-11-03"))
        assertFalse(EventPrivacy.allows("exam_id", "e-001"))
        // 黑名单优先于一切口径：就算键进了白名单，黑名单键仍须拒绝。
        for (key in listOf("course_name", "teacher", "location", "profile_name", "url", "account")) {
            assertFalse("黑名单键 $key 不许因任何未来白名单放宽而放行", key in EventPrivacy.SAFE_STRING_KEYS)
        }
    }

    @Test
    fun `敏感键无论值是什么类型都剥`() {
        // 假想的「把课名编码成数字」绕过路径：键黑名单兜住。
        for (sensitive in listOf("course_name", "teacher_name", "location", "profile_name", "url", "account")) {
            assertFalse("黑名单键 $sensitive 传数字也不许过", EventPrivacy.allows(sensitive, 123))
            assertFalse("黑名单键 $sensitive 传布尔也不许过", EventPrivacy.allows(sensitive, true))
        }
    }

    @Test
    fun `黑名单覆盖现实敏感维度`() {
        for (key in listOf(
            "course_name", "course", "teacher", "teacher_name", "location", "location_name",
            "classroom", "profile_name", "note", "title", "name",
            "url", "link", "account", "user_id", "device_id", "email", "phone",
            "schedule_item_id", "exam_id", "occurrence_date",
        )) {
            assertTrue("黑名单缺 $key", key in EventPrivacy.SENSITIVE_PARAMETER_KEYS)
        }
    }

    @Test
    fun `自由文本与其他类型剥`() {
        assertFalse(EventPrivacy.allows("anything", null))
        assertFalse(EventPrivacy.allows("anything", listOf(1, 2)))
        assertFalse(EventPrivacy.allows("anything", mapOf("k" to 1)))
        assertFalse(EventPrivacy.allows("anything", Any()))
    }

    @Test
    fun `sanitize 保留合法项并剥掉其余_入参不被修改`() {
        val input = linkedMapOf<String, Any?>(
            "day_of_week" to 2,
            "section_count" to 3,
            "course_name" to "线性代数",
            "schedule_item_id" to "abc",
            "has_note" to false,
        )
        val snapshot = input.toMap()
        val sanitized = EventPrivacy.sanitize(input)

        assertEquals(mapOf("day_of_week" to 2, "section_count" to 3, "has_note" to false), sanitized)
        assertEquals("入参不许被改", snapshot, input)
    }
}
