package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * LenientJson / DartTime / CourseTask / ScheduleItem / TimetableProfile 移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/models/lenient_field_type_parsing_test.dart、
 *   test/models/timetable_profile_test.dart、test/models/external_json_lenient_parsing_test.dart；
 * - [Dart推演]：对照 lib/models/settings/lenient_json_readers.dart、
 *   course_task.dart、schedule_item.dart、timetable_profile.dart 逐行推演；
 * - [人推]：边界值。
 */
class LenientAndProfileTest {

    // ---------- LenientJson [Dart抄录 lenient_json_readers.dart] ----------

    @Test
    fun lenientString_toStringCoercion() {
        assertEquals("1", LenientJson.string(1L))
        assertEquals("x", LenientJson.string("x"))
        assertEquals("1.5", LenientJson.string(1.5))
        assertNull(LenientJson.string(null))
        assertEquals("true", LenientJson.string(true))
    }

    @Test
    fun lenientBool_neverGuesses() { // [Dart抄录] '1'/1/0 都不是 bool
        assertEquals(true, LenientJson.bool(true))
        assertEquals(false, LenientJson.bool(false))
        assertEquals(true, LenientJson.bool("true"))
        assertEquals(false, LenientJson.bool("FALSE")) // 大小写不敏感、trim
        assertEquals(true, LenientJson.bool("  True  "))
        assertNull(LenientJson.bool("1"))
        assertNull(LenientJson.bool(1L))
        assertNull(LenientJson.bool(0L))
        assertNull(LenientJson.bool(null))
        assertNull(LenientJson.bool("yes"))
    }

    @Test
    fun lenientInt_doubleTruncates_stringTryParse() { // [Dart抄录]
        assertEquals(3L, LenientJson.int(3L))
        assertEquals(2L, LenientJson.int(2.7)) // 截断
        assertEquals(-2L, LenientJson.int(-2.7))
        assertEquals(20L, LenientJson.int("20"))
        assertEquals(20L, LenientJson.int(" 20 "))
        assertNull(LenientJson.int("20.5")) // tryParse 失败按缺键
        assertNull(LenientJson.int("第三周"))
        assertNull(LenientJson.int(null))
        assertNull(LenientJson.int(true))
    }

    @Test
    fun lenientDouble_numberAndString() {
        assertEquals(1.5, LenientJson.double(1.5)!!, 0.0)
        assertEquals(2.0, LenientJson.double(2L)!!, 0.0)
        assertEquals(0.5, LenientJson.double(" 0.5 ")!!, 0.0)
        assertNull(LenientJson.double("abc"))
        assertNull(LenientJson.double(null))
    }

    @Test
    fun lenientList_andStringList() {
        assertEquals(listOf<Any?>(1L, "a"), LenientJson.list(listOf(1L, "a")))
        assertNull(LenientJson.list("bad"))
        assertNull(LenientJson.list(null))
        assertEquals(listOf("a", "b"), LenientJson.stringList(listOf("a", 1L, "b", null)))
        assertNull(LenientJson.stringList("bad"))
    }

    // ---------- DartTime [人推] ----------

    @Test
    fun dartTime_isoRoundTrip() {
        val t = DartTime.dateTime(2026, 3, 22, 9, 30)
        assertEquals("2026-03-22T09:30:00.000", DartTime.toIso(t))
        assertEquals(t, DartTime.parseIso("2026-03-22T09:30:00"))
        assertEquals(t, DartTime.parseIso("2026-03-22T09:30:00.000"))
        // 日期只有 y-m-d
        assertEquals(DartTime.dateTime(2026, 11, 5), DartTime.parseIso("2026-11-05"))
        assertNull(DartTime.tryParseIso("garbage"))
        assertNull(DartTime.tryParseIso(null))
        assertNull(DartTime.tryParseIso(""))
    }

    @Test
    fun dartTime_carryOverNormalization() { // [人推] Dart DateTime(2026,2,30) 顺延到 3-02
        assertEquals(DartTime.dateTime(2026, 3, 2), DartTime.dateTime(2026, 2, 30))
        assertEquals(DartTime.dateTime(2027, 1, 1), DartTime.dateTime(2026, 13, 1))
        // addDays 保留时分、跨月跨年
        assertEquals(
            DartTime.dateTime(2026, 3, 1, 8, 30),
            DartTime.addDays(DartTime.dateTime(2026, 2, 27, 8, 30), 2),
        )
        // 2026-02-29 是无效日（2026 非闰年）→ 顺延 3-01
        assertEquals(DartTime.dateTime(2026, 3, 1), DartTime.dateTime(2026, 2, 29))
    }

