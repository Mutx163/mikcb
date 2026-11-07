package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
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
 * 局域网导入撤销点（`POST /api/v1/import/undo`）的 L0 测试。
 *
 * 全程真仓储（内存 KV → `TimetableStore` → `TimetableRepository`）。断言落在
 * 「仓储视图」与「盘上原始字节」两处：撤销失败/跳过的用例必须证明**一个字节都没写**，
 * 只断言返回值证明不了。
 *
 * 覆盖四条验收线：正常撤销、用户之后的操作不被抹掉、transferId 缺失安全跳过、
 * 重复撤销幂等。
 */
class LanTransferUndoTest {

    private val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 2, 9, 0)

    @Test
    fun `应用成功回真实 transferId 凭它能撤销这一批导入`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep", "原有课程"))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(courses = listOf(course("c9", "外来课程"))),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        val transferId = applied["transferId"] as? String
        assertNotNull("apply 成功必须回真实撤销点 id：$applied", transferId)
        assertNotEquals("撤销点 id 不能复用包里的 packageId", "transfer-test-1", transferId)

        val undone = host.undoTransferJson(transferId!!)
        assertEquals("撤销必须成功：$undone", true, undone["undo"])
        assertEquals(transferId, undone["transferId"])
        assertEquals(1, restoredCount(undone, "courses"))

        assertFalse("本次导入新增的课必须撤掉", repository.courses.any { it.id == "c9" })
        assertTrue("导入前的课必须还在", repository.courses.any { it.id == "keep" })
        assertFalse(
            "盘上也不许留着被撤掉的课",
            store.rawSnapshot().values.joinToString("\n").contains("外来课程"),
        )
    }

    @Test
    fun `撤销只回退这一批 用户导入后改过的课保留`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep", "原有课程"))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(courses = listOf(course("c9", "外来课程"), course("c10", "另一门"))),
            TransferApplyMode.MERGE,
        )
        val transferId = applied["transferId"] as String

        // 导入之后用户改了其中一门课：撤销必须保留这次修改。
        repository.updateCourse(course("c9", "用户改名"))

        val undone = host.undoTransferJson(transferId)
        assertEquals(true, undone["undo"])
        assertEquals(1, restoredCount(undone, "courses"))
        assertEquals("用户改过的课必须保留原样", "用户改名", repository.courses.single { it.id == "c9" }.name)
        assertFalse("没被改过的外来课要撤掉", repository.courses.any { it.id == "c10" })
        assertTrue("导入前的课必须还在", repository.courses.any { it.id == "keep" })
    }

    @Test
    fun `导入后用户新增的课不会被撤销抹掉`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(courses = listOf(course("c9", "外来课程"))),
            TransferApplyMode.MERGE,
        )
        val transferId = applied["transferId"] as String

        repository.addCourse(course("mine", "导入后自己加的"))

        val undone = host.undoTransferJson(transferId)
        assertEquals(true, undone["undo"])
        assertTrue("导入后用户新增的课不在本次补丁里", repository.courses.any { it.id == "mine" })
        assertFalse("本次导入新增的课仍要被撤掉", repository.courses.any { it.id == "c9" })
    }

    @Test
    fun `transferId 缺失或未知时安全跳过且不写盘`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep", "原有课程"))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())
        val before = store.rawSnapshot()

        val blank = host.undoTransferJson("   ")
        assertEquals(false, blank["undo"])
        assertEquals("transfer_id_required", blank["error"])
        assertEquals("空 id 不许动盘", before, store.rawSnapshot())

        val unknown = host.undoTransferJson("transfer-not-a-real-id")
        assertEquals(false, unknown["undo"])
        assertEquals("transfer_undo_token_missing", unknown["error"])
        assertEquals("不认识的 id 不许动盘", before, store.rawSnapshot())
        assertEquals(listOf("keep"), repository.courses.map { it.id })
    }

    @Test
    fun `重复撤销幂等 第二次既不报错也不再改数据`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep", "原有课程"))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(courses = listOf(course("c9", "外来课程"))),
            TransferApplyMode.MERGE,
        )
        val transferId = applied["transferId"] as String

        val first = host.undoTransferJson(transferId)
        assertEquals(true, first["undo"])
        val afterFirstUndo = store.rawSnapshot()
        val coursesAfterFirstUndo = repository.courses.map { it.id }

        val second = host.undoTransferJson(transferId)
        assertEquals("撤销点已消费，第二次不应再执行", false, second["undo"])
        assertEquals("transfer_undo_already_undone", second["error"])
        assertEquals("第二次撤销不许动盘", afterFirstUndo, store.rawSnapshot())
        assertEquals("课程集合保持不变", coursesAfterFirstUndo, repository.courses.map { it.id })
    }

    @Test
    fun `撤销把设置与当前周一起回到导入前`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                settings = TimetableSettings.defaults().copy(semesterWeekCount = 18),
                currentWeek = 5,
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        assertEquals("前置条件：设置已被导入改写", 18, repository.snapshot.settings.semesterWeekCount)
        assertEquals("前置条件：当前周已被导入改写", 5, repository.snapshot.currentWeek)

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals(true, undone["undo"])
        assertEquals("设置要回到导入前", 20, repository.snapshot.settings.semesterWeekCount)
        assertEquals("当前周要回到导入前", 7, repository.snapshot.currentWeek)
        assertEquals(1, restoredCount(undone, "settings"))
        assertEquals(1, restoredCount(undone, "current_week"))
    }

    @Test
    fun `撤销会删掉本次导入新建的时间模板_同id模板不再被导入改名`() {
        // 2026-11-06 返工：导入不再拿包里的 name/sections 改写同 id 的本机模板
        // （`LanTransferApplier.executeTimeSchemes` 的 Update 只建映射）。
        // 所以「被改名再还原」这个场景已经不存在——同 id 模板导入前后都是本机原名，
        // 撤销只需把导入**新建**的那套收回。断言按新语义保留。
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val localScheme = repository.createTimeScheme("本地模板", sectionsTwo())
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(
                    // 节次与本地模板不同 → 走 Create（同签名会走 Reuse，不会新建）。
                    scheme("s_remote", "外来新建模板", sectionsThree()),
                    scheme(localScheme.id, "外来改名", sectionsTwo()),
                ),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        val createdId = repository.snapshot.timeSchemes.first { it.id != localScheme.id }.id
        assertEquals(2, repository.snapshot.timeSchemes.size)
        assertEquals(
            "同 id 模板不许被包里的名字覆盖（导入前就叫本地模板）",
            "本地模板",
            repository.snapshot.timeSchemes.first { it.id == localScheme.id }.name,
        )

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals(true, undone["undo"])
        assertFalse("导入新建的模板要删掉", repository.snapshot.timeSchemes.any { it.id == createdId })
        assertEquals("同 id 模板仍是本机原名", "本地模板", repository.snapshot.timeSchemes.single().name)
        assertTrue("导入新建的课也要撤掉", repository.courses.none { it.id == "c9" })
    }

    @Test
    fun `导入后用户改过的新建模板撤销时保留`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(scheme("s_remote", "外来新建模板", sectionsThree())),
            ),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        val createdId = repository.snapshot.timeSchemes.single().id

        // 导入之后用户自己改了这套模板：撤销点必须尊重「之后的编辑」，
        // 只回退这一批导入造成的差异，不能把用户改名一起抹掉。
        repository.updateTimeScheme(createdId, "用户改名", sectionsTwo())

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals(true, undone["undo"])
        val kept = repository.snapshot.timeSchemes.single { it.id == createdId }
        assertEquals("用户改名", kept.name)
        assertFalse("撤销仍要撤掉这批导入的课", repository.courses.any { it.id == "c9" })
    }

    @Test
    fun `连续两次导入叠加 先撤 B 再撤 A 各自的撤销点都能用`() {
        // 对应 Dart `TransferUndoService` 的多槽语义（capacity=3）：
        // apply B 不许把 apply A 的撤销点顶掉，两次 undo 各消费自己的 id。
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep", "原有课程"))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val appliedA = host.applyTransferJson(
            packageJson(courses = listOf(course("ca", "A 课程"))),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, appliedA["applied"])
        val idA = appliedA["transferId"] as String

        val appliedB = host.applyTransferJson(
            packageJson(courses = listOf(course("cb", "B 课程"))),
            TransferApplyMode.MERGE,
        )
        assertEquals(true, appliedB["applied"])
        val idB = appliedB["transferId"] as String
        assertNotEquals("两次导入必须各自生成撤销点 id", idA, idB)

        // 先撤 B：只回 B，A 仍在。
        val undoB = host.undoTransferJson(idB)
        assertEquals("撤 B 必须成功：$undoB", true, undoB["undo"])
        assertFalse("B 课程要撤掉", repository.courses.any { it.id == "cb" })
        assertTrue("A 课程必须留着（B 的撤销点不该覆盖 A 的现场）", repository.courses.any { it.id == "ca" })

        // 再撤 A：A 的撤销点仍可按自己的 id 取到。
        val undoA = host.undoTransferJson(idA)
        assertEquals("撤 A 必须成功：$undoA", true, undoA["undo"])
        assertFalse("A 课程要撤掉", repository.courses.any { it.id == "ca" })
        assertTrue("导入前的课必须还在", repository.courses.any { it.id == "keep" })
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun restoredCount(result: Map<String, Any?>, kind: String): Int {
        @Suppress("UNCHECKED_CAST")
        val restored = result["restored"] as Map<String, Int>
        return restored[kind] ?: 0
    }

    private fun repositoryOn(store: InMemoryKeyValueStore): TimetableRepository {
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
        timeSchemes: List<TimeScheme> = emptyList(),
        settings: TimetableSettings? = TimetableSettings.defaults(),
        currentWeek: Int? = 7,
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-test-1",
            scope = scope,
            exportedAtIso = "2026-11-02T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = currentWeek,
            settingsJson = settings?.toJson(),
            coursesJson = courses.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
        ),
    )

    private fun course(id: String, name: String): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun scheme(id: String, name: String, sections: List<SectionTime>): TimeScheme = TimeScheme(
        id = id,
        name = name,
        sections = sections,
        createdAt = stamp,
        updatedAt = stamp,
    )

    private fun sectionsTwo(): List<SectionTime> = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("08:55", "09:40"),
    )

    private fun sectionsThree(): List<SectionTime> = sectionsTwo() + SectionTime("10:00", "10:45")
}
