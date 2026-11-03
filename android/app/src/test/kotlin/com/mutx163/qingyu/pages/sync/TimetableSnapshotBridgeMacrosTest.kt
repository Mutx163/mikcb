package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.computeContentSha256
import com.mutx163.qingyu.sync.decodeSnapshotObject
import com.mutx163.qingyu.sync.selectSnapshotMacros
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 快照桥的宏承载（P3 / N5）：`warehouse.macros` 键位 + 恢复回调。
 *
 * 这里只用 `Map<String, Any?>` 原始载荷——宏的编解码在 warehouse 域
 * （`WarehouseMacroCloudSync`），sync 模块不能反向依赖 warehouse，否则
 * `-Module pages/sync` 的 L0 编不过。
 */
class TimetableSnapshotBridgeMacrosTest {

    private fun repository(): TimetableRepository =
        TimetableRepository(TimetableStore(InMemoryKeyValueStore()))

    private fun course(id: String): Course = Course(
        id = id,
        name = "课程-$id",
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun snapshotBytes(macros: List<Map<String, Any?>>): ByteArray {
        val remote = repository()
        remote.addCourse(course("remote"))
        val result = TimetableSnapshotBridge.buildSnapshotBytes(
            repository = remote,
            deviceId = "devB",
            exportedAtIso = "2026-03-06T08:00:00.000",
            macros = macros,
        )
        assertTrue("快照应构建成功", result is SnapshotBuildResult.Success)
        return (result as SnapshotBuildResult.Success).bytes
    }

    @Test
    fun `上传快照的宏写在 warehouse_macros 下`() {
        val bytes = snapshotBytes(
            listOf(
                linkedMapOf("schoolId" to "s1", "adapterId" to "a1"),
                linkedMapOf("schoolId" to "s2", "adapterId" to "a2"),
            ),
        )
        val decoded = decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        val warehouse = decoded["warehouse"] as? Map<*, *>
        assertNotNull("Dart 读的是 warehouse.macros，键位不能漂", warehouse)
        val macros = warehouse!!["macros"] as? List<*>
        assertEquals(2, macros?.size)
        assertEquals("s1", (macros!![0] as Map<*, *>)["schoolId"])
    }

    @Test
    fun `恢复把 warehouse_macros 原始列表交给回调`() {
        val bytes = snapshotBytes(
            listOf(linkedMapOf("schoolId" to "s1", "adapterId" to "a1")),
        )
        val local = repository()
        local.addCourse(course("local"))
        var captured: Any? = null

        val result = TimetableSnapshotBridge.applySnapshot(local, bytes) { raw -> captured = raw }

        assertTrue("恢复应成功", result is SnapshotApplyResult.Applied)
        val macros = captured as? List<*>
        assertNotNull("回调必须拿到宏列表（落库由 warehouse 侧做）", macros)
        assertEquals(1, macros?.size)
        assertEquals("s1", (macros!![0] as Map<*, *>)["schoolId"])
    }

    @Test
    fun `快照没带宏时回调用空列表 不是 null 跳过`() {
        val bytes = snapshotBytes(emptyList())
        val local = repository()
        local.addCourse(course("local"))
        var called = false
        var captured: Any? = null

        TimetableSnapshotBridge.applySnapshot(local, bytes) { raw ->
            called = true
            captured = raw
        }

        assertTrue("回调必须被调用（空表也要落库，否则清不掉本地旧宏）", called)
        assertTrue("空表应是空 List，不是 null", captured is List<*>)
        assertEquals(0, (captured as List<*>).size)
    }

    @Test
    fun `不传回调时恢复只动课表`() {
        val bytes = snapshotBytes(listOf(linkedMapOf("schoolId" to "s1")))
        val local = repository()
        local.addCourse(course("local"))

        val result = TimetableSnapshotBridge.applySnapshot(local, bytes)

        assertTrue(result is SnapshotApplyResult.Applied)
        assertEquals("课表确实被覆盖成远端那份", 1, local.snapshot.courses.size)
        assertEquals("remote", local.snapshot.courses.first().id)
    }

    /**
     * 「导出 → 快照 → 导入」往返：上传侧载荷（`WarehouseMacroCloudSync.macrosProvider`
     * 产出的 `record.toJson()` 形状）经快照编码再解出来，内容必须逐字不丢。
     * 这是 sync 侧能断言到的最远处——`Map` ⇄ `WarehouseMacroRecord` 由 warehouse 域的
     * `WarehouseMacroCloudSyncTest` 钉，两段合起来才是端到端。
     */
    @Test
    fun `导出到快照再解出 宏载荷往返一致`() {
        val payload = listOf(
            linkedMapOf<String, Any?>(
                "schoolId" to "s1",
                "adapterId" to "a1",
                "importUrl" to "http://jw.example.edu.cn/login",
                "steps" to listOf(
                    linkedMapOf<String, Any?>("type" to "click", "selector" to "#login"),
                    linkedMapOf<String, Any?>("type" to "delay", "ms" to 3000L),
                ),
                "dialogResponses" to linkedMapOf<String, Any?>(
                    "semesterConfig" to linkedMapOf<String, Any?>(
                        "startDate" to "2026-09-01",
                        "firstCourseWeek" to 1,
                    ),
                ),
                "successfulImportCount" to 1,
            ),
        )

        val bytes = snapshotBytes(payload)
        val decoded = decodeSnapshotObject(String(bytes, Charsets.UTF_8))
        @Suppress("UNCHECKED_CAST")
        val roundTripped = selectSnapshotMacros(decoded) as List<Map<String, Any?>>

        assertEquals(1, roundTripped.size)
        assertEquals(payload[0]["schoolId"], roundTripped[0]["schoolId"])
        assertEquals(payload[0]["importUrl"], roundTripped[0]["importUrl"])
        assertEquals("步骤一条不能少（快照恢复靠它回放）", 2, (roundTripped[0]["steps"] as List<*>).size)
        assertEquals(
            "#login",
            ((roundTripped[0]["steps"] as List<*>)[0] as Map<*, *>)["selector"],
        )
        assertEquals(
            "嵌套的弹窗应答也要原样回来（JSON 数字解出是 Long）",
            1L,
            ((roundTripped[0]["dialogResponses"] as Map<*, *>)["semesterConfig"] as Map<*, *>)["firstCourseWeek"],
        )
        assertEquals(1L, roundTripped[0]["successfulImportCount"])
    }

    /**
     * 坏数据：远端快照（可能是历史导出 / 手改文件）里混进非对象项。
     *
     * 桥是纯搬运工——**不在这里过滤**，原样交给 warehouse 侧；过滤是
     * `WarehouseMacroCloudSync.parseSnapshotMacros` 的职责（那条断言在 warehouse 域
     * `WarehouseMacroCloudSyncTest`）。这里要钉的两件事：一条坏宏不许炸掉整份恢复；
     * 好条目必须照样带出去。
     */
    @Test
    fun `远端快照里的坏宏条目不炸恢复 好条目照常过桥`() {
        val bytes = snapshotBytesWithRawMacros(
            listOf("not-a-map", 42, linkedMapOf<String, Any?>("schoolId" to "s1", "adapterId" to "a1")),
        )
        val local = repository()
        local.addCourse(course("local"))
        var captured: Any? = null

        val result = TimetableSnapshotBridge.applySnapshot(local, bytes) { raw -> captured = raw }

        assertTrue("一条坏宏不能炸掉整份课表恢复", result is SnapshotApplyResult.Applied)
        val macros = captured as List<*>
        assertEquals("桥原样带出三条（丢弃由 warehouse 侧做）", 3, macros.size)
        assertEquals("s1", (macros[2] as Map<*, *>)["schoolId"])
    }

    /**
     * 造一份「远端写的」快照：`warehouse.macros` 里塞非对象项。
     * 类型化入口 [TimetableSnapshotBridge.buildSnapshotBytes] 喂不进去坏数据，
     * 只能改标准快照字节（改完按同一口径重算 `contentSha256`）。
     */
    private fun snapshotBytesWithRawMacros(rawMacros: List<Any?>): ByteArray {
        val base = snapshotBytes(emptyList())
        val payload = LinkedHashMap(decodeSnapshotObject(String(base, Charsets.UTF_8)))
        @Suppress("UNCHECKED_CAST")
        val warehouse = LinkedHashMap(payload["warehouse"] as Map<String, Any?>)
        warehouse["macros"] = rawMacros
        payload["warehouse"] = warehouse
        payload["contentSha256"] = computeContentSha256(payload)
        return MiniJson.encode(payload).toByteArray(Charsets.UTF_8)
    }
}