    // ---------- CourseTask [Dart抄录 lenient_field_type_parsing_test.dart] ----------

    @Test
    fun task_numericTitleCourseIdNoteCoercedToString() { // [Dart抄录]
        val task = CourseTask.fromJson(
            linkedMapOf(
                "id" to "task-1",
                "title" to 12345L,
                "courseId" to 42L,
                "note" to 9.5,
            ),
        )
        assertEquals("task-1", task.id)
        assertEquals("12345", task.title)
        assertEquals("42", task.courseId)
        assertEquals("9.5", task.note)
        assertFalse(task.isCompleted)
        assertEquals(CourseTaskSource.MANUAL, task.source)
    }

    @Test
    fun task_sourceWeekNumberAndString() { // [Dart抄录]
        assertEquals(7L, CourseTask.fromJson(linkedMapOf("id" to "a", "sourceWeek" to "7")).sourceWeek)
        assertEquals(12L, CourseTask.fromJson(linkedMapOf("id" to "a", "sourceWeek" to 12L)).sourceWeek)
        assertNull(CourseTask.fromJson(linkedMapOf("id" to "a", "sourceWeek" to "第三周")).sourceWeek)
    }

    @Test
    fun task_boolAsStringFallsBackFalse() { // [Dart抄录] 不猜
        assertFalse(CourseTask.fromJson(linkedMapOf("id" to "a", "isCompleted" to "true")).isCompleted)
        assertTrue(CourseTask.fromJson(linkedMapOf("id" to "a", "isCompleted" to true)).isCompleted)
        assertFalse(CourseTask.fromJson(linkedMapOf("id" to "a", "isCompleted" to false)).isCompleted)
    }

    @Test
    fun task_unknownSourceFallsBackManual() { // [Dart抄录]
        assertEquals(
            CourseTaskSource.HOMEWORK_MARK,
            CourseTask.fromJson(linkedMapOf("id" to "a", "source" to "homework_mark")).source,
        )
        assertEquals(
            CourseTaskSource.MANUAL,
            CourseTask.fromJson(linkedMapOf("id" to "a", "source" to 7L)).source,
        )
    }

    @Test
    fun task_dueDateStringParses_millisReturnsNull() { // [Dart抄录]
        assertEquals(
            DartTime.dateTime(2026, 11, 5),
            CourseTask.fromJson(linkedMapOf("id" to "a", "dueDate" to "2026-11-05")).dueDate,
        )
        assertNull(CourseTask.fromJson(linkedMapOf("id" to "a", "dueDate" to 1730000000000L)).dueDate)
    }

    @Test
    fun task_idMissingOrBlankThrows_numberIdCoerced() { // [Dart抄录]
        assertThrows(DartFormatException::class.java) {
            CourseTask.fromJson(linkedMapOf("title" to "x"))
        }
        assertThrows(DartFormatException::class.java) {
            CourseTask.fromJson(linkedMapOf("id" to "   "))
        }
        assertEquals("123", CourseTask.fromJson(linkedMapOf("id" to 123L)).id)
    }

    @Test
    fun task_roundTrip_jsonByteFrozen() { // [Dart抄录] 序列化输出逐键不变（格式冻结）
        val task = CourseTask(
            id = "task-9",
            title = "交作业",
            courseId = "c-1",
            sourceWeek = 3,
            dueDate = DartTime.dateTime(2026, 11, 8, 18),
            note = "记得带",
            isCompleted = true,
            source = CourseTaskSource.HOMEWORK_MARK,
            createdAt = DartTime.dateTime(2026, 11, 1, 9),
            updatedAt = DartTime.dateTime(2026, 11, 2, 10),
        )
        val json = task.toJson()
        // isUserEdited=false 不写键（保持旧档案字节不变）
        assertFalse(json.containsKey("isUserEdited"))
        val restored = CourseTask.fromJson(json)
        assertEquals(json, restored.toJson())
        // isUserEdited=true 写键
        val edited = task.copy(isUserEdited = true)
        assertTrue(edited.toJson().containsKey("isUserEdited"))
        assertEquals(true, edited.toJson()["isUserEdited"])
    }

