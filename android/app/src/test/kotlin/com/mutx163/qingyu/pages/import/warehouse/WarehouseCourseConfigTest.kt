package com.mutx163.qingyu.pages.import.warehouse

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * I2-2：`saveCourseConfig` 的解析口径（逐字对齐 Dart `WarehouseCourseConfigLogic.resolve`）。
 *
 * 核心契约：**无效值不覆盖用户已有设置**——周数 ≤0、开学日不是真实日历日，
 * 都按「脚本没给」处理（回 null），由调用方保留原值。
 */
class WarehouseCourseConfigTest {

    @Test
    fun `两项都给且合法时全解析出来`() {
        val resolved = resolveWarehouseCourseConfig(
            mapOf("semesterTotalWeeks" to 20, "semesterStartDate" to "2026-09-07"),
        )
        assertEquals(20, resolved.semesterWeekCount)
        assertEquals(LocalDateTime.of(2026, 9, 7, 0, 0), resolved.semesterStartDate)
        assertTrue(resolved.hasAnything)
    }

    @Test
    fun `周数容忍字符串与浮点形状 但 0 和负数按没给处理`() {
        assertEquals(
            20,
            resolveWarehouseCourseConfig(mapOf("semesterTotalWeeks" to "20")).semesterWeekCount,
        )
        assertEquals(
            20,
            resolveWarehouseCourseConfig(mapOf("semesterTotalWeeks" to 20.0)).semesterWeekCount,
        )
        assertNull(resolveWarehouseCourseConfig(mapOf("semesterTotalWeeks" to 0)).semesterWeekCount)
        assertNull(resolveWarehouseCourseConfig(mapOf("semesterTotalWeeks" to -3)).semesterWeekCount)
        assertNull(resolveWarehouseCourseConfig(mapOf("semesterTotalWeeks" to "abc")).semesterWeekCount)
    }

    @Test
    fun `开学日归一到本地零点 丢掉钟点`() {
        val date = warehouseSemesterStartDate("2026-9-7 08:00")
        assertEquals(LocalDateTime.of(2026, 9, 7, 0, 0), date)
    }

    @Test
    fun `越界日历日期拒绝 不回滚`() {
        // 宽松解析器会把 2026-13-45 归一成 2027-02-14——那会毁掉整学期周次。
        assertNull(warehouseSemesterStartDate("2026-13-45"))
        assertNull(warehouseSemesterStartDate("2026-02-30"))
        assertNull(warehouseSemesterStartDate("2026-00-10"))
        assertNull(warehouseSemesterStartDate("not-a-date"))
        assertNull(warehouseSemesterStartDate(""))
        assertNull(warehouseSemesterStartDate(null))
    }

    @Test
    fun `空载荷 hasAnything 为假（调用方什么都不写但回 true）`() {
        assertFalse(resolveWarehouseCourseConfig(emptyMap<Nothing, Nothing>()).hasAnything)
        assertFalse(
            resolveWarehouseCourseConfig(
                mapOf("firstDayOfWeek" to 1, "defaultClassDuration" to 45),
            ).hasAnything,
        )
    }

    @Test
    fun `不支持键清单与 Dart 逐字一致`() {
        assertEquals(
            listOf("firstDayOfWeek", "defaultClassDuration", "defaultBreakDuration"),
            WAREHOUSE_UNSUPPORTED_COURSE_CONFIG_KEYS,
        )
    }

    @Test
    fun `保存类桥消息解包 校验类型与 requestId`() {
        val ok = warehouseBridgeSaveRequest(
            """{"type":"saveCourseConfig","requestId":"course_config_1_x","payload":"{}"}""",
            "saveCourseConfig",
        )
        assertEquals("course_config_1_x", ok?.requestId)
        assertEquals("{}", ok?.payload)

        // 类型不符 / requestId 不可信 / 缺 payload：一律 null
        assertNull(
            warehouseBridgeSaveRequest(
                """{"type":"savePresetTimeSlots","requestId":"a","payload":"[]"}""",
                "saveCourseConfig",
            ),
        )
        assertNull(
            warehouseBridgeSaveRequest(
                """{"type":"saveCourseConfig","requestId":"a'b","payload":"{}"}""",
                "saveCourseConfig",
            ),
        )
        assertNull(
            warehouseBridgeSaveRequest(
                """{"type":"saveCourseConfig","requestId":"a"}""",
                "saveCourseConfig",
            ),
        )
    }
}
