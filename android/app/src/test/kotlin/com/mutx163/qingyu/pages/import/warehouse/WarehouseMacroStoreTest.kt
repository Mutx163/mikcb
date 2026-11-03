package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 宏持久化测试（P1 / N5）。
 *
 * 对拍参照：`lib/services/warehouse_macro_service.dart`（只读）。三件事钉死：
 * 1. 键名与 Dart 物理落盘逐字节一致（`flutter.` 前缀由存储层统一加）；
 * 2. 读路径脱敏回写带 droppedStepCount 闸；
 * 3. recordSuccessfulImport 任何异常不外抛。
 */
class WarehouseMacroStoreTest {

    private fun record(
        schoolId: String = "s1",
        adapterId: String = "a1",
        steps: List<WarehouseMacroStep> = listOf(WarehouseMacroStep.click("#btn")),
    ): WarehouseMacroRecord {
        val now = LocalDateTime.parse("2026-11-03T09:00:00")
        return WarehouseMacroRecord(
            schoolId = schoolId,
            adapterId = adapterId,
            schoolName = "示例大学",
            adapterName = "教务A",
            importUrl = "http://jw.example.edu.cn/login",
            schoolResourceFolder = schoolId,
            adapterAssetJsPath = "resources/$schoolId/$adapterId.js",
            steps = steps,
            createdAt = now,
            updatedAt = now,
        )
    }

    // ---------------------------------------------------------------------
    // 键名与基本读写
    // ---------------------------------------------------------------------

    @Test
    fun `落盘键与 Dart SharedPreferences 物理键逐字节一致`() {
        val store = InMemoryKeyValueStore()
        WarehouseMacroStore(store).saveMacro(record())
        val keys = store.rawSnapshot().keys
        assertTrue(
            "本体键必须是 flutter.warehouse_macro_record_s1_a1（Dart 插件同前缀），实际：$keys",
            keys.contains("flutter.warehouse_macro_record_s1_a1"),
        )
        assertTrue(
            "索引键必须是 flutter.warehouse_macro_record_index，实际：$keys",
            keys.contains("flutter.warehouse_macro_record_index"),
        )
    }

    @Test
    fun `save 后 get round-trip 内容一致`() {
        val store = InMemoryKeyValueStore()
        val service = WarehouseMacroStore(store)
        val saved = record().copy(
            dialogResponses = linkedMapOf<String, Any?>(
                "confirm|T|M" to true,
                "replaceExisting" to false,
                "semesterConfig" to linkedMapOf<String, Any?>(
                    "startDate" to "2026-09-01",
                    "firstCourseWeek" to 2,
                ),
            ),
        )
        service.saveMacro(saved)
        val loaded = service.getMacro("s1", "a1")
        assertNotNull(loaded)
        assertEquals(saved, loaded)
    }

    @Test
    fun `hasMacro 查本体 delete 连索引一起清`() {
        val store = InMemoryKeyValueStore()
        val service = WarehouseMacroStore(store)
        assertFalse(service.hasMacro("s1", "a1"))
        service.saveMacro(record())
        assertTrue(service.hasMacro("s1", "a1"))

        service.deleteMacro("s1", "a1")
        assertFalse(service.hasMacro("s1", "a1"))
        val index = MiniJson.tryParse(store.getString(WarehouseMacroRecord.INDEX_KEY) ?: "[]") as List<*>
        assertTrue("删除后索引不应再有该条目", index.isEmpty())
    }

    @Test
    fun `坏本体读回 null 不崩`() {
        val store = InMemoryKeyValueStore(
            initial = mapOf(WarehouseMacroRecord.storageKey("s1", "a1") to "{not-json"),
        )
        assertNull(WarehouseMacroStore(store).getMacro("s1", "a1"))
    }

    // ---------------------------------------------------------------------
    // 脱敏：敏感值不允许出现在盘上
    // ---------------------------------------------------------------------