    @Test
    fun task_keysMatchDartContract() { // [Dart抄录 course_task.dart:88-104]
        val keys = CourseTask(
            id = "t", title = "x", createdAt = DartTime.dateTime(2026, 1, 1), updatedAt = DartTime.dateTime(2026, 1, 1),
            isUserEdited = true,
        ).toJson().keys.toList()
        assertEquals(
            listOf("id", "title", "courseId", "sourceWeek", "dueDate", "note", "isCompleted", "source", "isUserEdited", "createdAt", "updatedAt"),
            keys,
        )
    }

    @Test
    fun task_compareByDueDate() { // [Dart推演 course_task.dart:210-236]
        val base = { id: String, due: LocalDateTime?, done: Boolean ->
            CourseTask(id = id, title = "t-$id", dueDate = due, isCompleted = done, createdAt = DartTime.dateTime(2026, 1, 1), updatedAt = DartTime.dateTime(2026, 1, 1))
        }
        val noDue = base("n", null, false)
        val due1 = base("a", DartTime.dateTime(2026, 1, 1), false)
        val due2 = base("b", DartTime.dateTime(2026, 1, 2), false)
        // 无截止日垫底
        assertTrue(CourseTask.compareByDueDate(noDue, due1) > 0)
        assertTrue(CourseTask.compareByDueDate(due1, noDue) < 0)
        // 截止日升序
        assertTrue(CourseTask.compareByDueDate(due1, due2) < 0)
        // 同日：未完成在前
        val due1Done = base("c", DartTime.dateTime(2026, 1, 1), true)
        assertTrue(CourseTask.compareByDueDate(due1Done, due1) > 0)
        // 同日同完成态：标题序
        val due1a = base("z", DartTime.dateTime(2026, 1, 1), false)
        assertTrue(CourseTask.compareByDueDate(due1a, due1) > 0)
    }

    @Test
    fun task_isOverdue() { // [Dart推演 course_task.dart:81-86]
        val task = CourseTask(
            id = "t", title = "x",
            dueDate = DartTime.dateTime(2026, 1, 1),
            isCompleted = false,
            createdAt = DartTime.dateTime(2026, 1, 1), updatedAt = DartTime.dateTime(2026, 1, 1),
        )
        assertTrue(task.isOverdue(now = DartTime.dateTime(2026, 1, 2)))
        assertFalse(task.isOverdue(now = DartTime.dateTime(2026, 1, 1)))
        assertFalse(task.copy(isCompleted = true).isOverdue(now = DartTime.dateTime(2026, 1, 2)))
        assertFalse(task.copy(dueDate = null).isOverdue(now = DartTime.dateTime(2026, 1, 2)))
    }

    // ---------- ScheduleItem [Dart抄录 lenient_field_type_parsing_test.dart] ----------

    @Test
    fun scheduleItem_numericTitleLocationCoerced() { // [Dart抄录]
        val item = ScheduleItem.fromJson(
            linkedMapOf(
                "id" to "item-1",
                "title" to 99L,
                "location" to 7L,
                "startTime" to "09:30",
                "endTime" to "10:20",
                "color" to "#123456",
                "startDate" to "2026-10-01",
                "endDate" to "2026-12-31",
                "recurrence" to "weekly",
            ),
        )
        assertEquals("item-1", item.id)
        assertEquals("99", item.title)
        assertEquals("7", item.location)
        assertEquals("09:30", item.startTime)
        assertEquals("10:20", item.endTime)
        assertEquals("#123456", item.color)
        assertEquals(DartTime.dateTime(2026, 10, 1), item.startDate)
        assertEquals(DartTime.dateTime(2026, 12, 31), item.endDate)
        assertEquals(ScheduleRecurrence.WEEKLY, item.recurrence)
    }

    @Test
    fun scheduleItem_defaultsForMissingTimes() { // [Dart抄录] startTime/endTime 缺失退默认钟点
        val item = ScheduleItem.fromJson(linkedMapOf("id" to "a"))
        assertEquals("08:00", item.startTime)
        assertEquals("09:00", item.endTime)
        assertEquals(ScheduleRecurrence.NONE, item.recurrence)
        assertTrue(item.enabled) // 字符串 'false' 按缺省 true（不猜）
        assertNull(item.reminderMinutesBefore)
    }

    @Test
    fun scheduleItem_idMissingOrBlankThrows() { // [Dart推演]
        assertThrows(DartFormatException::class.java) { ScheduleItem.fromJson(linkedMapOf()) }
        assertThrows(DartFormatException::class.java) { ScheduleItem.fromJson(linkedMapOf("id" to "  ")) }
    }

