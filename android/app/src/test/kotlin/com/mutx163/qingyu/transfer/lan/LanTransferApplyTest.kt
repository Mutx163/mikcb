package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
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
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 局域网 `import/preview` + `import/apply` 的**真数据层** L0 测试（批次 F17）。
 *
 * 全程不 mock 存储：内存 KV → `TimetableStore` → `TimetableRepository` → `LanTransferApplier`。
 * 断言落在两处：仓储对外视图 + **盘上的原始字节**（`InMemoryKeyValueStore.rawSnapshot()`）。
 * 后者是「先校验后落盘 / 失败回滚」的唯一硬证据——只断言「抛了异常」证明不了没写坏。
 */
class LanTransferApplyTest {

    // -----------------------------------------------------------------------
    // 预览 / 应用的基本契约
    // -----------------------------------------------------------------------

    @Test
    fun `预览不写盘 应用才写盘`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep", "原有课程"))
        val before = store.rawSnapshot()
        val host = LanEditRepositoryHost(repository)

        val preview = host.previewTransferJson(packageJson(courses = listOf(course("c9", "外来课程"))))
        assertNotNull(preview)
        assertEquals("transfer-test-1", preview!!["transferId"])
        assertEquals("预览不许动盘", before, store.rawSnapshot())

        val applied = host.applyTransferJson(
            packageJson(courses = listOf(course("c9", "外来课程"))),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        assertTrue(store.rawSnapshot().values.joinToString("\n").contains("外来课程"))
    }

