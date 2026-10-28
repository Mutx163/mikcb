package com.mutx163.qingyu.app

import com.mutx163.qingyu.FlutterPrefsCodec
import java.util.Base64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * [KeyValueStore] / [FrozenValueCodec] 的语义测试（纯 JVM，内存实现）。
 *
 * 期望值全部**人推**：
 * - 前缀与留档名来自数据契约 §1.1 / §1.3 与 `corruptBackupKey` 的定义；
 * - `List<String>` 的线格式断言用**独立事实**校验：Java 序列化流的头两个字节是
 *   `0xAC 0xED`（STREAM_MAGIC）、紧接两个字节是 `0x00 0x05`（STREAM_VERSION），
 *   MIME Base64 行宽 76、换行只用 `\n`（flag=0）。这些都不是从实现里抄的。
 */
class KeyValueStoreTest {

    /** 数据契约 §1.3 点名的 4 个生产 key。 */
    private val productionListKeys = listOf(
        "courses",
        "teacher_records",
        "location_records",
        "warehouse_recent_school_ids",
    )

    // ---------- key 前缀 ----------

    @Test
    fun physicalKeyIsContractKeyWithFlutterPrefix() {
        assertEquals("flutter.timetable_profiles", FrozenValueCodec.physicalKey("timetable_profiles"))
        assertEquals("flutter.", FrozenValueCodec.KEY_PREFIX)
    }

    @Test
    fun logicalKeyStripsPrefixAndRejectsForeignKeys() {
        assertEquals("current_week", FrozenValueCodec.logicalKey("flutter.current_week"))
        // 原生侧自有 key 不归我们管。
        assertNull(FrozenValueCodec.logicalKey("native_runtime_prefs_foo"))
    }

    @Test
    fun keysReturnsLogicalKeysOnly() {
        val store = InMemoryKeyValueStore(mapOf("current_week" to "7"))
        store.putString("active_timetable_profile_id", "p1")
        assertEquals(setOf("current_week", "active_timetable_profile_id"), store.keys())
    }

    // ---------- 标量往返 ----------

    @Test
    fun stringAndIntAndBoolRoundTrip() {
        val store = InMemoryKeyValueStore()
        store.putString("active_timetable_profile_id", "profile-a")
        store.putInt("current_week", 12)
        store.putBool("some_flag", true)

        assertEquals("profile-a", store.getString("active_timetable_profile_id"))
        assertEquals(12, store.getInt("current_week", -1))
        assertTrue(store.getBool("some_flag", false))
        // 落盘形态：int/bool 都是字符串，与插件一致。
        assertEquals("12", store.rawSnapshot()["flutter.current_week"])
        assertEquals("true", store.rawSnapshot()["flutter.some_flag"])
    }

    @Test
    fun missingKeysFallBackToDefaults() {
        val store = InMemoryKeyValueStore()
        assertNull(store.getString("nope"))
        assertEquals(20, store.getInt("nope", 20))
        assertFalse(store.getBool("nope", false))
        assertNull(store.getStringList("nope"))
        assertFalse(store.contains("nope"))
    }

    @Test
    fun getIntFallsBackWhenStoredValueIsNotANumber() {
        val store = InMemoryKeyValueStore(mapOf("current_week" to "not-a-number"))
        assertEquals(20, store.getInt("current_week", 20))
    }

    // ---------- List<String> ----------

    @Test
    fun stringListRoundTripsByteExactForTheFourProductionKeys() {
        val values = listOf("数学", "English 101", "带\n换行的值", "")
        for (key in productionListKeys) {
            val store = InMemoryKeyValueStore()
            store.putStringList(key, values)
            assertEquals("key=$key", values, store.getStringList(key))
        }
    }

    @Test
    fun emptyStringListIsLegitimateDataNotMissing() {
        val store = InMemoryKeyValueStore()
        store.putStringList("courses", emptyList())

        // 空列表 ≠ 键不存在：前者是「用户真的没课」，后者是「从没写过」。
        assertEquals(emptyList<String>(), store.getStringList("courses"))
        assertNotNull(store.getStringList("courses"))
        assertNull(InMemoryKeyValueStore().getStringList("courses"))
    }

