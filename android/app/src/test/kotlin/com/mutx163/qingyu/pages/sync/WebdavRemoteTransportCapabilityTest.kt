package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.GetBytesResult
import com.mutx163.qingyu.sync.HistoryListResult
import com.mutx163.qingyu.sync.LockResult
import com.mutx163.qingyu.sync.WebdavHeadResult
import com.mutx163.qingyu.sync.WebdavWriteResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 条件写 / 锁能力的**接口默认值契约**（协议互通第 1 段）。
 *
 * 钉住的事情：`WebdavRemoteTransport` 新增的三个方法（`putBytesConditional` /
 * `acquireWriteLock` / `releaseWriteLock`）对**没有覆盖它们**的实现必须完全透明——
 * 情侣同步的假实现（`CoupleTimetableSettingsControllerTest.FakeTransport`）与生产
 * 之外的任何旧实现，不改动一个字也必须编译通过、行为与加能力之前一致。
 * 这是「情侣同步不退化」的机器判据之一（另一判据：CoupleSyncCoordinatorTest 全绿）。
 */
class WebdavRemoteTransportCapabilityTest {

    /** 只实现原来 8 个动作的最小实现（与情侣测试假实现同构，刻意不加新方法）。 */
    private class LegacyOnlyFake : WebdavRemoteTransport {
        val files = LinkedHashMap<String, ByteArray>()
        var putCalls = 0
        override fun listHistoryBackupFiles(historyRemoteFolder: String): HistoryListResult =
            HistoryListResult.ok(emptyList())
        override fun getBytes(remotePath: String): GetBytesResult =
            files[remotePath]?.let { GetBytesResult.ok(it) } ?: GetBytesResult.notFound()
        override fun putBytes(remotePath: String, bytes: ByteArray): WebdavWriteResult {
            putCalls++
            files[remotePath] = bytes
            return WebdavWriteResult.ok(201, null)
        }
        override fun getRemoteEtag(remotePath: String): String? = null
        override fun ensureRemoteFolder(remoteFolder: String): WebdavWriteResult =
            WebdavWriteResult.ok(200, null)
        override fun head(remotePath: String): WebdavHeadResult = WebdavHeadResult.missing(404)
        override fun testConnection(): String? = null
        override fun deleteRemoteFile(remotePath: String): WebdavWriteResult =
            WebdavWriteResult.ok(204, null)
    }

    @Test
    fun `默认条件写丢弃条件头_等价普通PUT`() {
        val fake = LegacyOnlyFake()

        val result = fake.putBytesConditional(
            "/Apps/x/snapshot.meta.json",
            byteArrayOf(1),
            headers = mapOf("If-Match" to "stale-etag"),
            lockToken = "opaquelocktoken:some",
        )

        assertTrue(!result.isFailed)
        assertEquals(1, fake.putCalls)
        assertTrue(fake.files.containsKey("/Apps/x/snapshot.meta.json"))
    }

    @Test
    fun `默认取锁返回不支持_默认放锁是失败值但不可达`() {
        val fake = LegacyOnlyFake()

        val lock = fake.acquireWriteLock("/Apps/x/")

        assertTrue(lock.isUnsupported)
        assertNull(lock.lockToken)
        // 没拿到锁就没有 token，调用方不会走 release；默认值仅为编译完备。
        assertTrue(fake.releaseWriteLock("/Apps/x/", "any").isFailed)
    }

    @Test
    fun `假传输_锁关闭时条件PUT仍落文件_与今天一致`() {
        val transport = FakeRemoteTransport() // lockSupported 默认 false

        assertTrue(!transport.putBytesConditional("/p", byteArrayOf(1)).isFailed)
        assertTrue(transport.acquireWriteLock("/Apps/x/").isUnsupported)
        assertNotNull(transport.files["/p"])
        assertNull(transport.lastConditionalPutLockToken)
    }

    @Test
    fun `假传输_锁开启时能取到锁并释放`() {
        val transport = FakeRemoteTransport().apply { lockSupported = true }

        val lock = transport.acquireWriteLock("/Apps/x/")

        assertTrue(!lock.isFailed && !lock.isUnsupported)
        assertEquals(lock.lockToken, transport.heldLockToken)
        val release = transport.releaseWriteLock("/Apps/x/", lock.lockToken!!)
        assertTrue(!release.isFailed)
        assertNull(transport.heldLockToken)
    }

    @Test
    fun `假传输_锁冲突是硬失败不是不支持`() {
        val transport = FakeRemoteTransport().apply {
            lockSupported = true
            lockConflict = true
        }

        val lock = transport.acquireWriteLock("/Apps/x/")

        assertTrue(lock.isFailed)
        assertEquals("access_denied", lock.errorMessage)
    }

    @Test
    fun `假传输_条件PUT记录条件头与token供冲突测试检视`() {
        val transport = FakeRemoteTransport()

        transport.putBytesConditional(
            "/meta",
            byteArrayOf(1),
            headers = mapOf("If-None-Match" to "*"),
            lockToken = "tok",
        )

        assertEquals(mapOf("If-None-Match" to "*"), transport.lastConditionalPutHeaders)
        assertEquals("tok", transport.lastConditionalPutLockToken)
    }
}