    @Test
    fun scheduleItem_occursOn_recurrenceAndExceptions() { // [Dart推演 schedule_item.dart:353-370]
        val weekly = ScheduleItem(
            id = "w", title = "t",
            startDate = DartTime.dateTime(2026, 1, 5), // 周一
            endDate = DartTime.dateTime(2026, 1, 31),
            startTime = "08:00", endTime = "09:00",
            createdAt = DartTime.dateTime(2026, 1, 1), updatedAt = DartTime.dateTime(2026, 1, 1),
            recurrence = ScheduleRecurrence.WEEKLY,
        )
        assertTrue(weekly.occursOn(DartTime.dateTime(2026, 1, 12))) // 下一个周一
        assertFalse(weekly.occursOn(DartTime.dateTime(2026, 1, 13))) // 周二
        assertFalse(weekly.occursOn(DartTime.dateTime(2026, 2, 2))) // 越界
        // 越界前
        assertFalse(weekly.occursOn(DartTime.dateTime(2026, 1, 4)))
        // exceptionDates
        val withException = weekly.copy(exceptionDates = listOf(DartTime.dateTime(2026, 1, 12)))
        assertFalse(withException.occursOn(DartTime.dateTime(2026, 1, 12)))
        // daily
        val daily = weekly.copy(recurrence = ScheduleRecurrence.DAILY)
        assertTrue(daily.occursOn(DartTime.dateTime(2026, 1, 13)))
        // none：区间内都算
        val none = weekly.copy(recurrence = ScheduleRecurrence.NONE)
        assertTrue(none.occursOn(DartTime.dateTime(2026, 1, 13)))
        // series override：任何日子都算（原日期语义）
        val override = weekly.copy(seriesId = "series-1", occurrenceDate = DartTime.dateTime(2026, 1, 5))
        assertTrue(override.occursOn(DartTime.dateTime(2026, 1, 20)))
    }

    @Test
    fun scheduleItem_keysMatchDartContract() { // [Dart抄录 schedule_item.dart:177-201]
        val keys = ScheduleItem(
            id = "i", title = "t",
            startDate = DartTime.dateTime(2026, 1, 1), endDate = DartTime.dateTime(2026, 1, 2),
            startTime = "08:00", endTime = "09:00",
            createdAt = DartTime.dateTime(2026, 1, 1), updatedAt = DartTime.dateTime(2026, 1, 1),
        ).toJson().keys.toList()
        assertEquals(
            listOf(
                "id", "title", "location", "note", "date", "startDate", "endDate",
                "startTime", "endTime", "color", "createdAt", "updatedAt",
                "recurrence", "exceptionDates", "seriesId", "occurrenceDate",
                "reminderMinutesBefore", "enabled",
            ),
            keys,
        )
        // 三条日期键一起写（旧 payload 兼容）
        val json = ScheduleItem(
            id = "i", title = "t",
            startDate = DartTime.dateTime(2026, 1, 1), endDate = DartTime.dateTime(2026, 1, 2),
            startTime = "08:00", endTime = "09:00",
            createdAt = DartTime.dateTime(2026, 1, 1), updatedAt = DartTime.dateTime(2026, 1, 1),
        ).toJson()
        assertEquals("2026-01-01T00:00:00.000", json["date"])
        assertEquals("2026-01-01T00:00:00.000", json["startDate"])
        assertEquals("2026-01-02T00:00:00.000", json["endDate"])
    }

    @Test
    fun scheduleItem_recurrenceFromValue_aliases() { // [Dart抄录 schedule_item.dart:19-29]
        assertEquals(ScheduleRecurrence.DAILY, ScheduleRecurrence.fromValue("daily"))
        assertEquals(ScheduleRecurrence.DAILY, ScheduleRecurrence.fromValue("day"))
        assertEquals(ScheduleRecurrence.WEEKLY, ScheduleRecurrence.fromValue("weekly"))
        assertEquals(ScheduleRecurrence.WEEKLY, ScheduleRecurrence.fromValue("week"))
        assertEquals(ScheduleRecurrence.NONE, ScheduleRecurrence.fromValue("garbage"))
        assertEquals(ScheduleRecurrence.NONE, ScheduleRecurrence.fromValue(null))
        assertEquals(ScheduleRecurrence.WEEKLY, ScheduleRecurrence.fromValue(" WEEKLY ")) // trim + lower
    }

