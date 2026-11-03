package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 局域网传输包**纯逻辑**层的 L0 测试（批次 F17）。
 *
 * 这一组钉的是 Dart 口径本身（错误码、差异分类、引用校验、模板合并计划），
 * 不碰存储；「真落盘 / 失败回滚」在 [LanTransferApplyTest] 与
 * `LanEditRepositoryEndToEndTest` 里钉。
 *
 * 反例三件套（清单 §十一 F17 要求）：包损坏 / 版本不兼容 / 空课表，各自有用例。
 */
class LanTransferLogicTest {

    private val stamp: LocalDateTime = LocalDateTime.of(2026, 10, 30, 9, 0)

    // -----------------------------------------------------------------------
    // 反例一：包损坏
    // -----------------------------------------------------------------------

    @Test
    fun `包损坏 结构门逐条抛对应错误码`() {
        assertEquals("transfer_package_json_invalid", parseError("not json at all"))
        assertEquals("transfer_package_root_invalid", parseError("[]"))
        assertEquals(
            "transfer_package_type_invalid",
            parseError("""{"app":"other","packageType":"transfer"}"""),
        )
        assertEquals(
            "transfer_course_list_required",
            parseError("""{"app":"mikcb","packageType":"transfer","schemaVersion":1,"packageId":"p"}"""),
        )

        // 信封、版本、必填列表都在场，但某条课程缺必填字段 → 字段门报出来
        val missingName = MiniJson.encode(
            buildTransferPackageJson(
                packageId = "p1",
                scope = TransferScope.CURRENT_TIMETABLE,
                exportedAtIso = "2026-10-30T09:00:00.000",
                channel = TransferChannel.LAN,
                currentWeek = 7,
                settingsJson = TimetableSettings.defaults().toJson(),
                coursesJson = listOf(
                    linkedMapOf(
                        "id" to "c1", "teacher" to "", "location" to "", "dayOfWeek" to 1,
                        "startSection" to 1, "endSection" to 2, "startTime" to "08:00", "endTime" to "09:40",
                    ),
                ),
            ),
        )
        assertEquals("transfer_course_name_required", parseError(missingName))
    }

    // -----------------------------------------------------------------------
    // 反例二：版本不兼容
    // -----------------------------------------------------------------------

    @Test
    fun `版本不兼容 抛 transfer_package_schema_unsupported`() {
        assertEquals(
            "transfer_package_schema_unsupported",
            parseError("""{"app":"mikcb","packageType":"transfer","schemaVersion":9}"""),
        )
        // 字符串版本号同样不认（Dart `is! num` 口径）
        assertEquals(
            "transfer_package_schema_unsupported",
            parseError("""{"app":"mikcb","packageType":"transfer","schemaVersion":"1"}"""),
        )
    }

    // -----------------------------------------------------------------------
    // 反例三：空课表
    // -----------------------------------------------------------------------

    @Test
    fun `空包只降级成结构诊断 预览能出形状 应用时拒绝`() {
        // current_timetable 必须带 settings（`transfer_settings_required`），
        // 所以真正「什么载荷都没有」的包只能出现在不携带设置的作用域里。
        val json = packageJson(
            scope = TransferScope.SELECTED_COURSES,
            settings = null,
            currentWeek = null,
        )
        val incoming = LanTransferLogic.parseIncoming(json)
        assertEquals(listOf("transfer_package_empty"), incoming.diagnostics)

        val preview = LanTransferLogic.previewJson(incoming, LanTransferDiffSource())
        @Suppress("UNCHECKED_CAST")
        val merge = preview["mergeDiff"] as Map<String, Any?>
        assertEquals(0, merge["total"])
        assertEquals(8, (merge["summaries"] as List<*>).size)
    }

    @Test
    fun `当前课表包课程为空不算空包 与 Dart validate 只看载荷在场一致`() {
        val incoming = LanTransferLogic.parseIncoming(packageJson(courses = emptyList()))
        assertTrue("settings 在场就算有载荷：${incoming.diagnostics}", incoming.diagnostics.isEmpty())
        assertTrue(incoming.source.courses.isEmpty())
    }

    // -----------------------------------------------------------------------
    // 整设备写入 / profiles
    // -----------------------------------------------------------------------

