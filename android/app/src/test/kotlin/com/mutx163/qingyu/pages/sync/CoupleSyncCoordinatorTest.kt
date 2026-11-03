package com.mutx163.qingyu.pages.sync

import java.security.MessageDigest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣课表协调层单测（C1 · 真收发接线另一半）。
 *
 * 期望值人推：
 * - 「拉取」= GET 对端文件；拿到字节即 IMPORTED（无绑定）/ UPDATED（已有绑定）；
 * - 「内容没变就免导入」= 内容哈希与上次一致 + 已有绑定 + 非强制 → UNCHANGED（产品行为：别每次进页面都重导）；
 * - 「上传」= PUT 到我的槽位文件；落点必须是 `mineTimetableRemotePath`。
 */
class CoupleSyncCoordinatorTest {

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    @Test
    fun `首次拉取无绑定_判导入并给出内容哈希`() {
        val config = defaultCoupleConfig()
        val payload = buildCoupleBytes("v1")
        val transport = FakeRemoteTransport()
        transport.files[config.partnerTimetableRemotePath] = payload

        val outcome = CoupleSyncCoordinator(transport).pullPartnerTimetable(
            config,
            force = true,
            hasBinding = false,
        )

        assertEquals(CouplePullKind.IMPORTED, outcome.kind)
        assertArrayEquals(payload, outcome.bytes)
        assertEquals(sha256Hex(payload), outcome.contentHash)
    }

    @Test
    fun `已有绑定且内容未变_非强拉时短路为未变化`() {
        val config = defaultCoupleConfig()
        val payload = buildCoupleBytes("v1")
        val transport = FakeRemoteTransport()
        transport.files[config.partnerTimetableRemotePath] = payload
        val withBaseline = config.copyWith(lastRemoteContentHash = sha256Hex(payload))

        val outcome = CoupleSyncCoordinator(transport).pullPartnerTimetable(
            withBaseline,
            force = false,
            hasBinding = true,
        )

        assertEquals(CouplePullKind.UNCHANGED, outcome.kind)
        assertEquals(sha256Hex(payload), outcome.contentHash)
    }

    @Test
    fun `强制拉取时即便内容未变也重新导入`() {
        val config = defaultCoupleConfig()
        val payload = buildCoupleBytes("v1")
        val transport = FakeRemoteTransport()
        transport.files[config.partnerTimetableRemotePath] = payload
        val withBaseline = config.copyWith(lastRemoteContentHash = sha256Hex(payload))

        val outcome = CoupleSyncCoordinator(transport).pullPartnerTimetable(
            withBaseline,
            force = true,
            hasBinding = true,
        )

        assertEquals(CouplePullKind.UPDATED, outcome.kind)
    }

    @Test
    fun `拉取时远端缺失判失败`() {
        val outcome = CoupleSyncCoordinator(FakeRemoteTransport()).pullPartnerTimetable(defaultCoupleConfig())
        assertEquals(CouplePullKind.FAILED, outcome.kind)
        assertEquals("couple_webdav_partner_file_missing", outcome.errorCode)
        assertNull(outcome.bytes)
    }

    @Test
    fun `拉取时超时映射成安全短码`() {
        val transport = FakeRemoteTransport()
        transport.getResultOverride = com.mutx163.qingyu.sync.GetBytesResult.failed("connection_timeout")
        val outcome = CoupleSyncCoordinator(transport).pullPartnerTimetable(defaultCoupleConfig())
        assertEquals(CouplePullKind.FAILED, outcome.kind)
        assertEquals("connection_timeout", outcome.errorCode)
    }

    @Test
    fun `上传我的课表写到我的槽位文件`() {
        val config = defaultCoupleConfig()
        val payload = buildCoupleBytes("mine-v2")
        val transport = FakeRemoteTransport()

        val outcome = CoupleSyncCoordinator(transport).uploadMineTimetable(config, payload)

        assertEquals(SyncOpKind.OK, outcome.kind)
        assertEquals(config.mineTimetableRemotePath, outcome.remotePath)
        assertArrayEquals(payload, transport.files[config.mineTimetableRemotePath])
    }

    @Test
    fun `上传断线映射成安全短码`() {
        val transport = FakeRemoteTransport()
        transport.putFailureCode = "connection_failed"
        val outcome = CoupleSyncCoordinator(transport).uploadMineTimetable(defaultCoupleConfig(), buildCoupleBytes())
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("connection_failed", outcome.errorCode)
    }
}
