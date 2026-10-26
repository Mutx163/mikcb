package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseSessionNote
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入导出纯逻辑端口测试。
 * dart 源：lib/domain/import_export_logic.dart；
 * 抄录用例：test/domain/import_course_id_map_test.dart、
 * test/domain/import_local_field_preserve_test.dart、
 * test/domain/import_export_section_expansion_test.dart、
 * test/providers/import_dedup_test.dart、test/utils/pure_parsers_invariants_test.dart。
 */
class ImportExportLogicTest {

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        teacher: String = "张老师",
        location: String = "A101",
        shortName: String? = null,
        color: String = "#2196F3",
        textColor: String? = null,
        weeks: List<Int>? = null,
        startWeek: Int = 1,
        endWeek: Int = 16,
        note: String? = null,
        description: String? = null,
        sessionNotes: Map<Int, CourseSessionNote>? = null,
        suspendedWeeks: List<Int>? = null,
        timeSchemeIdOverride: String? = null,
    ): Course = Course(
        id = id,
        name = name,
        shortName = shortName,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
        textColor = textColor,
        customWeeks = weeks,
        startWeek = startWeek,
        endWeek = endWeek,
        note = note,
        description = description,
        sessionNotes = sessionNotes,
        suspendedWeeks = suspendedWeeks,
        timeSchemeIdOverride = timeSchemeIdOverride,
    )

    // ------------------------------------------------------------------
    // dedupeImportedCourses（import_dedup_test.dart:40-105）
    // ------------------------------------------------------------------

    @Test
    fun dedupe_removes_duplicates_already_in_existing() {
        // [Dart抄录] import_dedup_test.dart:41-80
        val existing = listOf(
            course("a", "高等数学", dayOfWeek = 1, startSection = 1, endSection = 2, weeks = listOf(1, 2, 3, 4)),
        )
        val imported = listOf(
            course("b", "高等数学", dayOfWeek = 1, startSection = 1, endSection = 2, weeks = listOf(1, 2, 3, 4)),
            course("c", "大学英语", dayOfWeek = 2, startSection = 3, endSection = 4, weeks = listOf(1, 2, 3, 4)),
        )
        val deduped = dedupeImportedCourses(imported, existing)
        assertEquals(1, deduped.size)
        assertEquals("大学英语", deduped.first().name)
    }

    @Test
    fun dedupe_removes_duplicates_within_imported_batch() {
        // [Dart抄录] import_dedup_test.dart:82-105
        val imported = listOf(
            course("a", "高等数学", weeks = listOf(1, 2, 3, 4)),
            course("b", "高等数学", weeks = listOf(1, 2, 3, 4)),
        )
        assertEquals(1, dedupeImportedCourses(imported).size)
    }

    @Test
    fun dedupe_key_ignores_case_and_whitespace() {
        // [Dart推演] buildImportedCourseDedupKey 用 trim().toLowerCase()（:180-186）
        val imported = listOf(
            course("a", "高等数学", teacher = "张三", weeks = listOf(1, 2)),
            course("b", " 高等数学 ", teacher = "张三", weeks = listOf(1, 2)),
        )
        assertEquals(1, dedupeImportedCourses(imported).size)
    }

    // ------------------------------------------------------------------
    // mergeImportedCourseWithExisting（import_dedup_test.dart:205-238、
    // import_local_field_preserve_test.dart:47-78）
    // ------------------------------------------------------------------

    @Test
    fun merge_keeps_teacher_location_when_imported_blank() {
        // [Dart抄录] import_dedup_test.dart:205-238
        val existing = course(
            "a", "大学英语", dayOfWeek = 2, startSection = 3, endSection = 4,
            teacher = "李老师", location = "C303", shortName = "英语", color = "#00FF00",
            weeks = listOf(1, 2, 3),
        )
        val imported = course(
            "b", "大学英语", dayOfWeek = 2, startSection = 3, endSection = 4,
            teacher = "", location = "", weeks = listOf(1, 2, 3),
        )
        val merged = mergeImportedCourseWithExisting(existing, imported)
        assertEquals("a", merged.id)
        assertEquals("李老师", merged.teacher)
        assertEquals("C303", merged.location)
        assertEquals("英语", merged.shortName)
        assertEquals("#00FF00", merged.color)
    }

    @Test
    fun merge_keeps_local_suspended_weeks() {
        // [Dart抄录] import_local_field_preserve_test.dart:48-57
        val existing = course("c1", "高等数学", suspendedWeeks = listOf(5, 9))
        val imported = course("imported-1", "高等数学")
        val merged = mergeImportedCourseWithExisting(existing, imported)
        assertEquals(listOf(5, 9), merged.suspendedWeeks)
        assertTrue(merged.isSuspendedInWeek(5))
    }

    @Test
    fun merge_imported_suspended_weeks_win_when_present() {
        // [Dart抄录] import_local_field_preserve_test.dart:59-66
        val existing = course("c1", "高等数学", suspendedWeeks = listOf(5))
        val imported = course("imported-1", "高等数学", suspendedWeeks = listOf(7, 11))
        val merged = mergeImportedCourseWithExisting(existing, imported)
        assertEquals(listOf(7, 11), merged.suspendedWeeks)
    }

    @Test
    fun merge_sync_chain_keeps_suspended_weeks() {
        // [Dart抄录] import_local_field_preserve_test.dart:68-78
        val existing = course("c1", "高等数学", suspendedWeeks = listOf(5))
        val result = syncImportedCourses(
            existingCourses = listOf(existing),
            importedCourses = listOf(course("imported-1", "高等数学")),
        )
        assertEquals(1, result.mergedCourses.size)
        assertEquals("c1", result.mergedCourses.single().id)
        assertEquals(listOf(5), result.mergedCourses.single().suspendedWeeks)
    }

    // ------------------------------------------------------------------
    // preserveImportedCourseLocalSharedFields（import_local_field_preserve_test.dart:81-113）
    // ------------------------------------------------------------------

    @Test
    fun preserve_keeps_notes_session_notes_time_scheme() {
        // [Dart抄录] import_local_field_preserve_test.dart:82-101
        val existing = course(
            "c1", "高等数学",
            note = "这周要交论文",
            sessionNotes = mapOf(3 to CourseSessionNote(text = "第 3 周作业：习题 12", hasHomework = true)),
            timeSchemeIdOverride = "scheme-night",
        )
        val imported = course("imported-1", "高等数学", dayOfWeek = 3, startSection = 5)
        val merged = preserveImportedCourseLocalSharedFields(existing, imported)
        assertEquals("这周要交论文", merged.note)
        assertEquals(existing.sessionNotes, merged.sessionNotes)
        assertEquals("scheme-night", merged.timeSchemeIdOverride)
    }

    @Test
    fun preserve_keeps_local_suspended_weeks() {
        // [Dart抄录] import_local_field_preserve_test.dart:103-113
        val existing = course("c1", "高等数学", suspendedWeeks = listOf(6))
        val imported = course("imported-1", "高等数学")
        val merged = preserveImportedCourseLocalSharedFields(existing, imported)
        assertEquals(listOf(6), merged.suspendedWeeks)
    }

    // ------------------------------------------------------------------
    // syncImportedCourses（import_course_id_map_test.dart + import_dedup_test.dart）
    // ------------------------------------------------------------------

    @Test
    fun sync_soft_match_maps_imported_id_to_local_id() {
        // [Dart抄录] import_course_id_map_test.dart:37-45
        val result = syncImportedCourses(
            existingCourses = listOf(course("local-1", "数学")),
            importedCourses = listOf(course("remote-1", "数学")),
        )
        assertEquals(listOf("local-1"), result.mergedCourses.map { it.id })
        assertEquals("local-1", result.importedIdToLocalId["remote-1"])
    }

    @Test
    fun sync_new_course_identity_mapping() {
        // [Dart抄录] import_course_id_map_test.dart:47-55
        val result = syncImportedCourses(
            existingCourses = emptyList(),
            importedCourses = listOf(course("remote-9", "物理")),
        )
        assertEquals(listOf("remote-9"), result.mergedCourses.map { it.id })
        assertEquals("remote-9", result.importedIdToLocalId["remote-9"])
    }

    @Test
    fun sync_each_entry_maps_to_existing_course() {
        // [Dart抄录] import_course_id_map_test.dart:57-83
        val result = syncImportedCourses(
            existingCourses = listOf(
                course("local-math", "数学"),
                course("local-phy", "物理", dayOfWeek = 3),
            ),
            importedCourses = listOf(
                course("in-math", "数学"),
                course("in-phy", "物理", dayOfWeek = 3),
                course("in-chem", "化学", dayOfWeek = 4),
            ),
        )
        val finalIds = result.mergedCourses.map { it.id }.toSet()
        for ((key, value) in result.importedIdToLocalId) {
            assertTrue("导入课程 $key 映射到了不存在的 $value", value in finalIds)
        }
        assertEquals("local-math", result.importedIdToLocalId["in-math"])
        assertEquals("local-phy", result.importedIdToLocalId["in-phy"])
        assertEquals("in-chem", result.importedIdToLocalId["in-chem"])
    }

    @Test
    fun sync_deduped_duplicate_maps_to_survivor() {
        // [Dart抄录] import_course_id_map_test.dart:85-102
        val result = syncImportedCourses(
            existingCourses = emptyList(),
            importedCourses = listOf(
                course("dup-a", "数学"),
                course("dup-b", "数学"),
            ),
        )
        assertEquals(1, result.mergedCourses.size)
        val survivor = result.mergedCourses.single().id
        assertEquals(survivor, result.importedIdToLocalId["dup-a"])
        assertEquals(survivor, result.importedIdToLocalId["dup-b"])
    }

    @Test
    fun sync_empty_import_gives_empty_map() {
        // [Dart抄录] import_course_id_map_test.dart:104-113
        val result = syncImportedCourses(
            existingCourses = listOf(course("local-1", "数学")),
            importedCourses = emptyList(),
        )
        assertTrue(result.importedIdToLocalId.isEmpty())
        assertEquals(0, result.addedCount)
        assertEquals(0, result.updatedCount)
    }

    @Test
    fun sync_default_result_has_empty_map() {
        // [Dart抄录] import_course_id_map_test.dart:115-123
        val result = ImportedCourseSyncResult(emptyList(), 0, 0)
        assertTrue(result.importedIdToLocalId.isEmpty())
    }

    @Test
    fun sync_does_not_soft_match_across_weekdays() {
        // [Dart抄录] import_dedup_test.dart:107-147
        val existing = listOf(
            course(
                "a", "高等数学", dayOfWeek = 1, startSection = 1, endSection = 2,
                weeks = listOf(1, 2, 3, 4, 5, 6), teacher = "张老师", location = "A101",
                shortName = "高数", color = "#FF0000", note = "验收备注",
                description = "课程简介", timeSchemeIdOverride = "scheme_a",
            ),
        )
        val imported = listOf(
            course(
                "b", "高等数学", dayOfWeek = 3, startSection = 3, endSection = 4,
                weeks = listOf(1, 2, 3, 4, 5, 6), teacher = "张老师", location = "B202",
            ),
        )
        val result = syncImportedCourses(existing, imported)
        assertEquals(1, result.addedCount)
        assertEquals(0, result.updatedCount)
        assertEquals(2, result.mergedCourses.size)
        assertEquals(setOf(1, 3), result.mergedCourses.map { it.dayOfWeek }.toSet())
    }

    @Test
    fun sync_soft_match_same_weekday_keeps_local_fields() {
        // [Dart抄录] import_dedup_test.dart:149-202
        val existing = listOf(
            course(
                "a", "高等数学", dayOfWeek = 1, startSection = 1, endSection = 2,
                weeks = listOf(1, 2, 3, 4, 5, 6), teacher = "张老师", location = "A101",
                shortName = "高数", color = "#FF0000", note = "验收备注",
                description = "课程简介", timeSchemeIdOverride = "scheme_a",
            ),
        )
        val imported = listOf(
            course(
                "b", "高等数学", dayOfWeek = 1, startSection = 3, endSection = 4,
                weeks = listOf(1, 2, 3, 4, 5, 6), teacher = "张老师", location = "B202",
            ),
        )
        val result = syncImportedCourses(existing, imported)
        assertEquals(0, result.addedCount)
        assertEquals(1, result.updatedCount)
        assertEquals(1, result.mergedCourses.size)
        val merged = result.mergedCourses.first()
        assertEquals("a", merged.id)
        assertEquals(1, merged.dayOfWeek)
        assertEquals(3, merged.startSection)
        assertEquals(4, merged.endSection)
        assertEquals("B202", merged.location)
        assertEquals("高数", merged.shortName)
        assertEquals("#FF0000", merged.color)
        assertEquals("验收备注", merged.note)
        assertEquals("课程简介", merged.description)
        assertEquals("scheme_a", merged.timeSchemeIdOverride)
    }

    @Test
    fun sync_grouped_split_local_records_receive_shared_fields() {
        // [Dart抄录] import_dedup_test.dart:241-311
        val existing = listOf(
            course("a", "高等数学", weeks = listOf(1, 2, 3, 4, 5), shortName = "高数", color = "#FF0000"),
            course("b", "高等数学", weeks = listOf(7, 8), shortName = "高数", color = "#FF0000"),
            course("c", "高等数学", weeks = listOf(11, 12, 13), shortName = "高数", color = "#FF0000"),
        )
        val imported = listOf(
            course(
                "new", "高等数学", weeks = listOf(1, 2, 3, 4, 5, 7, 8, 11, 12, 13),
                teacher = "张老师", location = "A101",
            ),
        )
        val result = syncImportedCourses(existing, imported)
        assertEquals(0, result.addedCount)
        assertEquals(3, result.updatedCount)
        assertEquals(3, result.mergedCourses.size)
        assertEquals(
            setOf("1,2,3,4,5", "7,8", "11,12,13"),
            result.mergedCourses.map { it.activeWeeks.joinToString(",") }.toSet(),
        )
        assertTrue(result.mergedCourses.all { it.shortName == "高数" })
        assertTrue(result.mergedCourses.all { it.teacher == "张老师" })
    }

    @Test
    fun sync_keeps_local_only_courses_and_merges_same_day_updates() {
        // [Dart抄录] import_dedup_test.dart:314-363
        val existing = listOf(
            course(
                "a", "高等数学", weeks = listOf(1, 2, 3, 4, 5, 6),
                teacher = "张老师", location = "A101", shortName = "高数",
            ),
            course("stale", "线性代数", dayOfWeek = 5, startSection = 3, endSection = 4, weeks = listOf(1, 2, 3, 4)),
        )
        val imported = listOf(
            course(
                "new-a", "高等数学", startSection = 3, endSection = 4,
                weeks = listOf(1, 2, 3, 4, 5, 6), teacher = "张老师", location = "B202",
            ),
        )
        val result = syncImportedCourses(existing, imported)
        assertEquals(2, result.mergedCourses.size)
        assertEquals(0, result.addedCount)
        assertEquals(1, result.updatedCount)
        assertTrue(result.mergedCourses.any { it.name == "线性代数" })
    }

    // ------------------------------------------------------------------
    // replaceImportedCoursesPreservingLocalFields（import_dedup_test.dart:365-471）
    // ------------------------------------------------------------------

    @Test
    fun replace_removes_stale_and_keeps_local_metadata() {
        // [Dart抄录] import_dedup_test.dart:366-424
        val existing = listOf(
            course(
                "a", "高等数学", weeks = listOf(1, 2, 3, 4, 5, 6),
                teacher = "张老师", location = "A101", shortName = "高数",
                color = "#FF0000", note = "本地备注", description = "本地简介",
                timeSchemeIdOverride = "scheme_a",
            ),
            course("stale", "线性代数", dayOfWeek = 5, startSection = 3, endSection = 4, weeks = listOf(1, 2, 3, 4)),
        )
        val imported = listOf(
            course(
                "new-a", "高等数学", startSection = 3, endSection = 4,
                weeks = listOf(1, 2, 3, 4, 5, 6), teacher = "张老师", location = "B202",
            ),
        )
        val replaced = replaceImportedCoursesPreservingLocalFields(existing, imported)
        assertEquals(1, replaced.size)
        assertEquals("a", replaced.single().id)
        assertEquals("高等数学", replaced.single().name)
        assertEquals(1, replaced.single().dayOfWeek)
        assertEquals(3, replaced.single().startSection)
        assertEquals(4, replaced.single().endSection)
        assertEquals("B202", replaced.single().location)
        assertEquals("高数", replaced.single().shortName)
        assertEquals("#FF0000", replaced.single().color)
        assertEquals("本地备注", replaced.single().note)
        assertEquals("本地简介", replaced.single().description)
        assertEquals("scheme_a", replaced.single().timeSchemeIdOverride)
    }

    @Test
    fun replace_fans_shared_fields_into_split_schedules() {
        // [Dart抄录] import_dedup_test.dart:427-471
        val existing = listOf(
            course(
                "a", "大学英语", dayOfWeek = 2, startSection = 3, endSection = 4,
                weeks = listOf(1, 2, 3, 4, 5, 6, 7, 8), shortName = "英语",
                color = "#00FF00", description = "共享简介",
            ),
        )
        val imported = listOf(
            course("b", "大学英语", dayOfWeek = 2, startSection = 3, endSection = 4, weeks = listOf(1, 2, 3, 4)),
            course("c", "大学英语", dayOfWeek = 2, startSection = 3, endSection = 4, weeks = listOf(5, 6, 7, 8)),
        )
        val replaced = replaceImportedCoursesPreservingLocalFields(existing, imported)
        assertEquals(2, replaced.size)
        assertEquals(setOf("英语"), replaced.map { it.shortName }.toSet())
        assertEquals(setOf("#00FF00"), replaced.map { it.color }.toSet())
        assertEquals(setOf("共享简介"), replaced.map { it.description }.toSet())
    }

    // ------------------------------------------------------------------
    // buildExpandedSections（import_export_section_expansion_test.dart）
    // ------------------------------------------------------------------

    private fun table(vararg pairs: String): List<SectionTime> = pairs.map {
        SectionTime(it.split("-").first(), it.split("-").last())
    }

    @Test
    fun expand_from_last_parseable_end_when_last_entry_malformed() {
        // [Dart抄录] import_export_section_expansion_test.dart:25-39
        val expanded = buildExpandedSections(
            table("08:00-08:45", "08:55-上午8点半"),
            4,
        )
        assertEquals(4, expanded.size)
        assertEquals("08:55", expanded[2].startTime)
        assertTrue(expanded[3].startTime.compareTo("01:00") > 0)
    }

    @Test
    fun expand_stops_when_no_parseable_anchor() {
        // [Dart抄录] import_export_section_expansion_test.dart:41-53
        val expanded = buildExpandedSections(
            table("上午8点-上午8点半", "上午9点-上午9点半"),
            4,
        )
        assertEquals(2, expanded.size)
    }

    @Test
    fun expand_normal_behavior_unchanged() {
        // [Dart抄录] import_export_section_expansion_test.dart:55-70
        val expanded = buildExpandedSections(
            table("08:00-08:45", "08:55-09:40"),
            4,
        )
        assertEquals(listOf("08:00", "08:55", "09:50", "10:45"), expanded.map { it.startTime })
        assertEquals("10:35", expanded[2].endTime)
        assertEquals("11:30", expanded[3].endTime)
    }

    @Test
    fun expand_empty_starts_from_defaults() {
        // [Dart抄录] import_export_section_expansion_test.dart:72-77
        val expanded = buildExpandedSections(emptyList(), 2)
        assertTrue(expanded.size >= 2)
        assertEquals("08:00", expanded.first().startTime)
    }

    @Test
    fun expand_stops_before_crossing_end_of_day() {
        // [Dart推演] 末节 23:55 结束 → 下一节 00:05 起 +1:35 超过 1440 → 停
        // （锚点 23:05 可解析、课间 10、节长 45 → nextEnd = 1440 > 1440？=1440 不大于 1440）
        // 用整点对齐：22:55-23:40（末节），课间 10 → 23:50 + 45 = 24:35 > 1440 → 停
        val expanded = buildExpandedSections(
            table("22:00-23:40"),
            3,
        )
        assertEquals(1, expanded.size)
        // 但 24:00 恰好落界时允许（end == 1440）：20:00-20:45，课间10 → 20:55+45=21:40；再补 21:50+45=22:35
        val fits = buildExpandedSections(table("20:00-20:45"), 3)
        assertEquals(3, fits.size)
        assertEquals("20:55", fits[1].startTime)
        assertEquals("21:40", fits[1].endTime)
        assertEquals("21:50", fits[2].startTime)
        assertEquals("22:35", fits[2].endTime)
    }

    @Test
    fun expand_accepts_2400_as_anchor() {
        // [Dart推演] 24:00 是合法结束时间（parseClockToMinutes 放行）：
        // 末节 23:10-24:00，课间 10 → 下节 24:10 起，节长 45 → end=24:55 超界 → 停（只补不进去）
        val expanded = buildExpandedSections(table("23:10-24:00"), 2)
        assertEquals(1, expanded.size)
    }

    // ------------------------------------------------------------------
    // 其他纯函数
    // ------------------------------------------------------------------

    @Test
    fun preview_required_section_count() {
        // [Dart推演] import_export_logic.dart:44-55
        assertEquals(
            5,
            previewImportedCourseRequiredSectionCount(
                listOf(course("a", "数", endSection = 3), course("b", "物", endSection = 5)),
                10,
            ),
        )
        assertEquals(
            10,
            previewImportedCourseRequiredSectionCount(emptyList(), 10),
        )
    }

    @Test
    fun max_course_week_clamped() {
        // [Dart推演] import_export_logic.dart:57-69
        // 注意：customWeeks 走 Course 构造的 normalizeWeekList，999 越界会被
        // 丢弃（与 Dart Course 构造同口径）；钳到 30 的行为要用 endWeek 验证。
        assertEquals(
            30,
            maxCourseWeek(listOf(course("a", "数", endWeek = 999)), 20),
        )
        assertEquals(
            4,
            maxCourseWeek(listOf(course("a", "数", weeks = listOf(1, 2, 4))), 20),
        )
        assertEquals(
            20,
            maxCourseWeek(emptyList(), 20),
        )
        // [Dart推演] fallback 也被钳
        assertEquals(1, maxCourseWeek(emptyList(), 0))
        assertEquals(30, maxCourseWeek(emptyList(), 99))
        // customWeeks 优先于 endWeek；空 customWeeks 回落 endWeek
        assertEquals(
            6,
            maxCourseWeek(listOf(course("a", "数", endWeek = 16, weeks = listOf(1, 6))), 20),
        )
        assertEquals(
            16,
            maxCourseWeek(listOf(course("a", "数", endWeek = 16, weeks = emptyList())), 20),
        )
    }

    @Test
    fun course_lists_equal_by_json() {
        // [Dart推演] courseListsEqual 按 toJsonString 逐条比（:458-471）
        val a = course("a", "数")
        val b = course("a", "数")
        val c = course("a", "数", teacher = "李老师")
        assertTrue(courseListsEqual(listOf(a), listOf(b)))
        assertFalse(courseListsEqual(listOf(a), listOf(c)))
        assertFalse(courseListsEqual(listOf(a), listOf(a, b)))
        assertTrue(courseListsEqual(emptyList(), emptyList()))
    }

    @Test
    fun build_dedup_key_shape() {
        // [Dart推演] import_export_logic.dart:177-188 的键形态：
        // name|teacher|location|day|start|end|weeks（均 trim+lowercase，周次升序）
        val key = buildImportedCourseDedupKey(
            course("a", " 高等数学 ", teacher = " 张三 ", location = " A101 ",
                dayOfWeek = 2, startSection = 1, endSection = 3, weeks = listOf(3, 1, 2)),
        )
        assertEquals("高等数学|张三|a101|2|1|3|1,2,3", key)
    }

    @Test
    fun null_semantics_in_merge_follow_dart() {
        // [Dart推演] mergeImportedSharedFieldsIntoExistingSchedule 不动 suspendedWeeks
        // （:270-292 没有这一条 copyWith），本地停课周天然保住
        val existing = course("c1", "高等数学", suspendedWeeks = listOf(9))
        val imported = course("i1", "高等数学", suspendedWeeks = listOf(2))
        val merged = mergeImportedSharedFieldsIntoExistingSchedule(existing, imported)
        assertEquals(listOf(9), merged.suspendedWeeks)
        // note 也以 existing 为准（Dart :288）
        val existingNote = course("c1", "高等数学", note = "本地备注")
        val mergedNote = mergeImportedSharedFieldsIntoExistingSchedule(existingNote, imported)
        assertEquals("本地备注", mergedNote.note)
        // timeSchemeIdOverride 保持本地（Dart :290）
        val existingScheme = course("c1", "高等数学", timeSchemeIdOverride = "scheme-x")
        val mergedScheme = mergeImportedSharedFieldsIntoExistingSchedule(existingScheme, imported)
        assertEquals("scheme-x", mergedScheme.timeSchemeIdOverride)
    }
}
