package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 远端路径 / ETag 比对 / 字节比对单测。
 *
 * 抄录：Dart `_versionedSnapshotRemotePath`（deviceId 清洗）、
 * `_resolveRemoteSnapshotPath`（穿越/子目录拒绝）、`_remoteMetaChanged`、
 * `_bytesEqual`、`isSecureUrl`；人推：空 deviceId 回落、相对路径拼接。
 */
class WebdavPathsTest {

    @Test
    fun `operation timeout is 30 seconds`() {
        assertEquals(30_000L, DEFAULT_OPERATION_TIMEOUT_MILLIS)
    }

    @Test
    fun `isSecureUrl checks https prefix`() {
        assertTrue(isSecureUrl("https://dav.example.com/dav/"))
        assertTrue(isSecureUrl("  HTTPS://a.b/ "))
        assertFalse(isSecureUrl("http://192.168.1.8:5005/dav/"))
        assertFalse(isSecureUrl(""))
    }

    @Test
    fun `versioned path sanitizes device id`() {
        val folder = "/Apps/qingyu-sync/"
        val path = versionedSnapshotRemotePath(
            normalizedRemoteFolder = folder,
            contentSha256 = "abc123",
            exportedAtUtcMicros = 1_750_000_000_000_000L,
            deviceId = "my/phone:01",
        )
        assertTrue(path.startsWith(folder + "snapshot-abc123-1750000000000000-"))
        assertTrue(path.endsWith(".mikcb"))
        assertFalse(path.contains("/phone"))
        assertTrue(path.contains("my_phone_01"))
    }

    @Test
    fun `versioned path falls back for empty device`() {
        val empty = versionedSnapshotRemotePath(
            normalizedRemoteFolder = "/Apps/qingyu-sync/",
            contentSha256 = "h",
            exportedAtUtcMicros = 7L,
            deviceId = "",
        )
        assertTrue(empty.contains("-device.mikcb"))
        // 人推修正：Dart 只判空串回落，空白按字符清洗为下划线（"  " → "__"）。
        val blank = versionedSnapshotRemotePath(
            normalizedRemoteFolder = "/Apps/qingyu-sync/",
            contentSha256 = "h",
            exportedAtUtcMicros = 7L,
            deviceId = "  ",
        )
        assertTrue(blank.contains("-__.mikcb"))
    }

    @Test
    fun `resolve remote snapshot path validates traversal`() {
        val folder = "/Apps/qingyu-sync/"
        val legacy = folder + "snapshot.mikcb"
        // 空按 legacy 回落（Dart 原样）。
        assertEquals(legacy, resolveRemoteSnapshotPath(folder, legacy, null))
        assertEquals(legacy, resolveRemoteSnapshotPath(folder, legacy, "   "))
        // 相对名拼到 folder 下。
        assertEquals(
            folder + "snapshot-abc.mikcb",
            resolveRemoteSnapshotPath(folder, legacy, "snapshot-abc.mikcb"),
        )
        // 绝对路径在 folder 内放行。
        assertEquals(
            folder + "snapshot-abc.mikcb",
            resolveRemoteSnapshotPath(folder, legacy, folder + "snapshot-abc.mikcb"),
        )
        // 穿越 / 反斜杠 / 子目录一律拒绝。
        assertNull(resolveRemoteSnapshotPath(folder, legacy, folder + "../evil.mikcb"))
        assertNull(resolveRemoteSnapshotPath(folder, legacy, folder + "a/b.mikcb"))
        assertNull(resolveRemoteSnapshotPath(folder, legacy, folder + "a\\b.mikcb"))
        assertNull(resolveRemoteSnapshotPath(folder, legacy, "/other/snapshot-abc.mikcb"))
        assertNull(resolveRemoteSnapshotPath(folder, legacy, folder))
    }

    @Test
    fun `remote meta change detects etag and content drift`() {
        val before = RemoteMetaState(
            isNotFound = false,
            metaPresent = true,
            contentSha256 = "h1",
            deviceId = "d1",
            exportedAtMillis = 100L,
            snapshotPath = "p1",
            etag = "e1",
        )
        // 全同 → 未变。
        assertFalse(remoteMetaChanged(before, before.copy()))
        // etag 变 → 变了。
        assertTrue(remoteMetaChanged(before, before.copy(etag = "e2")))
        // 内容 hash 变 → 变了。
        assertTrue(remoteMetaChanged(before, before.copy(contentSha256 = "h2")))
        // notFound 翻转 → 变了；双 notFound → 未变。
        assertTrue(
            remoteMetaChanged(
                before,
                before.copy(isNotFound = true, metaPresent = false),
            ),
        )
        val missing = RemoteMetaState(isNotFound = true, metaPresent = false)
        assertFalse(remoteMetaChanged(missing, missing.copy()))
        // meta 现/失 → 变了。
        assertTrue(remoteMetaChanged(before, before.copy(metaPresent = false)))
    }

    @Test
    fun `bytes equal compares content`() {
        assertTrue(bytesEqual(byteArrayOf(1, 2, 3), byteArrayOf(1, 2, 3)))
        assertFalse(bytesEqual(byteArrayOf(1, 2), byteArrayOf(1, 2, 3)))
        assertFalse(bytesEqual(byteArrayOf(1, 2, 3), byteArrayOf(1, 2, 4)))
        assertTrue(bytesEqual(byteArrayOf(), byteArrayOf()))
    }

    @Test
    fun `couple pull unchanged gate mirrors dart`() {
        // Dart：!force && lastHash == contentHash && hasBinding → unchanged 跳过。
        assertTrue(shouldSkipCouplePullAsUnchanged("abc", "abc", force = false, hasPartnerBinding = true))
        assertFalse(shouldSkipCouplePullAsUnchanged("abc", "abc", force = true, hasPartnerBinding = true))
        assertFalse(shouldSkipCouplePullAsUnchanged("abc", "abc", force = false, hasPartnerBinding = false))
        assertFalse(shouldSkipCouplePullAsUnchanged("old", "new", force = false, hasPartnerBinding = true))
        assertFalse(shouldSkipCouplePullAsUnchanged(null, "new", force = false, hasPartnerBinding = true))
    }
}
