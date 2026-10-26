package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WebdavSyncConfig 纯逻辑单测。
 *
 * 期望值来源：
 * - Dart 抄录（test/services/webdav_sync_config_test.dart、
 *   test/services/webdav_sync_service_test.dart:8-42）；
 * - 人推边界：空白文件夹回落、反斜杠 basename、单 v 前缀不相关（见 scheme）。
 */
class WebdavSyncConfigTest {

    @Test
    fun `normalizedRemoteFolder adds slashes`() {
        val bare = WebdavSyncConfig(remoteFolder = "Apps/qingyu-sync")
        assertEquals("/Apps/qingyu-sync/", bare.normalizedRemoteFolder)

        val empty = WebdavSyncConfig(remoteFolder = "   ")
        assertEquals(WebdavSyncConfig.DEFAULT_REMOTE_FOLDER, empty.normalizedRemoteFolder)

        val already = WebdavSyncConfig()
        assertEquals("/Apps/qingyu-sync/", already.normalizedRemoteFolder)
    }

    @Test
    fun `builds snapshot meta and history paths`() {
        val config = WebdavSyncConfig(remoteFolder = "Apps/qingyu-sync")
        assertEquals("/Apps/qingyu-sync/snapshot.mikcb", config.snapshotRemotePath)
        assertEquals("/Apps/qingyu-sync/snapshot.meta.json", config.metaRemotePath)
        assertEquals("/Apps/qingyu-sync/history/", config.historyRemoteFolder)
        assertEquals("/Apps/qingyu-sync/history/index.json", config.historyIndexRemotePath)
    }

    @Test
    fun `historyBackupRemotePath keeps basename only`() {
        val config = WebdavSyncConfig(remoteFolder = "Apps/qingyu-sync")
        // 抄录 service_test:18-22：穿越只留 basename。
        assertEquals(
            "/Apps/qingyu-sync/history/20260707-183045-abcdef12.mikcb",
            config.historyBackupRemotePath("20260707-183045-abcdef12.mikcb"),
        )
        assertEquals(
            "/Apps/qingyu-sync/history/safe.mikcb",
            config.historyBackupRemotePath("nested/../safe.mikcb"),
        )
    }

    @Test
    fun `sanitize keeps basename for backslash segments`() {
        // 抄录 config_test：反斜杠同样按分隔符处理。
        assertEquals(
            "file.mikcb",
            WebdavSyncConfig.sanitizeHistoryBackupFileName("folder\\file.mikcb"),
        )
        assertEquals(
            "safe.mikcb",
            WebdavSyncConfig.sanitizeHistoryBackupFileName("nested/../safe.mikcb"),
        )
    }

