package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `savePresetTimeSlots` 写链路（[WarehousePresetTimeSlotsWriteBack]）。
 *
 * 期望值**人推**：
 * - 载荷是节次时间数组（对齐 Dart `_decodeImportedSections` 的形状）；
 * - 成功 = 走仓储写入口落盘并套用，监听被通知、新仓库实例重读同盘能看到；
 * - 非法载荷 / 仓储校验拒绝 / 落盘异常，三种失败都**不覆盖用户设置**且回 Failed。
 */
class WarehousePresetTimeSlotsWriteBackTest {

    private val schemeName = "测试学校 导入节次"

    private val goodPayload =
        """[{"startTime":"08:00","endTime":"08:45"},{"startTime":"08:55","endTime":"09:40"}]"""

    private fun repositoryOn(raw: InMemoryKeyValueStore) = TimetableRepository(TimetableStore(raw))

    /** 记录通知 + 让断言能拿到最新快照的观察者。 */
    private class Recorder(repository: TimetableRepository) {
        val seen = mutableListOf<TimetableSnapshot>()

        init {
            repository.observe { seen.add(it) }
        }
    }

    private fun course(id: String, endSection: Int) = Course(
        id = id,
        name = "高数",
        teacher = "张老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun applied(result: WarehousePresetTimeSlotsWriteBack.PayloadResult): WarehousePresetTimeSlotsWriteBack.PayloadResult.Applied {
        assertTrue("应为 Applied，实际 $result", result is WarehousePresetTimeSlotsWriteBack.PayloadResult.Applied)
        return result as WarehousePresetTimeSlotsWriteBack.PayloadResult.Applied
    }

    // ---------- 正常载荷：创建新方案并套用 ----------

    @Test
    fun `正常载荷创建新方案套用当前课表并通知监听`() {
        val raw = InMemoryKeyValueStore()
        val repository = repositoryOn(raw)
        val recorder = Recorder(repository)

        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, goodPayload, schemeName,
        )

        val done = applied(result)
        assertTrue(done.created)
        assertEquals(2, done.sectionCount)
        assertEquals("08:00-08:45|08:55-09:40", done.signature)

        val snapshot = repository.snapshot
        val scheme = snapshot.timeSchemes.single { it.name == schemeName }
        assertEquals(done.schemeId, scheme.id)
        assertEquals("08:00", scheme.sections[0].startTime)
        assertEquals("09:40", scheme.sections[1].endTime)
        // 套用：当前课表指向它，镜像节次表同步。
        assertEquals(scheme.id, snapshot.settings.activeTimeSchemeId)
        assertEquals(2, snapshot.settings.sections.size)
        // 写后监听被刷新。
        assertTrue("落盘成功必须通知监听者", recorder.seen.isNotEmpty())

