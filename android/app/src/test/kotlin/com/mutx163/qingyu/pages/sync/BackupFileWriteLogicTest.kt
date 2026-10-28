package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.canonicalJson
import com.mutx163.qingyu.sync.canonicalize
import com.mutx163.qingyu.sync.computeContentSha256
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 备份文件写出模型测试（C2「备份还原页」的**写出半边**）。
 *
 * 期望值全部**人推**，不从实现里抄：
 *
 * - 「往返」用一份真实的同步快照负载：写→读回来后逐键相等、校验通过（整型统一用 [Long]，
 *   与 `MiniJson.parse` 的产物类型一致，避免 Int/Long 装箱差异制造的假失败）。
 * - 「校验和链」用**手写 canonical 字符串 + 独立 [MessageDigest]** 锚定，走与生产
 *   `canonicalize`+`canonicalJson` 不同的路径，两边对上才算哈希没走歪。
 * - 失败分类（信封坏 / 缺必需字段 / 空课表 / 太大）各有独立用例。
 */
class BackupFileWriteLogicTest {

    // ==========================================================
    // 一份真实的同步快照负载（整型用 Long、带小数用 Double，模拟 MiniJson.parse 的产物类型）
    // ==========================================================
    private fun realisticPayload(): LinkedHashMap<String, Any?> = linkedMapOf(
        "app" to "mikcb",
        "schemaVersion" to 2L,
        "backupType" to "sync",
        "exportedAt" to "2026-10-28T16:20:00.000",
        "deviceId" to "device-c2-saf",
        "activeProfileId" to "p1",
        "profiles" to listOf(
            linkedMapOf<String, Any?>(
                "id" to "p1",
                "name" to "默认课表",
                "courses" to listOf(
                    linkedMapOf<String, Any?>(
                        "id" to "c1",
                        "name" to "高等数学",
                        "dayOfWeek" to 1L,
                        "startSection" to 1L,
                        "endSection" to 2L,
                        "credit" to 3.5,
                    ),
                ),
            ),
        ),
        "timeSchemes" to listOf(
            linkedMapOf<String, Any?>("id" to "t1", "name" to "默认作息"),
        ),
        "locationTimeGroups" to emptyList<Any?>(),
        "scheduleDateRules" to emptyList<Any?>(),
        "scheduleDateRuleLastAppliedSignature" to null,
        "teacherRecords" to listOf("张老师"),
        "locationRecords" to emptyList<Any?>(),
        "warehouse" to linkedMapOf<String, Any?>("macros" to emptyList<Any?>()),
        "customHolidays" to emptyList<Any?>(),
        "partnerTimetableBinding" to null,
    )

    private fun writeOk(
        snapshot: Map<String, Any?>,
        declaredSha256: String? = null,
        maxBytes: Int = BackupFileWriteLogic.MAX_FILE_BYTES,
    ): WriteSuccess {
        val result = BackupFileWriteLogic.write(snapshot, declaredSha256, maxBytes)
        assertTrue("期望写出成功，实际=$result", result is WriteSuccess)
        return result as WriteSuccess
    }

    // ==========================================================
    // 1. 往返：写 → 读 逐键相等 + 校验通过
    // ==========================================================

    @Test
    fun `写出的备份能被读模型读回且负载逐键相等`() {
        val payload = realisticPayload()
        val written = writeOk(payload)

        // 自带非空哈希（默认走重算）
        assertTrue(written.checksumEmbedded)
        assertEquals(64, written.embeddedSha256.length)
        assertFalse(written.checksumDrift)
        assertEquals(BackupFileReadLogic.utf8ByteLength(written.content), written.byteLength)

        val read = BackupFileReadLogic.read(written.content)
        assertTrue("期望读回成功，实际=$read", read is BackupFileReadResult.Success)
        read as BackupFileReadResult.Success

        // 负载逐键相等（read 去掉 contentSha256 后应与原负载完全一致）
        assertEquals(payload, read.snapshot)
        assertFalse(read.snapshot.containsKey("contentSha256"))

        // 校验和与元数据
        assertTrue(read.checksumVerified)
        assertEquals(written.embeddedSha256, read.meta.contentSha256)
        assertEquals("2026-10-28T16:20:00.000", read.meta.exportedAtIso)
        assertFalse(read.meta.exportedAtUnparsed)
        assertEquals("device-c2-saf", read.meta.deviceId)
        assertNull(read.meta.appVersion)
        assertNull(read.meta.snapshotPath)
    }