    // ---------- TimetableProfile [Dart抄录 timetable_profile_test.dart] ----------

    private fun fullProfile(): TimetableProfile {
        val now = DartTime.dateTime(2026, 3, 22, 9)
        return TimetableProfile(
            id = "profile-1",
            name = "大一上",
            courses = listOf(
                Course(
                    id = "course-1", name = "高数", teacher = "张老师", location = "A101",
                    dayOfWeek = 1, startSection = 1, endSection = 2,
                    startTime = "08:00", endTime = "09:40",
                ),
            ),
            tasks = listOf(
                CourseTask(
                    id = "task-1", title = "完成作业", courseId = "course-1", sourceWeek = 6,
                    dueDate = DartTime.dateTime(2026, 4, 6),
                    createdAt = now, updatedAt = now,
                ),
            ),
            exams = listOf(
                Exam(
                    id = "exam-1", courseId = "course-1", name = "期末",
                    dateTime = DartTime.dateTime(2026, 7, 1),
                    startTime = "08:30", endTime = "10:30",
                    createdAt = now, updatedAt = now,
                ),
            ),
            settings = TimetableSettings(semesterWeekCount = 24),
            currentWeek = 6,
            createdAt = now,
            lastUsedAt = DartTime.dateTime(2026, 3, 22, 10),
        )
    }

    @Test
    fun profile_serializesAndRestores() { // [Dart抄录]
        val restored = TimetableProfile.fromJson(fullProfile().toJson())
        assertEquals("profile-1", restored.id)
        assertEquals("大一上", restored.name)
        assertEquals("高数", restored.courses.single().name)
        assertEquals("完成作业", restored.tasks.single().title)
        assertEquals(6L, restored.tasks.single().sourceWeek)
        assertEquals(24, restored.settings.semesterWeekCount)
        assertEquals(6L, restored.currentWeek)
        assertEquals(DartTime.dateTime(2026, 3, 22, 9), restored.createdAt)
        assertEquals(DartTime.dateTime(2026, 3, 22, 10), restored.lastUsedAt)
        assertEquals(1, restored.exams.size)
    }

    @Test
    fun profile_skipsMalformedNestedCollections() { // [Dart抄录]
        val restored = TimetableProfile.fromJson(
            linkedMapOf(
                "id" to "profile-1",
                "name" to "大一上",
                "courses" to listOf("bad-course"),
                "tasks" to listOf(42L),
                "scheduleItems" to linkedMapOf("bad" to true),
                "exams" to listOf(null),
                "settings" to TimetableSettings.defaults().toJson(),
                "createdAt" to "2026-03-22T09:00:00.000",
                "lastUsedAt" to "2026-03-22T10:00:00.000",
            ),
        )
        assertTrue(restored.courses.isEmpty())
        assertTrue(restored.tasks.isEmpty())
        assertTrue(restored.scheduleItems.isEmpty())
        assertTrue(restored.exams.isEmpty())
    }

    @Test
    fun profile_clampsCurrentWeekToSemesterLength() { // [Dart抄录]
        val restored = TimetableProfile.fromJson(
            linkedMapOf(
                "id" to "profile-1",
                "name" to "大一上",
                "courses" to emptyList<Any?>(),
                "settings" to TimetableSettings(semesterWeekCount = 12).toJson(),
                "currentWeek" to 20L,
                "createdAt" to "2026-03-22T09:00:00.000",
                "lastUsedAt" to "2026-03-22T10:00:00.000",
            ),
        )
        assertEquals(12L, restored.currentWeek)
    }

    @Test
    fun profile_idRulesDeliberatelyStrict() { // [Dart抄录 external_json_lenient_parsing_test.dart]
        // 数字型 id 抛（不是收）
        assertThrows(DartFormatException::class.java) {
            TimetableProfile.fromJson(linkedMapOf("id" to 12345L, "name" to "我的课表"))
        }
        // id 缺失同样拒收
        assertThrows(DartFormatException::class.java) {
            TimetableProfile.fromJson(linkedMapOf("name" to "我的课表"))
        }
        // id 是字符串时正常解析
        val p = TimetableProfile.fromJson(linkedMapOf("id" to "p-1", "name" to "我的课表"))
        assertEquals("p-1", p.id)
        assertEquals("我的课表", p.name)
        // name 类型不对退回「未命名课表」（这条仍是宽松的）
        val unnamed = TimetableProfile.fromJson(linkedMapOf("id" to "p-1", "name" to 42L))
        assertEquals("未命名课表", unnamed.name)
    }

