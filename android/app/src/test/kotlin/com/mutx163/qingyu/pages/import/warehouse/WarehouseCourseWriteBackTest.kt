package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * F32：脚本抓回的课程写回当前档案。
 *
 * 钉住三件事：
 * 1. 替换 / 合并语义显式且不会误删用户已有课表；
 * 2. 空列表**不写盘**（否则等于一键清空）；
 * 3. 落盘失败时内存保持旧课表、监听者不被通知（仓储「成功才通知」语义）。
 */
class WarehouseCourseWriteBackTest {

    private fun course(
        id: String,
        name: String = "课程$id",
        day: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        weeks: List<Int> = listOf(1, 2),
        startTime: String = "",
        endTime: String = "",
        hasCustomTime: Boolean = false,
    ) = Course(
        id = id,
        name = name,
        teacher = "教师",
        location = "教室",
        dayOfWeek = day,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        hasCustomTime = hasCustomTime,
        customWeeks = weeks,
    )

    private fun profileWith(
        courses: List<Course>,
        settings: TimetableSettings = TimetableSettings.defaults(),
    ): TimetableProfile = TimetableProfile(
        id = "p1",
        name = "默认课表",
        courses = courses,
        settings = settings,
        currentWeek = 1,
        createdAt = LocalDateTime.of(2026, 9, 1, 0, 0),
        lastUsedAt = LocalDateTime.of(2026, 9, 1, 0, 0),
    )

    private fun repositoryWith(courses: List<Course> = emptyList()): TimetableRepository {
        val raw = InMemoryKeyValueStore(
            if (courses.isEmpty()) {
                emptyMap()
            } else {
                mapOf("timetable_profiles" to MiniJson.encode(listOf(profileWith(courses).toJson())))
            },
        )
        return TimetableRepository(TimetableStore(raw))
    }

    /**
     * 指定 key 的写入失败。
     *
     * [failOnMatch] = -1：每次命中都失败；正数 N：**第 N 次**命中才失败。
     * 设置单一真源后 settings 与 courses 都写在 `timetable_profiles` 里，
     * 「设置已落盘、课程落盘失败、回滚」只能靠计数区分第几次写。
     */
    private class FailingWriteStore(
        private val delegate: InMemoryKeyValueStore,
        private val failKey: String,
        private val failOnMatch: Int = -1,
    ) : KeyValueStore by delegate {
        private var matchCount = 0

        override fun putString(key: String, value: String) {
            if (key == failKey) {
                matchCount += 1
                if (failOnMatch < 0 || matchCount == failOnMatch) {
                    throw IllegalStateException("disk_full")
                }
            }
            delegate.putString(key, value)
        }
    }

    /** 只有两节课的作息：用来钉「节次不够时补齐」。 */
    private fun twoSections() = listOf(
        SectionTime(startTime = "08:00", endTime = "08:45"),
        SectionTime(startTime = "08:55", endTime = "09:40"),
    )