        // 真落盘：新仓库实例重读同一份盘能看到方案。
        val reloaded = repositoryOn(raw)
        assertEquals(scheme.id, reloaded.snapshot.timeSchemes.single { it.name == schemeName }.id)
    }

    // ---------- 同名方案：更新而不是新建 ----------

    @Test
    fun `同名方案存在时更新原方案并切到当前课表`() {
        val repository = repositoryOn(InMemoryKeyValueStore())
        val existing = repository.createTimeScheme(name = schemeName)
        val recorder = Recorder(repository)

        val threeSections =
            """[{"startTime":"08:00","endTime":"08:45"},{"startTime":"08:55","endTime":"09:40"},""" +
                """{"startTime":"10:00","endTime":"10:45"}]"""
        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, threeSections, schemeName,
        )

        val done = applied(result)
        assertFalse("同名方案应更新而不是新建", done.created)
        assertEquals(existing.id, done.schemeId)
        assertEquals("方案数不变", 1, repository.snapshot.timeSchemes.size)
        assertEquals(3, repository.snapshot.timeSchemes.single().sections.size)
        assertEquals(existing.id, repository.snapshot.settings.activeTimeSchemeId)
        assertEquals(3, repository.snapshot.settings.sections.size)
        assertTrue(recorder.seen.isNotEmpty())
    }

    // ---------- 非法载荷：不落盘、不覆盖 ----------

    @Test
    fun `载荷不是数组时不落盘也不通知`() {
        val repository = repositoryOn(InMemoryKeyValueStore())
        val recorder = Recorder(repository)
        val before = repository.snapshot

        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, """{"startTime":"08:00"}""", schemeName,
        )

        assertTrue(result is WarehousePresetTimeSlotsWriteBack.PayloadResult.InvalidFormat)
        assertEquals(before, repository.snapshot)
        assertTrue(recorder.seen.isEmpty())
    }

    @Test
    fun `整表皆坏时不落盘也不通知`() {
        val repository = repositoryOn(InMemoryKeyValueStore())
        val recorder = Recorder(repository)

        // 坏位按位补空：两条全坏 = 没有可用节次（对齐 Dart noSectionTimesToSave）。
        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, """[{"startTime":123},{}]""", schemeName,
        )

        assertTrue(result is WarehousePresetTimeSlotsWriteBack.PayloadResult.NoSectionTimes)
        assertTrue(repository.snapshot.timeSchemes.isEmpty())
        assertTrue(recorder.seen.isEmpty())
    }

    @Test
    fun `倒序节次被仓储校验拒绝且既有设置原样不动`() {
        val repository = repositoryOn(InMemoryKeyValueStore())
        val first = applied(
            WarehousePresetTimeSlotsWriteBack.applyPayload(repository, goodPayload, schemeName),
        )
        val settingsBefore = repository.snapshot.settings
        val recorder = Recorder(repository)

        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, """[{"startTime":"10:00","endTime":"09:00"}]""", schemeName,
        )

        assertTrue(result is WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed)
        result as WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed
        assertNotNull(result.errorCode)
        assertEquals("section_end_must_after_start", result.errorCode!!.substringBefore("|"))
        // 用户设置不被非法值覆盖。
        assertEquals(settingsBefore, repository.snapshot.settings)
        assertEquals(first.schemeId, repository.snapshot.settings.activeTimeSchemeId)
        assertTrue("校验拒绝不许通知", recorder.seen.isEmpty())
    }

    // ---------- 写失败：回 Failed、不通知 ----------

    @Test
    fun `落盘异常时回Failed且用户设置不动`() {
        val repository = TimetableRepository(TimetableStore(FailingWriteStore()))
        val recorder = Recorder(repository)
        val before = repository.snapshot

        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, goodPayload, schemeName,
        )

        assertTrue(result is WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed)
        result as WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed
        assertNull(result.errorCode)
        assertNotNull(result.cause)
        assertEquals("内存保持旧值", before, repository.snapshot)
        assertTrue("落盘失败不许通知", recorder.seen.isEmpty())
    }

    // ---------- 课程保护：目标方案盖不住现有课程时拒绝 ----------

    @Test
    fun `课程最靠后节次超出新方案时应用被拒且课表不切换`() {
        val repository = repositoryOn(InMemoryKeyValueStore())
        repository.addCourse(course("c1", endSection = 5))
        val settingsBefore = repository.snapshot.settings

        val result = WarehousePresetTimeSlotsWriteBack.applyPayload(
            repository, goodPayload, schemeName,
        )

        assertTrue(result is WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed)
        result as WarehousePresetTimeSlotsWriteBack.PayloadResult.Failed
        assertEquals("section_count_below_usage", result.errorCode!!.substringBefore("|"))
        // 方案本身创建成功（对齐 Dart create 分支），但当前课表没被切过去。
        val created = repository.snapshot.timeSchemes.single { it.name == schemeName }
        assertNotEquals(created.id, repository.snapshot.settings.activeTimeSchemeId)
        assertEquals(settingsBefore, repository.snapshot.settings)
    }

    // ---------- 请求解析与签名 ----------

    @Test
    fun `请求解析只认可信requestId的savePresetTimeSlots消息`() {
        val ok = warehousePresetTimeSlotsRequest(
            """{"type":"savePresetTimeSlots","requestId":"slots_1","payload":"[]"}""",
        )
        assertEquals("slots_1", ok?.requestId)
        assertEquals("[]", ok?.payload)

        assertNull(warehousePresetTimeSlotsRequest(null))
        assertNull(warehousePresetTimeSlotsRequest("not json"))
        assertNull(warehousePresetTimeSlotsRequest("""{"type":"courses","requestId":"c1","payload":"[]"}"""))
        // requestId 不可信（可拼进 JS 的字符之外）一律拒绝。
        assertNull(
            warehousePresetTimeSlotsRequest(
                """{"type":"savePresetTimeSlots","requestId":"a');alert(1);//","payload":"[]"}""",
            ),
        )
        // payload 不是字符串（数组直接内嵌）回 null，宿主按旧降级口径回答。
        assertNull(
            warehousePresetTimeSlotsRequest(
                """{"type":"savePresetTimeSlots","requestId":"slots_2","payload":[]}""",
            ),
        )
    }

    @Test
    fun `签名与Dart口径一致`() {
        assertEquals(
            "08:00-08:45|08:55-09:40",
            WarehousePresetTimeSlotsWriteBack.sectionSignature(
                listOf(
                    SectionTime("08:00", "08:45"),
                    SectionTime("08:55", "09:40"),
                ),
            ),
        )
    }

    // ---------- 替身 ----------

    /** 读放行、写一律抛（对齐 TimetableRepositoryTest 的 FailingWriteStore）。 */
    private class FailingWriteStore : KeyValueStore {
        private val delegate = InMemoryKeyValueStore()

        override fun getString(key: String): String? = delegate.getString(key)
        override fun getInt(key: String, default: Int): Int = delegate.getInt(key, default)
        override fun getLong(key: String, default: Long): Long = delegate.getLong(key, default)
        override fun getBool(key: String, default: Boolean): Boolean = delegate.getBool(key, default)
        override fun getStringList(key: String): List<String>? = delegate.getStringList(key)
        override fun putString(key: String, value: String) = failWrite()
        override fun putInt(key: String, value: Int) = failWrite()
        override fun putLong(key: String, value: Long) = failWrite()
        override fun putBool(key: String, value: Boolean) = failWrite()
        override fun putStringList(key: String, value: List<String>) = failWrite()
        override fun remove(key: String) = failWrite()
        override fun contains(key: String): Boolean = delegate.contains(key)
        override fun archiveCorruptAndRemove(key: String, micros: Long): String = failWrite()
        override fun keys(): Set<String> = delegate.keys()

        private fun failWrite(): Nothing = throw IllegalStateException("disk_full")
    }
}