    @Test
    fun `保存的记录里敏感 value 不落盘`() {
        val store = InMemoryKeyValueStore()
        val secret = "MyS3cret-绝不能落盘"
        // 模型层允许内存中构造带敏感值的 fillField（转换层不会产出这种形状，
        // 但「落盘即脱敏」必须由 toJson 兜底）。
        WarehouseMacroStore(store).saveMacro(
            record(
                steps = listOf(
                    WarehouseMacroStep.fillField("#pwd", secret, "password"),
                ),
            ),
        )
        val onDisk = store.rawSnapshot().values.joinToString("\n")
        assertFalse("密码值不允许出现在任何盘上内容里", onDisk.contains(secret))
    }

    private fun dartStyleRaw(withSecret: Boolean, extraUnknownStep: Boolean = false): String {
        val secretStep = if (withSecret) {
            """{"type":"fillField","fieldType":"password","selector":"#pwd","value":"LEGACY-SECRET"}"""
        } else {
            """{"type":"waitForManualInput","fieldType":"password","selector":"#pwd","value":"manual_input_password"}"""
        }
        val unknown = if (extraUnknownStep) """,{"type":"waitForStarPhase"}""" else ""
        return """
            {"schoolId":"s1","adapterId":"a1","schoolName":"S","adapterName":"A",
             "importUrl":"http://jw.example.edu.cn/login","schoolResourceFolder":"s1",
             "adapterAssetJsPath":"a.js",
             "steps":[$secretStep,{"type":"click","selector":"#btn"}$unknown],
             "dialogResponses":{},
             "createdAt":"2026-11-03T09:00:00.000","updatedAt":"2026-11-03T09:00:00.000",
             "successfulImportCount":0}
        """.trimIndent()
    }

    @Test
    fun `旧记录读路径脱敏回写 洗掉历史密码`() {
        val store = InMemoryKeyValueStore(
            initial = mapOf(
                WarehouseMacroRecord.storageKey("s1", "a1") to dartStyleRaw(withSecret = true),
            ),
        )
        val service = WarehouseMacroStore(store)
        val loaded = service.getMacro("s1", "a1")
        assertNotNull(loaded)
        assertEquals(
            "敏感步骤读回应还原成 waitForManualInput",
            WarehouseMacroStepType.WAIT_FOR_MANUAL_INPUT,
            loaded!!.steps[0].type,
        )
        val onDisk = store.rawSnapshot()[physicalBlobKey()]
        assertNotNull(onDisk)
        assertFalse("读一次就该把历史密码洗掉", onDisk!!.contains("LEGACY-SECRET"))
    }

    /** rawSnapshot 的键是落盘物理键（带 flutter. 前缀），本体查找用它。 */
    private fun physicalBlobKey(): String =
        com.mutx163.qingyu.app.FrozenValueCodec.physicalKey(
            WarehouseMacroRecord.storageKey("s1", "a1"),
        )

    @Test
    fun `丢过步骤的记录不回写 少掉的步骤不许被永久落盘`() {
        val raw = dartStyleRaw(withSecret = true, extraUnknownStep = true)
        val store = InMemoryKeyValueStore(
            initial = mapOf(WarehouseMacroRecord.storageKey("s1", "a1") to raw),
        )
        val service = WarehouseMacroStore(store)
        val loaded = service.getMacro("s1", "a1")
        assertEquals(2, loaded!!.steps.size) // 3 条进 2 条出：unknown type 被丢
        assertEquals(
            "droppedStepCount > 0 时绝不能把重编码结果写回（否则丢步骤永久化）",
            raw,
            store.rawSnapshot()[physicalBlobKey()],
        )
    }

    // ---------------------------------------------------------------------
    // 索引：孤儿重建与坏目录重建
    // ---------------------------------------------------------------------

