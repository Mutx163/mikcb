package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.MiniJson
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
 * 局域网**整份快照恢复**（`backupType: full` + profiles）的接受 / 拒绝矩阵与
 * 撤销点生命周期（2026-11-03 分层放行；此前一刀切拒绝）。
 *
 * 与 [LanTransferApplyTest] 同一基建：内存 KV → `TimetableStore` →
 * `TimetableRepository` → `LanEditRepositoryHost`，不 mock 存储；
 * 「没写盘」一律断言 `rawSnapshot()` 的原始字节。
 */
class LanTransferWholeRestoreTest {

    // -----------------------------------------------------------------------
    // 接受矩阵
    // -----------------------------------------------------------------------

    @Test
    fun `整份恢复覆盖应用 真的换掉档案表并落盘 还回了撤销点`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)

        val incoming = listOf(
            profile(
                id = "p2",
                name = "手机上没见过的课表",
                course("c9", "恢复来的课"),
                settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
                currentWeek = 3,
            ),
        )
        val before = store.rawSnapshot()
        val applied = host.applyTransferJson(fullPackage(incoming), TransferApplyMode.OVERWRITE)

        assertEquals(true, applied["applied"])
        val transferId = applied["transferId"]
        assertNotNull("整份恢复成功也必须回撤销点 id", transferId)
        assertNotEquals("撤销点 id 不是包里的 packageId", "whole-test-1", transferId)

        assertEquals("档案表整表替换", listOf("p2"), repository.snapshot.profiles.map { it.id })
        assertEquals("激活档案切到包里指的那份", "p2", repository.snapshot.activeProfileId)
        assertEquals("全局设置取自激活档案的内嵌值", 18, repository.snapshot.settings.semesterWeekCount)
        assertEquals("当前周跟着激活档案走", 3, repository.snapshot.currentWeek)
        assertEquals(listOf("c9"), repository.courses.map { it.id })
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertTrue("盘上要写着恢复来的课", raw.contains("恢复来的课"))
        assertFalse("被换掉的旧档案不许还在盘上", raw.contains("p1"))
        assertNotEquals("盘必须真的变过", before, store.rawSnapshot())
    }

    @Test
    fun `整份恢复预演不写盘 差异以档案为粒度并标记 wholeRestore`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val incoming = listOf(profile(id = "p1", name = "默认课表改名", course("c9", "恢复来的课")))

        val before = store.rawSnapshot()
        val preview = host.previewTransferJson(fullPackage(incoming))

        assertEquals(true, preview["wholeRestore"])
        @Suppress("UNCHECKED_CAST")
        val diff = preview["overwriteDiff"] as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val summaries = diff["summaries"] as List<Map<String, Any?>>
        val profilesSummary = summaries.first { it["kind"] == "profiles" }
        assertEquals("同名档案内容变了算 updated", 1, profilesSummary["updated"])
        assertEquals("预演不许动盘", before, store.rawSnapshot())
    }

    @Test
    fun `整份恢复档案内嵌课程颜色照 LAN 口径收窄`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val incoming = listOf(
            profile(id = "p2", name = "彩包", course("c9", "恢复来的课").copy(color = "red")),
        )

        val applied = host.applyTransferJson(fullPackage(incoming), TransferApplyMode.OVERWRITE)

        assertEquals(true, applied["applied"])
        assertEquals(
            "档案里的课程颜色与顶层课程同一条注入面，必须收窄到 #RRGGBB",
            "#2196F3",
            repository.courses.single().color,
        )
    }

    @Test
    fun `整份恢复 merge 语义被拒 盘上一字未变`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val incoming = listOf(profile(id = "p2", name = "另一份课表", course("c9", "恢复来的课")))
        val before = store.rawSnapshot()

        val applied = host.applyTransferJson(fullPackage(incoming), TransferApplyMode.MERGE)

        assertEquals(false, applied["applied"])
        assertEquals("transfer_full_backup_requires_overwrite", applied["error"])
        assertEquals("档案表不许被动", listOf("p1"), repository.snapshot.profiles.map { it.id })
        assertEquals("被拒的整份恢复盘上一字未变", before, store.rawSnapshot())
    }

    @Test
    fun `整份恢复档案内引用对不上被拒 盘上一字未变`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val course = course("c9", "恢复来的课")
        val incoming = listOf(
            profile(id = "p2", name = "断引用", course, exam = exam("e9", "期末", courseId = "c_missing")),
        )
        val before = store.rawSnapshot()

        val applied = host.applyTransferJson(fullPackage(incoming), TransferApplyMode.OVERWRITE)

        assertEquals(false, applied["applied"])
        assertEquals("exam_course_missing:p2/e9", applied["error"])
        assertEquals(listOf("p1"), repository.snapshot.profiles.map { it.id })
        assertEquals(before, store.rawSnapshot())
    }

    @Test
    fun `整份恢复激活档案指不到包内档案 回落第一份`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val incoming = listOf(
            profile(id = "p2", name = "第一份"),
            profile(id = "p3", name = "第二份"),
        )

        val applied = host.applyTransferJson(
            fullPackage(incoming, activeProfileId = "ghost"),
            TransferApplyMode.OVERWRITE,
        )

        assertEquals(true, applied["applied"])
        assertEquals("悬空 activeProfileId 回落第一份（Dart 同口径）", "p2", repository.snapshot.activeProfileId)
    }

    // -----------------------------------------------------------------------
    // 撤销点：重建 / 失效 / 回炉
    // -----------------------------------------------------------------------

    @Test
    fun `整份恢复撤销 现场没动过 整份回到导入前`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val applied = host.applyTransferJson(
            fullPackage(listOf(profile(id = "p2", name = "恢复来的课表", course("c9", "恢复来的课")))),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        val transferId = applied["transferId"] as String

        val undo = host.undoTransferJson(transferId)

        assertEquals(true, undo["undo"])
        assertEquals("p1", repository.snapshot.activeProfileId)
        assertEquals(listOf("p1"), repository.snapshot.profiles.map { it.id })
        assertEquals(listOf("keep"), repository.courses.map { it.id })
        @Suppress("UNCHECKED_CAST")
        val restored = undo["restored"] as Map<String, Int>
        assertEquals(1, restored["profiles"])
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertFalse("撤销后盘上不许再留着恢复来的课", raw.contains("恢复来的课"))
    }

    @Test
    fun `整份恢复撤销 导入后动过数据 拒绝且不消费撤销点`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)
        val content = fullPackage(
            listOf(profile(id = "p2", name = "恢复来的课表", course("c9", "恢复来的课"))),
        )
        val applied = host.applyTransferJson(content, TransferApplyMode.OVERWRITE)
        val transferId = applied["transferId"] as String
        // 导入之后用户改了一门课：撤销必须让路，不能把用户的修改一起抹掉。
        repository.updateCourse(repository.courses.single().copy(teacher = "用户后来改的"))

        val refused = host.undoTransferJson(transferId)
        assertEquals(false, refused["undo"])
        assertEquals("transfer_undo_state_changed", refused["error"])

        // 拒绝不许烧掉撤销点。用户把数据改回去的最可靠路径就是把同一份包再整份
        // 恢复一遍——恢复完现场与撤销点的「导入后」一致，同一个 id 还能再撤。
        val reapplied = host.applyTransferJson(content, TransferApplyMode.OVERWRITE)
        assertEquals(true, reapplied["applied"])
        val undo = host.undoTransferJson(transferId)
        assertEquals(true, undo["undo"])
        assertEquals("p1", repository.snapshot.activeProfileId)
    }

    @Test
    fun `整份恢复撤销写盘失败 令牌放回 重试可成`() {
        val backing = InMemoryKeyValueStore()
        val failing = FailingKeyValueStore(backing, failOnKeyContaining = "profile")
        val repository = repositoryOn(failing)
        val host = LanEditRepositoryHost(repository)
        val applied = host.applyTransferJson(
            fullPackage(listOf(profile(id = "p2", name = "恢复来的课表", course("c9", "恢复来的课")))),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        val transferId = applied["transferId"] as String

        failing.enabled = true
        val failedUndo = host.undoTransferJson(transferId)
        failing.enabled = false
        assertEquals(false, failedUndo["undo"])
        assertEquals("transfer_undo_failed", failedUndo["error"])
        assertEquals("写盘失败时内存不许被动", "p2", repository.snapshot.activeProfileId)

        val retry = host.undoTransferJson(transferId)
        assertEquals("失败的撤销点要回炉，同一个 id 重试能成", true, retry["undo"])
        assertEquals("p1", repository.snapshot.activeProfileId)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    /** 在指定 key 上抛错的存储替身：证明「撤销写盘失败时令牌真的放回来了」。 */
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
                    courses = listOf(course("keep", "原有课程")),
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

    /** `backupType: full` + profiles 的整份包（settings/currentWeek 省略，档案内嵌）。 */
    private fun fullPackage(
        profiles: List<TimetableProfile>,
        activeProfileId: String? = null,
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "whole-test-1",
            scope = TransferScope.ALL_DATA,
            exportedAtIso = "2026-11-03T09:00:00.000",
            channel = TransferChannel.LAN,
            activeProfileId = activeProfileId,
            profilesJson = profiles.map { it.toJson() },
            isFullBackup = true,
        ),
    )

    private fun profile(
        id: String,
        name: String,
        vararg courses: Course,
        exam: Exam? = null,
        task: CourseTask? = null,
        settings: TimetableSettings = TimetableSettings.defaults(),
        currentWeek: Long = 1,
    ): TimetableProfile = TimetableProfile(
        id = id,
        name = name,
        courses = courses.toList(),
        tasks = task?.let { listOf(it) } ?: emptyList(),
        exams = exam?.let { listOf(it) } ?: emptyList(),
        settings = settings,
        currentWeek = currentWeek,
        createdAt = stamp,
        lastUsedAt = stamp,
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
        dateTime = LocalDateTime.of(2026, 12, 1, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = stamp,
        updatedAt = stamp,
    )

    private companion object {
        val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 3, 9, 0)
    }
}