    @Test
    fun `sanitize rejects empty and traversal`() {
        try {
            WebdavSyncConfig.sanitizeHistoryBackupFileName("")
            throw AssertionError("expected IllegalArgumentException for empty")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.isNotEmpty())
        }
        try {
            WebdavSyncConfig.sanitizeHistoryBackupFileName("..")
            throw AssertionError("expected IllegalArgumentException for ..")
        } catch (_: IllegalArgumentException) {
        }
        try {
            WebdavSyncConfig.sanitizeHistoryBackupFileName(".")
            throw AssertionError("expected IllegalArgumentException for .")
        } catch (_: IllegalArgumentException) {
        }
    }

    @Test
    fun `historyBackupRemotePath rejects traversal root`() {
        val config = WebdavSyncConfig(remoteFolder = "Apps/qingyu-sync")
        try {
            config.historyBackupRemotePath("..")
            throw AssertionError("expected rejection")
        } catch (_: IllegalArgumentException) {
        }
        // 人推：纯穿越 "../secret.mikcb" 按 Dart 口径只留 basename（不抛）。
        assertEquals(
            "/Apps/qingyu-sync/history/secret.mikcb",
            config.historyBackupRemotePath("../secret.mikcb"),
        )
    }

    @Test
    fun `round trips through toJson fromJson`() {
        val original = WebdavSyncConfig(
            enabled = true,
            provider = WebdavSyncProvider.CUSTOM,
            syncMode = WebdavSyncMode.MANUAL,
            baseUrl = "https://dav.example.com/dav/",
            remoteFolder = "/Apps/custom/",
            username = "user@example.com",
            lastSyncedAtIso = "2026-07-01T12:00:00Z",
            lastAppliedRemoteHash = "remote-hash",
            lastUploadedLocalHash = "local-hash",
            maxBackupCount = 9,
            maxBackupAgeDays = 14,
            manualBackupProtected = false,
            lastUploadedHadUserData = true,
        )
        val restored = WebdavSyncConfig.fromJson(original.toJson())
        assertEquals(original, restored)
        assertTrue(restored.enabled)
        assertEquals(WebdavSyncProvider.CUSTOM, restored.provider)
        assertEquals(WebdavSyncMode.MANUAL, restored.syncMode)
        assertEquals("remote-hash", restored.lastAppliedRemoteHash)
        assertEquals(java.lang.Boolean.TRUE, restored.lastUploadedHadUserData)
    }

    @Test
    fun `lastUploadedHadUserData non boolean is unknown`() {
        // 抄录 config_test：字符串 "yes" 按未知（null）处理，不误拦。
        val restored = WebdavSyncConfig.fromJson(mapOf("lastUploadedHadUserData" to "yes"))
        assertNull(restored.lastUploadedHadUserData)
        val missing = WebdavSyncConfig.fromJson(emptyMap())
        assertNull(missing.lastUploadedHadUserData)
    }

    @Test
    fun `fromJson uses defaults for unknown enums and missing fields`() {
        val restored = WebdavSyncConfig.fromJson(
            mapOf("provider" to "not-a-provider", "syncMode" to "not-a-mode"),
        )
        assertFalse(restored.enabled)
        assertEquals(WebdavSyncProvider.JIANGUOYUN, restored.provider)
        assertEquals(WebdavSyncMode.AUTO, restored.syncMode)
        assertEquals(WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL, restored.baseUrl)
        assertEquals(WebdavSyncConfig.DEFAULT_REMOTE_FOLDER, restored.remoteFolder)
        assertEquals(WebdavSyncConfig.DEFAULT_MAX_BACKUP_COUNT, restored.maxBackupCount)
        assertEquals(WebdavSyncConfig.DEFAULT_MAX_BACKUP_AGE_DAYS, restored.maxBackupAgeDays)
        assertTrue(restored.manualBackupProtected)
    }

    @Test
    fun `copyWith can clear nullable sync markers`() {
        val original = WebdavSyncConfig(
            lastSyncedAtIso = "2026-07-01T00:00:00Z",
            lastAppliedRemoteHash = "a",
            lastUploadedLocalHash = "b",
            lastUploadedHadUserData = true,
        )
        val cleared = original.copyWith(
            clearLastSyncedAt = true,
            clearLastAppliedRemoteHash = true,
            clearLastUploadedLocalHash = true,
            clearLastUploadedHadUserData = true,
            enabled = true,
        )
        assertTrue(cleared.enabled)
        assertNull(cleared.lastSyncedAtIso)
        assertNull(cleared.lastAppliedRemoteHash)
        assertNull(cleared.lastUploadedLocalHash)
        assertNull(cleared.lastUploadedHadUserData)
    }

    @Test
    fun `inspect scheme grades https http invalid`() {
        assertEquals(WebdavBaseUrlScheme.HTTPS, inspectWebdavBaseUrlScheme("https://dav.example.com/dav/"))
        assertEquals(WebdavBaseUrlScheme.HTTPS, inspectWebdavBaseUrlScheme("  HTTPS://NAS.LOCAL:5006/ "))
        assertEquals(WebdavBaseUrlScheme.INSECURE_HTTP, inspectWebdavBaseUrlScheme("http://192.168.1.8:5005/dav/"))
        assertEquals(WebdavBaseUrlScheme.INSECURE_HTTP, inspectWebdavBaseUrlScheme("HTTP://nas.local/dav"))
        assertEquals(WebdavBaseUrlScheme.INVALID, inspectWebdavBaseUrlScheme("ftp://files.example.cn/dav"))
        assertEquals(WebdavBaseUrlScheme.INVALID, inspectWebdavBaseUrlScheme("file:///etc/passwd"))
        assertEquals(WebdavBaseUrlScheme.INVALID, inspectWebdavBaseUrlScheme("dav.example.com/dav/"))
        assertEquals(WebdavBaseUrlScheme.INVALID, inspectWebdavBaseUrlScheme(""))
        assertEquals(WebdavBaseUrlScheme.INVALID, inspectWebdavBaseUrlScheme("   "))
        assertEquals(
            WebdavBaseUrlScheme.HTTPS,
            inspectWebdavBaseUrlScheme(WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL),
        )
    }
}