    @Test
    fun `目录漏了条目 从孤儿本体补齐并回写索引`() {
        val orphanRaw = """
            {"schoolId":"s2","adapterId":"b2","schoolName":"S","adapterName":"B",
             "importUrl":"u","schoolResourceFolder":"s2","adapterAssetJsPath":"b.js",
             "steps":[],"createdAt":"2026-11-03T09:00:00.000",
             "updatedAt":"2026-11-03T08:00:00.000","successfulImportCount":0}
        """.trimIndent()
        val store = InMemoryKeyValueStore(
            initial = mapOf(WarehouseMacroRecord.storageKey("s2", "b2") to orphanRaw),
        )
        val service = WarehouseMacroStore(store)
        val entries = service.getAllMacroEntries()
        assertEquals(1, entries.size)
        assertEquals("s2", entries[0].schoolId)
        assertEquals("b2", entries[0].adapterId)
        // 修好的目录已落盘
        val indexRaw = store.getString(WarehouseMacroRecord.INDEX_KEY)
        assertNotNull(indexRaw)
        assertTrue(indexRaw!!.contains("\"s2\""))
    }

    @Test
    fun `目录读坏 整份从本体重建`() {
        val rawA = """
            {"schoolId":"sa","adapterId":"aa","schoolName":"S","adapterName":"A",
             "importUrl":"u","schoolResourceFolder":"sa","adapterAssetJsPath":"a.js",
             "steps":[],"createdAt":"2026-11-03T09:00:00.000",
             "updatedAt":"2026-11-03T07:00:00.000","successfulImportCount":0}
        """.trimIndent()
        val rawB = """
            {"schoolId":"sb","adapterId":"bb","schoolName":"S","adapterName":"B",
             "importUrl":"u","schoolResourceFolder":"sb","adapterAssetJsPath":"b.js",
             "steps":[],"createdAt":"2026-11-03T09:00:00.000",
             "updatedAt":"2026-11-03T08:00:00.000","successfulImportCount":0}
        """.trimIndent()
        val store = InMemoryKeyValueStore(
            initial = mapOf(
                WarehouseMacroRecord.storageKey("sa", "aa") to rawA,
                WarehouseMacroRecord.storageKey("sb", "bb") to rawB,
                WarehouseMacroRecord.INDEX_KEY to "not-json-at-all",
            ),
        )
        val entries = WarehouseMacroStore(store).getAllMacroEntries()
        assertEquals(2, entries.size)
        // 按更新时间新→旧
        assertEquals("bb", entries[0].adapterId)
        assertEquals("aa", entries[1].adapterId)
    }

    // ---------------------------------------------------------------------
    // recordSuccessfulImport：绝不抛出
    // ---------------------------------------------------------------------

    @Test
    fun `记账成功 计数加一并更新脚本页地址`() {
        val store = InMemoryKeyValueStore()
        val service = WarehouseMacroStore(store)
        service.saveMacro(record())
        val ok = service.recordSuccessfulImport("s1", "a1", "http://jw.example.edu.cn/xsMain.jsp")
        assertTrue(ok)
        val loaded = service.getMacro("s1", "a1")
        assertEquals(1, loaded!!.successfulImportCount)
        assertEquals("http://jw.example.edu.cn/xsMain.jsp", loaded.scriptPageUrl)
    }

    @Test
    fun `没有记录时记账返回 false`() {
        assertFalse(
            WarehouseMacroStore(InMemoryKeyValueStore()).recordSuccessfulImport("s1", "a1"),
        )
    }

    @Test
    fun `存储写失败时记账返回 false 绝不外抛`() {
        val seeded = InMemoryKeyValueStore()
        WarehouseMacroStore(seeded).saveMacro(record())
        // 读路径透传到内存实现，写路径一律炸：记账的 saveMacro 会踩中。
        val throwing = ThrowingStore(seeded)
        val ok = WarehouseMacroStore(throwing).recordSuccessfulImport("s1", "a1")
        assertFalse("写失败要被吞掉返回 false（导入成功不能被记账翻成失败）", ok)
        assertTrue("记账确实尝试过写盘（异常不是绕过去的）", throwing.usedForWrite)
    }

    /** 读透传、写必炸的替身：验证 recordSuccessfulImport 的异常吞咽。 */
    private class ThrowingStore(private val delegate: KeyValueStore) : KeyValueStore by delegate {
        var usedForWrite = false

        override fun putString(key: String, value: String) {
            usedForWrite = true
            throw IllegalStateException("disk full (test stub)")
        }
    }
}
