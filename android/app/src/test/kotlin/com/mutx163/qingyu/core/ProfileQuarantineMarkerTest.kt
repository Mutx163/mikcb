package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * D5 守卫：留档条目的截断标记必须与 Dart **逐字**一致。
 *
 * Dart `lib/models/timetable_profile.dart:291` 对 profile 级留档用 `…(截断)`；
 * `lib/services/storage_service.dart:731` 的 `…<truncated>` 属于**尚未移植**的
 * 旧 `courses` 键留档通道，两者不是同一个通道，不能混用。
 * 该串会写进 `timetable_profiles_unparsed_items`，属持久化格式，改字即破坏冻结。
 */
class ProfileQuarantineMarkerTest {

    @Test
    fun `超长条目的截断标记是 Dart 的省略号加中文截断`() {
        val sink = mutableListOf<String>()
        TimetableProfile.quarantineDroppedItem(sink, "x".repeat(5000))

        assertEquals(1, sink.size)
        assertTrue("必须以 Dart 的 …(截断) 结尾：${sink[0].takeLast(8)}", sink[0].endsWith("…(截断)"))
        assertEquals(4096 + "…(截断)".length, sink[0].length)
    }

    @Test
    fun `未超长条目原样留档且不改字`() {
        val sink = mutableListOf<String>()
        TimetableProfile.quarantineDroppedItem(sink, mapOf("id" to "p1", "name" to "课表"))

        assertEquals(1, sink.size)
        assertEquals("""{"id":"p1","name":"课表"}""", sink[0])
    }

    @Test
    fun `留档上限之外不再追加`() {
        val sink = mutableListOf<String>()
        repeat(TimetableProfile.MAX_QUARANTINED_ITEMS + 5) { index ->
            TimetableProfile.quarantineDroppedItem(sink, index)
        }
        assertEquals(TimetableProfile.MAX_QUARANTINED_ITEMS, sink.size)
    }
}