    @Test
    fun encodedListUsesJavaSerializationMagicAndLfOnlyMimeBase64() {
        val store = InMemoryKeyValueStore()
        // 足够长，保证 MIME 编码真的折行（76 字符一行）。
        val long = (1..40).map { "teacher-$it-abcdefghijklmnopqrstuvwxyz" }
        store.putStringList("teacher_records", long)

        val raw = store.rawSnapshot().getValue("flutter.teacher_records")
        assertTrue("必须带 LIST_PREFIX", raw.startsWith(FlutterPrefsCodec.LIST_PREFIX))

        val body = raw.substring(FlutterPrefsCodec.LIST_PREFIX.length)
        // flag=0 的换行是 LF：出现 CR 说明用了 DEFAULT(CRLF) 编码器，Flutter 读回会不一致。
        assertFalse("MIME flag=0 不许出现 CR", body.contains('\r'))
        assertTrue("长载荷必须按 76 列折行", body.contains('\n'))
        body.lineSequence().filter { it.isNotEmpty() }.forEach { line ->
            assertTrue("行宽不得超过 76：${line.length}", line.length <= 76)
        }

        val bytes = Base64.getMimeDecoder().decode(body)
        // Java 对象序列化流头：AC ED 00 05（独立事实，不是抄实现）。
        assertEquals(0xAC, bytes[0].toInt() and 0xFF)
        assertEquals(0xED, bytes[1].toInt() and 0xFF)
        assertEquals(0x00, bytes[2].toInt() and 0xFF)
        assertEquals(0x05, bytes[3].toInt() and 0xFF)
    }

    @Test
    fun decodeRejectsValueWithoutListPrefix() {
        try {
            FrozenValueCodec.decodeStringList("{\"not\":\"a flutter list\"}")
            fail("缺 LIST_PREFIX 必须抛，不许当空列表")
        } catch (expected: IllegalArgumentException) {
            assertTrue(expected.message!!.contains("LIST_PREFIX"))
        }
    }

    @Test
    fun getStringListThrowsOnCorruptValueInsteadOfReturningEmptyList() {
        // 契约硬要求（KeyValueStore KDoc）：解码失败要抛，空列表是合法数据，
        // 两者混起来会让坏数据被当成空课表覆盖掉。
        val store = InMemoryKeyValueStore(mapOf("courses" to "definitely-not-a-list"))

        try {
            store.getStringList("courses")
            fail("损坏值必须抛，不许静默返回空列表")
        } catch (expected: IllegalArgumentException) {
            assertTrue(expected.message!!.contains("LIST_PREFIX"))
        }
    }

    @Test
    fun getStringListPropagatesTruncatedBase64Payload() {
        // 前缀对但载荷是半截：同样属于「坏了」，必须抛而不是给半份列表。
        val store = InMemoryKeyValueStore(
            mapOf("location_records" to FlutterPrefsCodec.LIST_PREFIX + "rO0ABXNyAB"),
        )
        try {
            store.getStringList("location_records")
            fail("半截载荷必须抛")
        } catch (expected: Exception) {
            // java.io.EOFException / IllegalArgumentException 都算「坏了」。
            assertNotNull(expected)
        }
    }

    // ---------- 损坏留档 ----------

    @Test
    fun archiveCorruptAndRemoveMovesRawValueToTimestampedBackupKey() {
        val store = InMemoryKeyValueStore(mapOf("timetable_profiles" to "{broken"))
        val backupKey = store.archiveCorruptAndRemove("timetable_profiles", micros = 1_700_000_000_000_000L)

        assertEquals("timetable_profiles_corrupt_backup_1700000000000000", backupKey)
        assertEquals("{broken", store.rawSnapshot()["flutter.$backupKey"])
        assertFalse(store.contains("timetable_profiles"))
        assertTrue(store.keys().contains(backupKey))
    }

    @Test
    fun corruptBackupKeyUsesKeyThenMicros() {
        assertEquals("current_week_corrupt_backup_42", corruptBackupKey("current_week", 42L))
    }

    @Test
    fun archiveOnMissingKeyStillReturnsBackupNameWithoutWritingValue() {
        val store = InMemoryKeyValueStore()
        val backupKey = store.archiveCorruptAndRemove("timetable_settings", micros = 7L)
        assertEquals("timetable_settings_corrupt_backup_7", backupKey)
        assertNull(store.rawSnapshot()["flutter.$backupKey"])
    }
}