    @Test
    fun `写出的文本是缩进 JSON 且解析后与原负载一致`() {
        val payload = realisticPayload()
        val written = writeOk(payload)

        // 缩进形态（真两空格 + 换行），且键值分隔是 "key": value
        assertTrue("应有换行", written.content.contains("\n"))
        assertTrue("应有缩进", written.content.contains("\n  \"app\": \"mikcb\""))

        val reparsed = MiniJson.parse(written.content) as Map<*, *>
        val body = LinkedHashMap(reparsed)
        body.remove("contentSha256")
        assertEquals(payload, body)
    }

    @Test
    fun `序列化不改类型：整数读回是 Long、小数读回是 Double`() {
        val written = writeOk(realisticPayload())
        val parsed = MiniJson.parse(written.content) as Map<*, *>

        assertEquals(2L, parsed["schemaVersion"])
        val profile = (parsed["profiles"] as List<*>).first() as Map<*, *>
        val course = (profile["courses"] as List<*>).first() as Map<*, *>
        assertEquals(1L, course["dayOfWeek"])
        assertEquals(3.5, course["credit"] as Double, 0.0)
    }

    // ==========================================================
    // 2. 校验和链的独立锚点：手写 canonical 字符串 + 独立 MessageDigest
    // ==========================================================

    @Test
    fun `校验和与手写 canonical 字符串独立算出的一致`() {
        // 最小合法负载（整型 2L 的 canonical 形态是 "2"，与手写一致）
        val minimal = linkedMapOf<String, Any?>(
            "app" to "mikcb",
            "schemaVersion" to 2L,
            "backupType" to "sync",
            "exportedAt" to "2026-03-07T09:05:30.000",
            "deviceId" to "device-1",
            "profiles" to listOf(linkedMapOf<String, Any?>("id" to "p1", "name" to "默认")),
            "timeSchemes" to listOf(linkedMapOf<String, Any?>("id" to "t1", "name" to "默认作息")),
        )
        val written = writeOk(minimal)

        // 手写 canonical：键升序、紧凑、非 ASCII 不转义；exportedAt/deviceId/contentSha256 不进哈希
        val handwrittenCanonical =
            """{"app":"mikcb","backupType":"sync","profiles":[{"id":"p1","name":"默认"}],""" +
                """"schemaVersion":2,"timeSchemes":[{"id":"t1","name":"默认作息"}]}"""
        // 进哈希的负载：先滤掉 exportedAt / deviceId / contentSha256，再 canonicalize（与 Dart 同序）
        val forHash = minimal.filterKeys { it != "exportedAt" && it != "deviceId" && it != "contentSha256" }
        assertEquals(handwrittenCanonical, canonicalJson(canonicalize(forHash)))
        assertEquals(sha256Hex(handwrittenCanonical), written.embeddedSha256)
        assertEquals(sha256Hex(handwrittenCanonical), computeContentSha256(minimal))
    }

    @Test
    fun `重编码一次后哈希不变`() {
        val written = writeOk(realisticPayload())
        // 读回的 JSON 再算一遍哈希，必须与写进文件的一致（否则读侧必报校验失败）
        val parsed = MiniJson.parse(written.content) as Map<String, Any?>
        assertEquals(written.embeddedSha256, computeContentSha256(parsed))
    }

    // ==========================================================
    // 3. declaredSha256 的三种语义
    // ==========================================================

    @Test
    fun `声明哈希与内容不符时改用重算值并标记漂移`() {
        val payload = realisticPayload()
        val honest = writeOk(payload).embeddedSha256

        val written = writeOk(payload, declaredSha256 = "deadbeefdeadbeef")
        assertTrue("应标记漂移", written.checksumDrift)
        assertEquals("应改用重算值", honest, written.embeddedSha256)
        assertTrue(written.content.contains("\"contentSha256\": \"$honest\""))

        val read = BackupFileReadLogic.read(written.content) as BackupFileReadResult.Success
        assertTrue(read.checksumVerified)
    }