    @Test
    fun profile_lenientCurrentWeek_stringAndOutOfRange() { // [Dart推演 :124-127]
        // 字符串周次收下（lenientInt）
        val stringy = TimetableProfile.fromJson(
            linkedMapOf("id" to "p", "currentWeek" to "12"),
        )
        assertEquals(12L, stringy.currentWeek)
        // clamp(1, 30) 先行 → 30；再按 semesterWeekCount（默认 20）钳 → 20
        //（Dart 两条钳制串联：clamp(1,30) 后进 clampCurrentWeekToSettings）
        val high = TimetableProfile.fromJson(linkedMapOf("id" to "p", "currentWeek" to 50L))
        assertEquals(20L, high.currentWeek)
        // 0 → 1
        val zero = TimetableProfile.fromJson(linkedMapOf("id" to "p", "currentWeek" to 0L))
        assertEquals(1L, zero.currentWeek)
        // 缺键 → 1
        assertEquals(1L, TimetableProfile.fromJson(linkedMapOf("id" to "p")).currentWeek)
    }

    @Test
    fun profile_profileKindLenient() { // [Dart推演 :141-147]
        assertEquals(
            TimetableProfileKind.PARTNER_IMPORTED,
            TimetableProfile.fromJson(linkedMapOf("id" to "p", "profileKind" to "partnerImported")).profileKind,
        )
        // 非法名回落 normal
        assertEquals(
            TimetableProfileKind.NORMAL,
            TimetableProfile.fromJson(linkedMapOf("id" to "p", "profileKind" to 42L)).profileKind,
        )
        assertEquals(
            TimetableProfileKind.NORMAL,
            TimetableProfile.fromJson(linkedMapOf("id" to "p")).profileKind,
        )
    }

    @Test
    fun profile_keysMatchDartContract() { // [Dart抄录 timetable_profile.dart:70-84]
        val keys = fullProfile().toJson().keys.toList()
        assertEquals(
            listOf(
                "id", "name", "courses", "tasks", "scheduleItems", "exams",
                "settings", "currentWeek", "createdAt", "lastUsedAt", "profileKind",
            ),
            keys,
        )
    }

    @Test
    fun profile_parseProfilesPayload_dropsAndQuarantines() { // [Dart推演 :224-248]
        val good = fullProfile().toJson()
        val result = TimetableProfile.parseProfilesPayload(
            listOf(
                good,
                "not-a-map",
                42L,
                linkedMapOf("name" to "no-id"), // id 缺失 → profile_id_required → 丢弃
            ),
        )
        assertEquals(1, result.profiles.size)
        assertEquals(3, result.stats.droppedProfiles)
        assertTrue(result.didDrop)
        assertFalse(result.hasItemLevelOnlyDrops)
        // 留档包含 3 条被丢弃的原始条目
        assertEquals(3, result.quarantinedItems.size)
    }

    @Test
    fun profile_itemLevelDrops_notProfileLevel() { // [Dart推演 hasItemLevelOnlyDrops]
        val stats = TimetableProfile.Companion.ParseStats()
        TimetableProfile.fromJsonLenient(
            linkedMapOf(
                "id" to "p",
                "courses" to listOf("bad"), // 条目级丢弃
            ),
            stats,
        )
        assertEquals(1, stats.droppedCourses)
        assertEquals(0, stats.droppedProfiles)
        assertTrue(stats.hasItemLevelDrops)
        assertFalse(stats.hasProfileLevelDrops)
        // 留档写的是原始条目
        assertTrue(stats.quarantinedItems.single().contains("bad"))
    }

    @Test
    fun profile_quarantineCap() { // [Dart推演 :280-294] 上限 50 条
        val sink = mutableListOf<String>()
        for (i in 0 until 60) {
            TimetableProfile.quarantineDroppedItem(sink, "item-$i")
        }
        assertEquals(50, sink.size)
        // 单条超长截断到 4096 + 「…(截断)」
        val long = mutableListOf<String>()
        TimetableProfile.quarantineDroppedItem(long, "x".repeat(5000))
        assertEquals(TimetableProfile.MAX_QUARANTINED_ITEM_CHARS + "…(截断)".length, long.single().length)
        assertTrue(long.single().endsWith("…(截断)"))
    }
}