    /** 指定节次表的仓储（设置里没有主模板，补节应直接写设置）。 */
    private fun repositoryWithSections(
        sections: List<SectionTime>,
        courses: List<Course> = emptyList(),
        store: (InMemoryKeyValueStore) -> KeyValueStore = { it },
    ): TimetableRepository {
        // 设置单一真源在档案内嵌 `settings`（`TimetableStore.loadSettings`）；顶层
        // `timetable_settings` 在有档案时只是旧世界镜像，读侧不再走它。
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_profiles" to MiniJson.encode(
                    listOf(
                        profileWith(
                            courses,
                            TimetableSettings.defaults().copy(sections = sections),
                        ).toJson(),
                    ),
                ),
            ),
        )
        return TimetableRepository(TimetableStore(store(raw)))
    }

    // ── 策略 ──────────────────────────────────────────────────────────

    @Test
    fun `空档案默认替换 已有课默认合并`() {
        assertEquals(WarehouseCourseWriteBack.Mode.REPLACE, WarehouseCourseWriteBack.resolveMode(0))
        assertEquals(WarehouseCourseWriteBack.Mode.MERGE, WarehouseCourseWriteBack.resolveMode(3))
        assertEquals(
            "调用方显式指定时以调用方为准",
            WarehouseCourseWriteBack.Mode.REPLACE,
            WarehouseCourseWriteBack.resolveMode(3, WarehouseCourseWriteBack.Mode.REPLACE),
        )
    }

    // ── 写回 ──────────────────────────────────────────────────────────

    @Test
    fun `空课表导入直接写入当前档案`() {
        val repository = repositoryWith()
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", name = "数学"), course("c2", name = "英语")),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        val outcome = (result as WarehouseCourseWriteBack.Result.Done).outcome
        assertEquals(WarehouseCourseWriteBack.Mode.REPLACE, outcome.mode)
        assertEquals(2, outcome.importedCount)
        assertEquals(listOf("数学", "英语"), repository.snapshot.courses.map { it.name })
    }

    @Test
    fun `导入的非自定义时间课程按生效作息回填上课时间`() {
        // 脚本只给节次（startSection=1,endSection=2）、没给 isCustomTime。
        // Dart `importParsedCourses` 在落库前按生效模板回填 startTime/endTime；
        // 少了这一步，首页课卡只剩节次、上课时间是空的（2026-11-07 用户实报）。
        val repository = repositoryWithSections(twoSections())
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", name = "数学", startSection = 1, endSection = 2)),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        val written = repository.snapshot.courses.single()
        assertEquals("模板第 1 节开始", "08:00", written.startTime)
        assertEquals("模板第 2 节结束", "09:40", written.endTime)
        assertFalse("模板回填不等于用户自定义时间", written.hasCustomTime)
    }

    @Test
    fun `脚本给的自定义时间不被模板覆盖`() {
        val repository = repositoryWithSections(twoSections())
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(
                course(
                    "c1",
                    name = "早读",
                    startSection = 1,
                    endSection = 1,
                    startTime = "07:30",
                    endTime = "07:45",
                    hasCustomTime = true,
                ),
            ),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        val written = repository.snapshot.courses.single()
        assertEquals("07:30", written.startTime)
        assertEquals("07:45", written.endTime)
        assertTrue(written.hasCustomTime)
    }

    @Test
    fun `存量空时间课表重导入时也要补回上课时间`() {
        // 升级前用旧代码导入的课：startTime/endTime 为空。再导入同一份课表时
        // mergedCourses 与 before 完全相同（importedCount=0），但 sync 必须仍然执行
        // 并把时间补回去——否则存量坏数据永远自愈不了。
        val broken = course("c1", name = "数学", startSection = 1, endSection = 2)
        val repository = repositoryWithSections(twoSections(), courses = listOf(broken))
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(broken.copy(id = "imported-id")),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        val written = repository.snapshot.courses.single()
        assertEquals("08:00", written.startTime)
        assertEquals("09:40", written.endTime)
    }

    @Test
    fun `已有课表默认合并 原有课程一条不少`() {
        val repository = repositoryWith(listOf(course("old", name = "旧课")))
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("new", name = "新课", day = 3)),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        assertEquals(WarehouseCourseWriteBack.Mode.MERGE, (result as WarehouseCourseWriteBack.Result.Done).outcome.mode)
        assertEquals(listOf("旧课", "新课"), repository.snapshot.courses.map { it.name })
    }

    @Test
    fun `显式替换会只留脚本课程`() {
        val repository = repositoryWith(listOf(course("old", name = "旧课")))
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("new", name = "新课", day = 3)),
            requestedMode = WarehouseCourseWriteBack.Mode.REPLACE,
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        assertEquals(listOf("新课"), repository.snapshot.courses.map { it.name })
    }

    @Test
    fun `空课程列表不写盘也不清空已有课表`() {
        val repository = repositoryWith(listOf(course("old", name = "旧课")))
        val seen = mutableListOf<Any>()
        repository.observe { seen.add(it) }

        val result = WarehouseCourseWriteBack.apply(repository, emptyList(), droppedCount = 3)

        assertTrue(result is WarehouseCourseWriteBack.Result.NoImportableCourses)
        assertEquals(3, (result as WarehouseCourseWriteBack.Result.NoImportableCourses).droppedCount)
        assertEquals(listOf("旧课"), repository.snapshot.courses.map { it.name })
        assertTrue("没写盘就不该通知", seen.isEmpty())
    }

    @Test
    fun `合并后课程一字不差时按0条上报且不写盘`() {
        // 用「自定义时间」的课做基线：模板回填会跳过它，合并后确实一字不差。
        // （普通课若 startTime 为空，回填本身就是一次真实变化，不能再报 0——
        //   那条路径由 `存量空时间课表重导入时也要补回上课时间` 覆盖。）
        val existing = course(
            "c1",
            name = "数学",
            day = 2,
            weeks = listOf(1, 2),
            startTime = "08:00",
            endTime = "09:40",
            hasCustomTime = true,
        )
        val repository = repositoryWith(listOf(existing))
        val seen = mutableListOf<Any>()
        repository.observe { seen.add(it) }

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(existing.copy(id = "imported-id")),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        val outcome = (result as WarehouseCourseWriteBack.Result.Done).outcome
        assertEquals(WarehouseCourseWriteBack.Mode.MERGE, outcome.mode)
        assertEquals("只更新不新增", 1, repository.snapshot.courses.size)
        // Dart `effectiveImportedCount`：合并没有实际变化就是 0，不能谎报「更新了 1 门」。
        assertEquals("没有实际变化", 0, outcome.importedCount)
        assertTrue("没有实际变化就不该写盘通知", seen.isEmpty())
    }

    @Test
    fun `导入周次超过学期总周数时抬高学期周数`() {
        val repository = repositoryWith()
        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", weeks = (1..25).toList())),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        // Dart `importParsedCourses`：按合并后最大周次抬高 semesterWeekCount，否则第 21-25 周点不出来。
        assertEquals(25, repository.snapshot.settings.semesterWeekCount)
        assertEquals(listOf(1, 2), repository.snapshot.courses.single().customWeeks?.take(2))
    }

    @Test
    fun `导入只会抬高学期周数 不会把用户设的周数压回去`() {
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_profiles" to MiniJson.encode(
                    listOf(
                        profileWith(
                            emptyList(),
                            TimetableSettings.defaults().copy(semesterWeekCount = 30),
                        ).toJson(),
                    ),
                ),
            ),
        )
        val repository = TimetableRepository(TimetableStore(raw))

        WarehouseCourseWriteBack.apply(repository, listOf(course("c1", weeks = listOf(1, 2, 3))))

        assertEquals("只升不降", 30, repository.snapshot.settings.semesterWeekCount)
    }

    @Test
    fun `学期总周数封顶 30 周 第 31 周不再抬高`() {
        val repository = repositoryWith()
        WarehouseCourseWriteBack.apply(repository, listOf(course("c1", weeks = (1..31).toList()))
        )
        // Dart `maxAllowedSemesterWeekCount = 30`（import_export_logic.dart:39），
        // 归一化时 31 已被剔除，最后一周 = 30（不是 42）。
        assertEquals(30, repository.snapshot.settings.semesterWeekCount)
    }

    @Test
    fun `自定义周次乱序也按归一化最大值抬升`() {
        val repository = repositoryWith()
        WarehouseCourseWriteBack.apply(repository, listOf(course("c1", weeks = listOf(21, 1, 3)))
        )
        // Dart `maxCourseWeek` 取 `normalizedCustomWeeks.last`（升序去重后的末项），
        // 不是原始 `customWeeks.lastOrNull()`——乱序时旧实现会误抬到 3。
        assertEquals(21, repository.snapshot.settings.semesterWeekCount)
    }

    @Test
    fun `确认开学日后按今天重算当前周`() {
        val start = LocalDateTime.now().minusDays(14)
        val repository = repositoryWith(listOf(course("c1", weeks = (1..20).toList())))

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", weeks = (1..20).toList())),
            semesterStartDate = start,
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        val expected = WeekCalculator.weekForDate(
            date = LocalDateTime.now(),
            semesterStart = start,
            semesterWeekCount = repository.snapshot.settings.semesterWeekCount,
            fallback = 1,
        )
        // Dart 换了开学日会 `calculateWeekForDate(now)` 重算当前周，不能留旧周次。
        assertEquals(expected, repository.snapshot.currentWeek)
    }

    @Test
    fun `落盘失败时返回失败 且内存课表保持原样`() {
        val raw = InMemoryKeyValueStore(
            mapOf("timetable_profiles" to MiniJson.encode(listOf(profileWith(listOf(course("old", name = "旧课"))).toJson()))),
        )
        val repository = TimetableRepository(TimetableStore(FailingWriteStore(raw, "timetable_profiles")))
        val seen = mutableListOf<Any>()
        repository.observe { seen.add(it) }

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("new", name = "新课", day = 5)),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Failed)
        assertEquals("落盘失败不许改内存", listOf("旧课"), repository.snapshot.courses.map { it.name })
        assertTrue("落盘失败不许通知", seen.isEmpty())
    }

    @Test
    fun `写成功后重建仓储能从盘上读回新课`() {
        val raw = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(raw))

        WarehouseCourseWriteBack.apply(repository, listOf(course("c1", name = "持久化课")))

        val reloaded = TimetableRepository(TimetableStore(raw))
        assertEquals(listOf("持久化课"), reloaded.snapshot.courses.map { it.name })
    }

    // ── 节次容量（Dart `ensureImportSectionCapacity`） ──────────────────

    @Test
    fun `节次不够时补齐到最终课表所需节次`() {
        val repository = repositoryWithSections(twoSections())

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", startSection = 1, endSection = 5, weeks = listOf(1, 2, 3))),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        // Dart：容量确认后先补节次表再写课程，否则第 5 节的课落盘了却读不到时间。
        assertEquals(5, repository.snapshot.settings.sections.size)
        assertEquals(5, repository.snapshot.courses.single().endSection)
    }

    @Test
    fun `节次够用时不做任何补节`() {
        val eight = (1..8).map { index ->
            SectionTime(
                startTime = String.format(java.util.Locale.ROOT, "%02d:00", 7 + index),
                endTime = String.format(java.util.Locale.ROOT, "%02d:45", 7 + index),
            )
        }
        val repository = repositoryWithSections(eight)

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", startSection = 1, endSection = 3)),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        assertEquals("够用就不该动用户的作息", eight, repository.snapshot.settings.sections)
    }

    @Test
    fun `课程落盘失败时回滚已补齐的节次`() {
        val repository = repositoryWithSections(
            twoSections(),
            store = { raw -> FailingWriteStore(raw, "timetable_profiles") },
        )

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("c1", startSection = 1, endSection = 5)),
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Failed)
        // 「课没进、作息却变了」是最难解释的状态：补节必须随课程落盘失败一起退回去。
        assertEquals(twoSections(), repository.snapshot.settings.sections)
    }

    // ── 载荷整链 ──────────────────────────────────────────────────────

    @Test
    fun `载荷不是 JSON 数组时报格式错误`() {
        val repository = repositoryWith()
        val result = WarehouseCourseWriteBack.applyPayload(
            repository = repository,
            payload = """{"name":"不是数组"}""",
            unknownTeacher = "未知教师",
            unknownLocation = "未知地点",
            idFactory = { "id" },
        )

        assertTrue(result is WarehouseCourseWriteBack.PayloadResult.InvalidFormat)
    }

    @Test
    fun `合法载荷解析后写回 并统计丢弃记录`() {
        val repository = repositoryWith()
        val payload = MiniJson.encode(
            listOf(
                mapOf(
                    "name" to "高数",
                    "day" to 1,
                    "startSection" to 1,
                    "endSection" to 2,
                    "weeks" to listOf(1, 2),
                ),
                mapOf("name" to "坏记录", "day" to 0, "weeks" to listOf(1)),
            ),
        )

        val result = WarehouseCourseWriteBack.applyPayload(
            repository = repository,
            payload = payload,
            unknownTeacher = "未知教师",
            unknownLocation = "未知地点",
            idFactory = { "id-1" },
        )

        assertTrue(result is WarehouseCourseWriteBack.PayloadResult.Done)
        val done = result as WarehouseCourseWriteBack.PayloadResult.Done
        assertEquals(1, done.outcome.importedCount)
        assertEquals(1, done.outcome.droppedCount)
        assertEquals(2, done.receivedCount)
        assertEquals(listOf("高数"), repository.snapshot.courses.map { it.name })
    }

    // ── 与 Dart `importParsedCourses` 对拍 ──────────────────────────────

    @Test
    fun `导入确认的开学日即使课程没有变化也会落盘`() {
        val start = LocalDateTime.of(2026, 9, 7, 0, 0)
        val existing = course("c1", name = "数学", day = 2, weeks = listOf(1, 2))
        val repository = repositoryWith(listOf(existing))

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(existing.copy(id = "imported-id")),
            semesterStartDate = start,
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        // Dart：`importParsedCourses` 在合并结果没变化时也不会提前 return，
        // 因为开学日是这次导入要落盘的产物。
        assertEquals(start, repository.snapshot.settings.semesterStartDate)
    }

    @Test
    fun `覆盖导入先去重 计数按去重后的条数`() {
        val repository = repositoryWith(listOf(course("old", name = "旧课")))
        val duplicate = course("new", name = "新课", day = 3)

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(duplicate, duplicate.copy()),
            requestedMode = WarehouseCourseWriteBack.Mode.REPLACE,
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Done)
        assertEquals(1, (result as WarehouseCourseWriteBack.Result.Done).outcome.importedCount)
        assertEquals(listOf("新课"), repository.snapshot.courses.map { it.name })
    }

    @Test
    fun `课程落盘失败时回滚已写入的开学日`() {
        val oldStart = LocalDateTime.of(2026, 2, 23, 0, 0)
        val newStart = LocalDateTime.of(2026, 9, 7, 0, 0)
        val profile = profileWith(
            listOf(course("old", name = "旧课")),
            TimetableSettings.defaults().copy(semesterStartDate = oldStart),
        )
        val raw = InMemoryKeyValueStore(
            mapOf(
                "timetable_profiles" to MiniJson.encode(listOf(profile.toJson())),
            ),
        )
        // 第 1 次写 = 开学日设置落盘（成功）；第 2 次写 = 课程落盘（失败）；第 3 次 = 回滚。
        val repository = TimetableRepository(
            TimetableStore(FailingWriteStore(raw, "timetable_profiles", failOnMatch = 2)),
        )

        val result = WarehouseCourseWriteBack.apply(
            repository = repository,
            courses = listOf(course("new", name = "新课", day = 5)),
            semesterStartDate = newStart,
        )

        assertTrue(result is WarehouseCourseWriteBack.Result.Failed)
        assertEquals("课没进就不许只改开学日", oldStart, repository.snapshot.settings.semesterStartDate)
    }

    @Test
    fun `空数组载荷不写盘`() {
        val repository = repositoryWith(listOf(course("old", name = "旧课")))
        val result = WarehouseCourseWriteBack.applyPayload(
            repository = repository,
            payload = "[]",
            unknownTeacher = "未知教师",
            unknownLocation = "未知地点",
            idFactory = { "id" },
        )

        assertTrue(result is WarehouseCourseWriteBack.PayloadResult.NoImportableCourses)
        assertEquals(listOf("旧课"), repository.snapshot.courses.map { it.name })
    }
}