    @Test
    fun `声明哈希与内容一致时原样采用且不标记漂移`() {
        val payload = realisticPayload()
        val honest = writeOk(payload).embeddedSha256

        val written = writeOk(payload, declaredSha256 = honest)
        assertFalse(written.checksumDrift)
        assertEquals(honest, written.embeddedSha256)
    }

    @Test
    fun `声明空串表示刻意不带哈希`() {
        val payload = realisticPayload()
        val written = writeOk(payload, declaredSha256 = "")

        assertFalse(written.checksumEmbedded)
        assertEquals("", written.embeddedSha256)
        assertTrue(written.content.contains("\"contentSha256\": \"\""))

        val read = BackupFileReadLogic.read(written.content) as BackupFileReadResult.Success
        assertFalse("没带哈希 → 跳过校验", read.checksumVerified)
        assertEquals("", read.meta.contentSha256)
        assertEquals(payload, read.snapshot)
    }

    @Test
    fun `输入自带旧哈希会被剥掉并重算`() {
        val polluted = realisticPayload().apply { this["contentSha256"] = "stale-value" }
        val honest = writeOk(realisticPayload()).embeddedSha256

        val written = writeOk(polluted)
        assertEquals("旧哈希不能透传", honest, written.embeddedSha256)
        assertFalse(written.content.contains("stale-value"))

        val read = BackupFileReadLogic.read(written.content) as BackupFileReadResult.Success
        assertTrue(read.checksumVerified)
        assertFalse(read.snapshot.containsKey("contentSha256"))
    }

    // ==========================================================
    // 4. 自检门：写不出一份读不回的备份
    // ==========================================================

    private fun failureOf(snapshot: Map<String, Any?>): WriteFailure {
        val result = BackupFileWriteLogic.write(snapshot)
        assertTrue("期望写出失败，实际=$result", result is WriteFailure)
        return result as WriteFailure
    }

    @Test
    fun `app 不是 mikcb 时拒绝写出`() {
        val payload = realisticPayload().apply { this["app"] = "other" }
        assertEquals(BackupFileWriteFailureKind.ENVELOPE_UNRECOGNIZED, failureOf(payload).kind)
    }

    @Test
    fun `schemaVersion 不是 2 时拒绝写出`() {
        val payload = realisticPayload().apply { this["schemaVersion"] = 3L }
        assertEquals(BackupFileWriteFailureKind.ENVELOPE_UNRECOGNIZED, failureOf(payload).kind)
    }

    @Test
    fun `backupType 不是 sync 时拒绝写出`() {
        val payload = realisticPayload().apply { this["backupType"] = "full" }
        assertEquals(BackupFileWriteFailureKind.ENVELOPE_UNRECOGNIZED, failureOf(payload).kind)
    }

    @Test
    fun `profiles 不是数组时拒绝写出`() {
        val payload = realisticPayload().apply { this["profiles"] = "not-a-list" }
        assertEquals(BackupFileWriteFailureKind.MISSING_REQUIRED_FIELDS, failureOf(payload).kind)
    }

    @Test
    fun `timeSchemes 不是数组时拒绝写出`() {
        val payload = realisticPayload().apply { this["timeSchemes"] = 42L }
        assertEquals(BackupFileWriteFailureKind.MISSING_REQUIRED_FIELDS, failureOf(payload).kind)
    }

    @Test
    fun `一张课表都没有时拒绝写出`() {
        val payload = realisticPayload().apply { this["profiles"] = emptyList<Any?>() }
        val failure = failureOf(payload)
        assertEquals(BackupFileWriteFailureKind.NO_PROFILES, failure.kind)
        assertTrue(failure.detail.contains("profiles=0"))
    }

    @Test
    fun `超过字节上限时拒绝写出`() {
        val result = BackupFileWriteLogic.write(realisticPayload(), maxBytes = 10)
        assertTrue(result is WriteFailure)
        assertEquals(BackupFileWriteFailureKind.TOO_LARGE, (result as WriteFailure).kind)
        assertTrue(result.detail.contains("limit=10"))
    }

    // ==========================================================
    // 小工具
    // ==========================================================

    private fun sha256Hex(text: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