    @Test
    fun `整份备份缺档案与 all_data 仍拒 分层矩阵里它们没有可恢复内容`() {
        // 两条都不带 profiles：full 缺档案（无可恢复内容）与 all_data 非 full
        // （bf09a7c3 的清表绕过形状）仍拒；full + profiles 的整份包已放行，
        // 见 LanTransferWholeRestoreTest。
        assertEquals(
            "use_profile_backup_not_full",
            parseError(packageJson(scope = TransferScope.ALL_DATA)),
        )
        assertEquals(
            "use_profile_backup_not_full",
            parseError(
                packageJson(
                    scope = TransferScope.ALL_DATA,
                    isFullBackup = true,
                ),
            ),
        )
    }

    @Test
    fun `带 profiles 的包明确拒 不静默丢档案`() {
        val other = TimetableProfile(
            id = "p2",
            name = "另一份课表",
            currentWeek = 1,
            createdAt = stamp,
            lastUsedAt = stamp,
        )
        assertEquals(
            "profile_backup_profiles_unsupported",
            parseError(packageJson(profiles = listOf(other))),
        )
    }

    // -----------------------------------------------------------------------
    // 颜色收窄（浏览器渲染面）
    // -----------------------------------------------------------------------

    @Test
    fun `课程颜色按 LAN 口径收窄 只留六位十六进制`() {
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor("#2196f3"))
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor("2196F3"))
        assertEquals("#AABBCC", LanTransferLogic.normalizeLanCourseColor("#aabbcc"))
        // 以下全部回落默认色（Dart `defaultLanCourseColor`）
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor("red"))
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor(null))
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor("#12345"))
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor("javascript:alert(1)"))
        assertEquals("#2196F3", LanTransferLogic.normalizeLanCourseColor("expression(alert(1))"))
    }

    @Test
    fun `解析时就把危险颜色换成默认色`() {
        val incoming = LanTransferLogic.parseIncoming(
            packageJson(courses = listOf(course("c1", "高数", color = "url(javascript:alert(1))"))),
        )
        assertEquals("#2196F3", incoming.source.courses.single().color)
    }

    // -----------------------------------------------------------------------
    // 差异分类
    // -----------------------------------------------------------------------

    @Test
    fun `差异 同 id 内容改 新增 删除 各归各类`() {
        val current = LanTransferDiffSource(
            courses = listOf(course("c1", "高数"), course("c3", "本地独有")),
            settings = TimetableSettings.defaults(),
        )
        val incoming = LanTransferDiffSource(
            courses = listOf(course("c1", "高数", teacher = "张"), course("c2", "新课")),
            settings = TimetableSettings.defaults(),
        )

        val merge = LanTransferLogic.compare(
            current, incoming, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.MERGE,
        )
        assertEquals(1, merge.forKind(LanTransferKind.COURSES).updatedCount)
        assertEquals(1, merge.forKind(LanTransferKind.COURSES).addedCount)
        assertEquals(0, merge.forKind(LanTransferKind.COURSES).removedCount)

        val overwrite = LanTransferLogic.compare(
            current, incoming, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.OVERWRITE,
        )
        assertEquals(1, overwrite.forKind(LanTransferKind.COURSES).removedCount)
        assertEquals(3, overwrite.forKind(LanTransferKind.COURSES).totalCount)

        // 局部作用域的「覆盖」= 合并语义（包边界外的本地数据不算删除）
        val scopedOverwrite = LanTransferLogic.compare(
            current, incoming, TransferScope.WEEK_TIMETABLE, TransferApplyMode.OVERWRITE,
        )
        assertEquals(0, scopedOverwrite.forKind(LanTransferKind.COURSES).removedCount)
    }

    @Test
    fun `变更条目带前后值 与 Dart TransferEntityChange 形状一致`() {
        val current = LanTransferDiffSource(courses = listOf(course("c1", "高数")))
        val incoming = LanTransferDiffSource(courses = listOf(course("c1", "高数", teacher = "张")))
        val diff = LanTransferLogic.compare(
            current, incoming, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.MERGE,
        )
        val change = diff.forKind(LanTransferKind.COURSES).changes.single()
        val json = change.toJson()
        assertEquals("updated", json["type"])
        assertEquals("c1", json["id"])
        assertEquals("updated: 高数 (c1)", json["description"])
        assertTrue(json.containsKey("before"))
        assertTrue(json.containsKey("after"))
        // 新增条目没有 before
        val added = LanTransferLogic.compare(
            LanTransferDiffSource(),
            LanTransferDiffSource(courses = listOf(course("c9", "新课"))),
            TransferScope.CURRENT_TIMETABLE,
            TransferApplyMode.MERGE,
        ).forKind(LanTransferKind.COURSES).changes.single().toJson()
        assertFalse(added.containsKey("before"))
        assertTrue(added.containsKey("after"))
    }

    @Test
    fun `设置差异只在携带设置的作用域出现 且只比已移植子集`() {
        val current = LanTransferDiffSource(settings = TimetableSettings.defaults())
        val changed = LanTransferDiffSource(
            settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
        )
        val same = LanTransferDiffSource(settings = TimetableSettings.defaults())

        val full = LanTransferLogic.compare(
            current, changed, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.MERGE,
        )
        assertEquals(1, full.forKind(LanTransferKind.SETTINGS).updatedCount)
        assertEquals(
            0,
            LanTransferLogic.compare(
                current, same, TransferScope.CURRENT_TIMETABLE, TransferApplyMode.MERGE,
            ).forKind(LanTransferKind.SETTINGS).totalCount,
        )
        // week_timetable 不携带设置 → 连这一类都不输出
        val scoped = LanTransferLogic.compare(
            current, changed, TransferScope.WEEK_TIMETABLE, TransferApplyMode.MERGE,
        )
        assertEquals(0, scoped.forKind(LanTransferKind.SETTINGS).totalCount)
    }

    @Test
    fun `规范化比对忽略键序 但不同值必须报出来`() {
        assertTrue(
            LanTransferLogic.sameJson(
                linkedMapOf("a" to 1, "b" to 2),
                linkedMapOf("b" to 2, "a" to 1),
            ),
        )
        assertTrue(
            LanTransferLogic.sameJson(
                linkedMapOf("nested" to linkedMapOf("x" to 1, "y" to listOf(1, 2))),
                linkedMapOf("nested" to linkedMapOf("y" to listOf(1, 2), "x" to 1)),
            ),
        )
        assertFalse(LanTransferLogic.sameJson(linkedMapOf("a" to 1), linkedMapOf("a" to 2)))
        assertFalse(
            LanTransferLogic.sameJson(
                linkedMapOf("list" to listOf(1, 2)),
                linkedMapOf("list" to listOf(2, 1)),
            ),
        )
    }

    // -----------------------------------------------------------------------
    // 本地引用校验
    // -----------------------------------------------------------------------

    @Test
    fun `引用校验按 Dart 顺序报第一个对不上的`() {
        val current = LanTransferDiffSource(
            courses = listOf(course("c1", "高数")),
            timeSchemes = listOf(scheme("s1", "默认模板")),
        )
        val incoming = LanTransferDiffSource(
            courses = listOf(course("c9", "新课").copy(timeSchemeIdOverride = "sX")),
            exams = listOf(exam("e1", "期中", "c_nope")),
            tasks = listOf(task("t1", "作业", "c_nope")),
            scheduleDateRules = listOf(rule("r1", "规则", "sX")),
            locationTimeGroups = listOf(group("g1", "教学楼", "sX")),
        )
        assertEquals(
            listOf(
                "exam_course_missing:e1",
                "task_course_missing:t1",
                "time_rule_scheme_missing:r1",
                "location_scheme_missing:g1",
                "course_scheme_missing:c9",
            ),
            LanTransferLogic.collectReferenceErrors(incoming, current),
        )
    }

    @Test
    fun `引用能落到本地已有课与模板上就不报`() {
        val current = LanTransferDiffSource(
            courses = listOf(course("c1", "高数")),
            timeSchemes = listOf(scheme("s1", "默认模板")),
        )
        val incoming = LanTransferDiffSource(
            courses = listOf(course("c2", "新课").copy(timeSchemeIdOverride = "s1")),
            exams = listOf(exam("e1", "期中", "c1")),
            tasks = listOf(task("t1", "作业", "c1")),
            scheduleDateRules = listOf(rule("r1", "规则", "s1")),
            locationTimeGroups = listOf(group("g1", "教学楼", "s1")),
        )
        assertTrue(LanTransferLogic.collectReferenceErrors(incoming, current).isEmpty())
    }

    // -----------------------------------------------------------------------
    // 模板合并计划 / 引用改写 / 按 id 合并
    // -----------------------------------------------------------------------

    @Test
    fun `模板合并计划 同 id 更新 同签名复用 新签名创建 同批同签名走别名`() {
        val sectionsA = listOf(SectionTime("08:00", "08:45"))
        val sectionsB = listOf(SectionTime("09:00", "09:45"))
        val steps = LanTransferLogic.planTimeSchemes(
            local = listOf(scheme("s1", "本地名", sectionsA)),
            incoming = listOf(
                scheme("s1", "外来名", sectionsA),
                scheme("s2", "外来二", sectionsA),
                scheme("s3", "外来三", sectionsB),
                scheme("s4", "外来四", sectionsB),
            ),
        )
        assertEquals(
            listOf(
                LanTimeSchemeStep.Update("s1", "外来名", sectionsA),
                LanTimeSchemeStep.Reuse("s2", "s1"),
                LanTimeSchemeStep.Create("s3", "外来三", sectionsB),
                LanTimeSchemeStep.Alias("s4", "s3"),
            ),
            steps,
        )
    }

    @Test
    fun `模板引用按映射改写 命中的才改`() {
        val map = mapOf("s_remote" to "s_local_new")
        assertEquals(
            "s_local_new",
            LanTransferLogic.remapCourseSchemes(
                listOf(course("c1", "高数").copy(timeSchemeIdOverride = "s_remote")), map,
            ).single().timeSchemeIdOverride,
        )
        assertNull(LanTransferLogic.remapCourseSchemes(listOf(course("c1", "高数")), map).single().timeSchemeIdOverride)
        assertEquals("s_local_new", LanTransferLogic.remapScheduleDateRules(listOf(rule("r1", "n", "s_remote")), map).single().timeSchemeId)
        assertEquals("s_local_new", LanTransferLogic.remapLocationTimeGroups(listOf(group("g1", "n", "s_remote")), map).single().timeSchemeId)
        assertEquals(
            "s_local_new",
            LanTransferLogic.remapSettingsScheme(
                TimetableSettings.defaults().copy(activeTimeSchemeId = "s_remote"), map,
            ).activeTimeSchemeId,
        )
        assertEquals(
            "keep",
            LanTransferLogic.remapSettingsScheme(
                TimetableSettings.defaults().copy(activeTimeSchemeId = "keep"), map,
            ).activeTimeSchemeId,
        )
    }

    @Test
    fun `按 id 合并 本地顺序保序 同 id 用外来值 新 id 追加在后`() {
        val merged = LanTransferLogic.mergeById(
            listOf(course("c1", "本地旧名"), course("c2", "本地二")),
            listOf(course("c2", "外来二"), course("c3", "外来三")),
        ) { it.id }
        assertEquals(listOf("c1", "c2", "c3"), merged.map { it.id })
        assertEquals("本地旧名", merged[0].name)
        assertEquals("外来二", merged[1].name)
        assertEquals("外来三", merged[2].name)
    }

    // -----------------------------------------------------------------------
    // 协议形状
    // -----------------------------------------------------------------------

    @Test
    fun `预览形状与 Dart LanTransferPreview 一致 且 channel 强制 lan`() {
        val incoming = LanTransferLogic.parseIncoming(
            packageJson(channel = TransferChannel.FILE, courses = listOf(course("c1", "高数"))),
        )
        val preview = LanTransferLogic.previewJson(incoming, LanTransferDiffSource())
        // wholeRestore 是 Kotlin 侧新增的标记位（网页端据此禁用合并按钮）；
        // 其余六键与 Dart `LanTransferPreview.toJson()` 逐字同形。
        assertEquals(
            listOf("transferId", "channel", "scope", "mergeDiff", "overwriteDiff", "diff", "wholeRestore"),
            preview.keys.toList(),
        )
        assertEquals("transfer-test-1", preview["transferId"])
        assertEquals("lan", preview["channel"])
        assertEquals("current_timetable", preview["scope"])
        assertEquals(false, preview["wholeRestore"])

        @Suppress("UNCHECKED_CAST")
        val merge = preview["mergeDiff"] as Map<String, Any?>
        assertEquals(
            listOf("mode", "added", "updated", "removed", "total", "summaries"),
            merge.keys.toList(),
        )
        assertEquals("merge", merge["mode"])
        assertEquals(1, merge["added"])
        assertEquals(preview["overwriteDiff"], preview["diff"])
        val summaries = merge["summaries"] as List<*>
        assertEquals(8, summaries.size)
        @Suppress("UNCHECKED_CAST")
        val coursesSummary = summaries.first() as Map<String, Any?>
        assertEquals("courses", coursesSummary["kind"])
    }

    @Test
    fun `应用结果形状与 Dart 一致 applied mode transferId diff error`() {
        val diff = LanTransferLogic.compare(
            LanTransferDiffSource(),
            LanTransferDiffSource(),
            TransferScope.CURRENT_TIMETABLE,
            TransferApplyMode.MERGE,
        )
        val ok = LanTransferLogic.applyResultJson(true, TransferApplyMode.MERGE, diff, null)
        assertEquals(listOf("applied", "mode", "transferId", "diff"), ok.keys.toList())
        assertEquals(true, ok["applied"])
        assertEquals("merge", ok["mode"])
        assertNull(ok["transferId"])

        val failed = LanTransferLogic.applyResultJson(false, TransferApplyMode.OVERWRITE, diff, "transfer_package_empty")
        assertEquals(false, failed["applied"])
        assertEquals("overwrite", failed["mode"])
        assertEquals("transfer_package_empty", failed["error"])
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun parseError(content: String): String {
        val error = try {
            LanTransferLogic.parseIncoming(content)
            null
        } catch (e: FormatException) {
            e
        }
        assertTrue("这份内容必须被拒：${content.take(120)}", error != null)
        return error!!.message.orEmpty()
    }

    private fun packageJson(
        scope: TransferScope = TransferScope.CURRENT_TIMETABLE,
        packageId: String = "transfer-test-1",
        channel: TransferChannel = TransferChannel.LAN,
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
        rules: List<ScheduleDateRule> = emptyList(),
        groups: List<LocationTimeGroup> = emptyList(),
        settings: TimetableSettings? = TimetableSettings.defaults(),
        currentWeek: Int? = 7,
        profiles: List<TimetableProfile> = emptyList(),
        isFullBackup: Boolean = false,
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = packageId,
            scope = scope,
            exportedAtIso = "2026-10-30T09:00:00.000",
            channel = channel,
            currentWeek = currentWeek,
            settingsJson = settings?.toJson(),
            coursesJson = courses.map { it.toJson() },
            tasksJson = tasks.map { it.toJson() },
            examsJson = exams.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
            scheduleDateRulesJson = rules.map { it.toJson() },
            locationTimeGroupsJson = groups.map { it.toJsonMap() },
            profilesJson = profiles.map { it.toJson() },
            isFullBackup = isFullBackup,
        ),
    )

    private fun course(
        id: String,
        name: String,
        teacher: String = "",
        color: String = "#2196F3",
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
    )

    private fun task(id: String, title: String, courseId: String? = null): CourseTask = CourseTask(
        id = id,
        title = title,
        courseId = courseId,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private fun exam(id: String, name: String, courseId: String): Exam = Exam(
        id = id,
        courseId = courseId,
        name = name,
        dateTime = LocalDateTime.of(2026, 11, 1, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = stamp,
        updatedAt = stamp,
    )

    private fun scheme(
        id: String,
        name: String,
        sections: List<SectionTime> = listOf(SectionTime("08:00", "08:45")),
    ): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private fun rule(id: String, name: String, schemeId: String): ScheduleDateRule = ScheduleDateRule(
        id = id,
        name = name,
        timeSchemeId = schemeId,
        startDate = "2026-09-01",
        endDate = "2026-09-07",
    )

    private fun group(id: String, name: String, schemeId: String): LocationTimeGroup = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = schemeId,
    )
}