    @Test
    fun `应用结果与 Dart 形状一致 mode transferId diff applied`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("c1", "高等数学"))
        val host = LanEditRepositoryHost(repository)
        val content = packageJson(courses = listOf(course("c1", "高等数学", teacher = "张")))

        val applied = host.applyTransferJson(content, TransferApplyMode.MERGE)
        assertEquals(true, applied["applied"])
        assertEquals("merge", applied["mode"])
        assertEquals("撤销点尚未移植：transferId 必须是 null 而不是编一个", null, applied["transferId"])

        @Suppress("UNCHECKED_CAST")
        val diff = applied["diff"] as Map<String, Any?>
        assertEquals("merge", diff["mode"])
        assertEquals(1, diff["updated"])
        assertEquals(0, diff["removed"])
        assertTrue("diff 必须带 8 类 summaries", (diff["summaries"] as List<*>).size == 8)
    }

    @Test
    fun `合并应用 同 id 更新与新增都真的落到盘上`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("c1", "高等数学"))
        repository.addCourse(course("c2", "大学物理"))
        val host = LanEditRepositoryHost(repository)

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(
                    course("c1", "高等数学", teacher = "张"),
                    course("c3", "新开课程"),
                ),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        assertEquals(
            setOf("c1", "c2", "c3"),
            repository.courses.map { it.id }.toSet(),
        )
        assertEquals("同 id 的教师按外来值更新", "张", repository.getCourseById("c1")?.teacher)
        assertEquals("本地独有的课在合并里不许丢", "大学物理", repository.getCourseById("c2")?.name)
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertTrue("盘上要有新开的课", raw.contains("新开课程"))
        assertTrue("盘上要写着改过的教师", raw.contains("张"))
    }

    @Test
    fun `覆盖应用 本地独有的课真的被删掉 盘上也删掉`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("c1", "高等数学"))
        repository.addCourse(course("c2", "大学物理"))
        val host = LanEditRepositoryHost(repository)

        val applied = host.applyTransferJson(
            packageJson(courses = listOf(course("c1", "高等数学"))),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        assertEquals("overwrite", applied["mode"])
        assertEquals(listOf("c1"), repository.courses.map { it.id })

        @Suppress("UNCHECKED_CAST")
        val diff = applied["diff"] as Map<String, Any?>
        assertEquals(1, diff["removed"])
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertFalse("盘上不许再留着被删掉的课", raw.contains("大学物理"))
    }

    @Test
    fun `局部作用域的覆盖走合并语义 本地课不丢`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("c1", "高等数学"))
        repository.addCourse(course("c2", "大学物理"))
        val host = LanEditRepositoryHost(repository)

        val applied = host.applyTransferJson(
            packageJson(
                scope = TransferScope.WEEK_TIMETABLE,
                settings = null,
                courses = listOf(course("c3", "本周加课")),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        assertEquals(setOf("c1", "c2", "c3"), repository.courses.map { it.id }.toSet())
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertTrue(raw.contains("本周加课"))
        assertTrue("包边界外的本地课必须原样在盘上", raw.contains("大学物理"))
    }

    // -----------------------------------------------------------------------
    // 先校验后落盘
    // -----------------------------------------------------------------------

    @Test
    fun `引用对不上时拒绝 盘上一字未变`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("c1", "高等数学"))
        val before = store.rawSnapshot()
        val host = LanEditRepositoryHost(repository)

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c_new", "外来新科")),
                exams = listOf(exam("e1", "期中", "c_missing")),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(false, applied["applied"])
        assertEquals("exam_course_missing:e1", applied["error"])
        assertEquals("被拒的导入不许动课", listOf("c1"), repository.courses.map { it.id })
        assertEquals("被拒的导入盘上一字未变", before, store.rawSnapshot())
    }

    @Test
    fun `空课表包被拒 盘上一字未变`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("c1", "高等数学"))
        val before = store.rawSnapshot()
        val host = LanEditRepositoryHost(repository)
        val content = packageJson(
            scope = TransferScope.SELECTED_COURSES,
            settings = null,
            currentWeek = null,
        )

        assertNotNull("空包仍能预览（Dart 同口径）", host.previewTransferJson(content))
        val applied = host.applyTransferJson(content, TransferApplyMode.MERGE)
        assertEquals(false, applied["applied"])
        assertEquals("transfer_package_empty", applied["error"])
        assertEquals(before, store.rawSnapshot())
    }

    @Test
    fun `整份备份走真 host 被拒 路由层能折成 400`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val before = store.rawSnapshot()
        val host = LanEditRepositoryHost(repository)

        val error = try {
            host.applyTransferJson(
                packageJson(scope = TransferScope.ALL_DATA, isFullBackup = true),
                TransferApplyMode.OVERWRITE,
            )
            null
        } catch (e: com.mutx163.qingyu.core.FormatException) {
            e
        }
        assertEquals("use_profile_backup_not_full", error?.message)
        assertEquals(before, store.rawSnapshot())
    }

    // -----------------------------------------------------------------------
    // 写盘失败 → 尽力补偿
    // -----------------------------------------------------------------------

    @Test
    fun `写设置失败时尽力补偿 课回到原样且盘上一字未变`() {
        val backing = InMemoryKeyValueStore()
        val failing = FailingKeyValueStore(backing, failOnKeyContaining = "settings")
        val repository = repositoryOn(failing)
        repository.addCourse(course("c1", "高等数学"))
        val before = backing.rawSnapshot()
        val host = LanEditRepositoryHost(repository)

        // 设置里的周数改成 18，好让「写设置」这一步真的发生并失败
        failing.enabled = true
        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c1", "高等数学"), course("c9", "外来课程")),
                settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
            ),
            TransferApplyMode.MERGE,
        )
        failing.enabled = false

        assertEquals(false, applied["applied"])
        assertEquals("transfer_import_failed", applied["error"])
        assertEquals(
            "补偿要把课程恢复成导入前那一条",
            listOf("c1"),
            repository.courses.map { it.id },
        )
        assertEquals("内存里的设置也要回到旧值", 20, repository.snapshot.settings.semesterWeekCount)
        assertEquals("盘上必须和导入前一模一样", before, backing.rawSnapshot())
    }

    // -----------------------------------------------------------------------
    // 时间模板：创建 + 引用改写 / 同 id 更新
    // -----------------------------------------------------------------------

    @Test
    fun `新签名模板会被创建 并把课程引用改写到本地新 id`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val localScheme = repository.createTimeScheme("本地模板", listOf(SectionTime("08:00", "08:45")))
        val host = LanEditRepositoryHost(repository)

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c_new", "外来课程").copy(timeSchemeIdOverride = "s_remote")),
                timeSchemes = listOf(scheme("s_remote", "外来模板", sectionsB)),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])

        val schemes = repository.snapshot.timeSchemes
        assertEquals(2, schemes.size)
        val created = schemes.first { it.id != localScheme.id }
        assertEquals("外来模板", created.name)
        assertEquals(sectionsB, created.sections)

        val course = repository.courses.single { it.id == "c_new" }
        assertNotEquals("外来模板 id 必须被改写成本地新 id", "s_remote", course.timeSchemeIdOverride)
        assertEquals(created.id, course.timeSchemeIdOverride)
    }

    @Test
    fun `同 id 模板按外来名字与节次更新`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val localScheme = repository.createTimeScheme("本地模板", listOf(SectionTime("08:00", "08:45")))
        val host = LanEditRepositoryHost(repository)

        val applied = host.applyTransferJson(
            packageJson(
                timeSchemes = listOf(scheme(localScheme.id, "外来改名", sectionsB)),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        val updated = repository.snapshot.timeSchemes.single { it.id == localScheme.id }
        assertEquals("外来改名", updated.name)
        assertEquals(sectionsB, updated.sections)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    /** 在指定 key 上抛错的存储替身：用来证明「写盘失败时应用真的补回来了」。 */
    private class FailingKeyValueStore(
        private val delegate: KeyValueStore,
        private val failOnKeyContaining: String,
    ) : KeyValueStore by delegate {

        var enabled: Boolean = false

        override fun putString(key: String, value: String) {
            if (enabled && key.contains(failOnKeyContaining)) {
                throw IllegalStateException("store_write_failed:$key")
            }
            delegate.putString(key, value)
        }
    }

    private fun repositoryOn(store: KeyValueStore): TimetableRepository {
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    currentWeek = 7,
                    createdAt = stamp,
                    lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(7)
        return TimetableRepository(timetableStore)
    }

    private fun packageJson(
        scope: TransferScope = TransferScope.CURRENT_TIMETABLE,
        courses: List<Course> = emptyList(),
        tasks: List<CourseTask> = emptyList(),
        exams: List<Exam> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
        rules: List<ScheduleDateRule> = emptyList(),
        groups: List<LocationTimeGroup> = emptyList(),
        settings: TimetableSettings? = TimetableSettings.defaults(),
        currentWeek: Int? = 7,
        isFullBackup: Boolean = false,
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-test-1",
            scope = scope,
            exportedAtIso = "2026-10-30T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = currentWeek,
            settingsJson = settings?.toJson(),
            coursesJson = courses.map { it.toJson() },
            tasksJson = tasks.map { it.toJson() },
            examsJson = exams.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
            scheduleDateRulesJson = rules.map { it.toJson() },
            locationTimeGroupsJson = groups.map { it.toJsonMap() },
            isFullBackup = isFullBackup,
        ),
    )

    private fun course(
        id: String,
        name: String,
        teacher: String = "",
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

    private fun scheme(id: String, name: String, sections: List<SectionTime>): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private companion object {
        val stamp: LocalDateTime = LocalDateTime.of(2026, 10, 30, 9, 0)

        /** 四节：够 fixtures 里的课（1~2 节）落进去，避免「节次不足」的额外噪声。 */
        val sectionsB: List<SectionTime> = listOf(
            SectionTime("09:00", "09:45"),
            SectionTime("09:55", "10:40"),
            SectionTime("10:50", "11:35"),
            SectionTime("11:45", "12:30"),
        )
    }
}
