package com.mutx163.qingyu.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 快照合并判据 / 冲突检测 / 内容哈希单测。
 *
 * 抄录 test/services/webdav_sync_service_test.dart 的判据全量；
 * 哈希「忽略 exportedAt/deviceId」抄录同文件 content-hash 段；
 * 人推边界：空串 remote 按缺失放行、hash 字典序平局走云端、信封版本门。
 */
class SyncConflictTest {

    private fun info(
        localMillis: Long = 1_000L,
        remoteMillis: Long = 2_000L,
        localHash: String = "local",
        remoteHash: String = "remote",
    ) = SyncConflictInfo(
        localExportedAtMillis = localMillis,
        remoteExportedAtMillis = remoteMillis,
        localHash = localHash,
        remoteHash = remoteHash,
    )

    @Test
    fun `auto resolver keeps newer side`() {
        // 抄录：local 新 → keepLocal。
        assertEquals(
            SyncConflictChoice.KEEP_LOCAL,
            resolveSyncConflictAutomatically(info(localMillis = 13_000L, remoteMillis = 12_000L)),
        )
        // 对称：remote 新 → keepRemote。
        assertEquals(
            SyncConflictChoice.KEEP_REMOTE,
            resolveSyncConflictAutomatically(info(localMillis = 12_000L, remoteMillis = 13_000L)),
        )
    }

    @Test
    fun `auto resolver tie breaks by hash compareTo`() {
        // 人推：同毫秒时 Dart `remoteHash.compareTo(localHash) >= 0 → keepRemote`。
        assertEquals(
            SyncConflictChoice.KEEP_REMOTE,
            resolveSyncConflictAutomatically(info(localMillis = 5_000L, remoteMillis = 5_000L, localHash = "a", remoteHash = "b")),
        )
        assertEquals(
            SyncConflictChoice.KEEP_LOCAL,
            resolveSyncConflictAutomatically(info(localMillis = 5_000L, remoteMillis = 5_000L, localHash = "b", remoteHash = "a")),
        )
        assertEquals(
            SyncConflictChoice.KEEP_REMOTE,
            resolveSyncConflictAutomatically(info(localMillis = 5_000L, remoteMillis = 5_000L, localHash = "same", remoteHash = "same")),
        )
    }

    @Test
    fun `background resolver never keeps local`() {
        // 抄录：后台不得静默用本地覆盖云端。
        assertEquals(
            SyncConflictChoice.KEEP_REMOTE,
            resolveSyncConflictForBackground(info(localMillis = 13_000L, remoteMillis = 12_000L)),
        )
        assertEquals(
            SyncConflictChoice.KEEP_REMOTE,
            resolveSyncConflictForBackground(info(localMillis = 12_000L, remoteMillis = 13_000L)),
        )
    }

    @Test
    fun `manual pull keeps remote without prompt when empty`() {
        assertEquals(SyncConflictChoice.KEEP_REMOTE, resolveManualPullConflictChoice(false))
        assertNull(resolveManualPullConflictChoice(true))
    }

    @Test
    fun `conflict info defaults to regular conflict`() {
        val i = info()
        assertFalse(i.isFirstSyncDivergence)
        assertFalse(i.localHasUserData)
    }

    @Test
    fun `auto upload allows when remote matches baseline`() {
        assertEquals(
            WebdavAutoUploadDecision.ALLOW,
            decideWebdavAutoUpload(
                remoteContentSha256 = "baseline",
                lastAppliedRemoteHash = "other",
                lastUploadedLocalHash = "baseline",
                localContentSha256 = "local-new",
                localHasUserAuthoredData = true,
            ),
        )
    }

    @Test
    fun `auto upload blocks drifted remote`() {
        assertEquals(
            WebdavAutoUploadDecision.REMOTE_DRIFTED,
            decideWebdavAutoUpload(
                remoteContentSha256 = "remote-other-device",
                lastAppliedRemoteHash = "baseline",
                lastUploadedLocalHash = "baseline",
                localContentSha256 = "local-new",
                localHasUserAuthoredData = true,
            ),
        )
    }

    @Test
    fun `auto upload upToDate when remote equals local`() {
        assertEquals(
            WebdavAutoUploadDecision.UP_TO_DATE,
            decideWebdavAutoUpload(
                remoteContentSha256 = "same",
                lastAppliedRemoteHash = "old",
                lastUploadedLocalHash = "old",
                localContentSha256 = "same",
                localHasUserAuthoredData = true,
            ),
        )
    }

    @Test
    fun `auto upload allows first upload when remote missing`() {
        assertEquals(
            WebdavAutoUploadDecision.ALLOW,
            decideWebdavAutoUpload(
                remoteContentSha256 = null,
                lastAppliedRemoteHash = null,
                lastUploadedLocalHash = null,
                localContentSha256 = "local",
                localHasUserAuthoredData = true,
            ),
        )
        // 人推：空串与空白同样按缺失放行。
        assertEquals(
            WebdavAutoUploadDecision.ALLOW,
            decideWebdavAutoUpload(
                remoteContentSha256 = "   ",
                lastAppliedRemoteHash = null,
                lastUploadedLocalHash = null,
                localContentSha256 = "local",
                localHasUserAuthoredData = false,
                lastUploadedHadUserData = true,
            ),
        )
    }

    @Test
    fun `auto upload blocks when local lost user data`() {
        assertEquals(
            WebdavAutoUploadDecision.LOCAL_DATA_EMPTY,
            decideWebdavAutoUpload(
                remoteContentSha256 = "baseline-with-courses",
                lastAppliedRemoteHash = "baseline-with-courses",
                lastUploadedLocalHash = "baseline-with-courses",
                localContentSha256 = "local-empty",
                localHasUserAuthoredData = false,
                lastUploadedHadUserData = true,
            ),
        )
    }

    @Test
    fun `auto upload allows settings only users`() {
        assertEquals(
            WebdavAutoUploadDecision.ALLOW,
            decideWebdavAutoUpload(
                remoteContentSha256 = "baseline-settings-only",
                lastAppliedRemoteHash = "baseline-settings-only",
                lastUploadedLocalHash = "baseline-settings-only",
                localContentSha256 = "local-settings-changed",
                localHasUserAuthoredData = false,
                lastUploadedHadUserData = false,
            ),
        )
    }

    @Test
    fun `auto upload blocks unknown flag`() {
        assertEquals(
            WebdavAutoUploadDecision.LOCAL_DATA_EMPTY,
            decideWebdavAutoUpload(
                remoteContentSha256 = "baseline",
                lastAppliedRemoteHash = "baseline",
                lastUploadedLocalHash = "baseline",
                localContentSha256 = "local-empty",
                localHasUserAuthoredData = false,
                lastUploadedHadUserData = null,
            ),
        )
    }

    @Test
    fun `auto upload blocks pull only device whose local dropped`() {
        assertEquals(
            WebdavAutoUploadDecision.LOCAL_DATA_EMPTY,
            decideWebdavAutoUpload(
                remoteContentSha256 = "cloud-v1",
                lastAppliedRemoteHash = "cloud-v1",
                lastUploadedLocalHash = null,
                localContentSha256 = "local-empty",
                localHasUserAuthoredData = false,
            ),
        )
    }

    @Test
    fun `empty local still upToDate when remote already matches`() {
        assertEquals(
            WebdavAutoUploadDecision.UP_TO_DATE,
            decideWebdavAutoUpload(
                remoteContentSha256 = "local-empty",
                lastAppliedRemoteHash = "old",
                lastUploadedLocalHash = "old",
                localContentSha256 = "local-empty",
                localHasUserAuthoredData = false,
                lastUploadedHadUserData = true,
            ),
        )
    }

    @Test
    fun `empty local allowed when no remote to protect`() {
        assertEquals(
            WebdavAutoUploadDecision.ALLOW,
            decideWebdavAutoUpload(
                remoteContentSha256 = null,
                lastAppliedRemoteHash = null,
                lastUploadedLocalHash = null,
                localContentSha256 = "local-empty",
                localHasUserAuthoredData = false,
                lastUploadedHadUserData = true,
            ),
        )
    }

    @Test
    fun `content hash ignores exportedAt and deviceId`() {
        val base = linkedMapOf<String, Any?>(
            "app" to "mikcb",
            "schemaVersion" to 2,
            "backupType" to "sync",
            "activeProfileId" to "p1",
            "profiles" to emptyList<Any?>(),
            "timeSchemes" to emptyList<Any?>(),
            "teacherRecords" to emptyList<Any?>(),
            "locationRecords" to emptyList<Any?>(),
            "warehouse" to emptyMap<String, Any?>(),
            "customHolidays" to emptyList<Any?>(),
            "partnerTimetableBinding" to null,
        )
        val aPayload = linkedMapOf<String, Any?>(*base.entries.map { it.key to it.value }.toTypedArray()).also {
            it["exportedAt"] = "2026-07-05T12:00:00.000Z"
            it["deviceId"] = "device-a"
        }
        val bPayload = linkedMapOf<String, Any?>(*base.entries.map { it.key to it.value }.toTypedArray()).also {
            it["exportedAt"] = "2026-07-05T18:00:00.000Z"
            it["deviceId"] = "device-b"
        }
        assertEquals(computeContentSha256(aPayload), computeContentSha256(bPayload))
    }

    @Test
    fun `content hash is key order insensitive`() {
        // 人推：canonicalize 先排键，不同插入序哈希一致。
        val a = linkedMapOf<String, Any?>("b" to 1, "a" to 2, "exportedAt" to "t1", "deviceId" to "d1")
        val b = linkedMapOf<String, Any?>("a" to 2, "b" to 1, "exportedAt" to "t2", "deviceId" to "d2")
        assertEquals(computeContentSha256(a), computeContentSha256(b))
    }

    @Test
    fun `content hash changes when business data changes`() {
        val a = linkedMapOf<String, Any?>("profiles" to listOf("p1"))
        val b = linkedMapOf<String, Any?>("profiles" to listOf("p2"))
        assertTrue(computeContentSha256(a) != computeContentSha256(b))
    }

    @Test
    fun `pull conflict on first sync divergence`() {
        assertTrue(
            webdavPullHasSyncConflict(
                lastUploadedLocalHash = null,
                lastAppliedRemoteHash = null,
                localContentSha256 = "local-hash",
                remoteContentSha256 = "remote-hash",
            ),
        )
        assertFalse(
            webdavPullHasSyncConflict(
                lastUploadedLocalHash = null,
                lastAppliedRemoteHash = null,
                localContentSha256 = "same-hash",
                remoteContentSha256 = "same-hash",
            ),
        )
    }

    @Test
    fun `pull requires both sides changed after baseline`() {
        assertFalse(
            webdavPullHasSyncConflict(
                lastUploadedLocalHash = "baseline",
                lastAppliedRemoteHash = "baseline",
                localContentSha256 = "local-new",
                remoteContentSha256 = "baseline",
            ),
        )
        assertTrue(
            webdavPullHasSyncConflict(
                lastUploadedLocalHash = "baseline",
                lastAppliedRemoteHash = "baseline",
                localContentSha256 = "local-new",
                remoteContentSha256 = "remote-new",
            ),
        )
    }

    @Test
    fun `background pull cancels first sync with user data`() {
        assertTrue(
            webdavBackgroundPullShouldCancel(
                lastUploadedLocalHash = null,
                lastAppliedRemoteHash = null,
                localContentSha256 = "local-hash",
                localHasUserData = true,
            ),
        )
        assertFalse(
            webdavBackgroundPullShouldCancel(
                lastUploadedLocalHash = null,
                lastAppliedRemoteHash = null,
                localContentSha256 = "local-hash",
                localHasUserData = false,
            ),
        )
    }

    @Test
    fun `background pull cancels when local changed since upload`() {
        assertTrue(
            webdavBackgroundPullShouldCancel(
                lastUploadedLocalHash = "baseline",
                lastAppliedRemoteHash = "baseline",
                localContentSha256 = "local-new",
                localHasUserData = true,
            ),
        )
        assertFalse(
            webdavBackgroundPullShouldCancel(
                lastUploadedLocalHash = "baseline",
                lastAppliedRemoteHash = "baseline",
                localContentSha256 = "baseline",
                localHasUserData = true,
            ),
        )
    }

    @Test
    fun `snapshot envelope gate checks app version type`() {
        assertTrue(isCompatibleSnapshotEnvelope("mikcb", 2, "sync"))
        assertFalse(isCompatibleSnapshotEnvelope("other", 2, "sync"))
        assertFalse(isCompatibleSnapshotEnvelope("mikcb", 1, "sync"))
        assertFalse(isCompatibleSnapshotEnvelope("mikcb", 2, "backup"))
        // 人推：Dart 对非 int 的 version 直接判不兼容。
        assertFalse(isCompatibleSnapshotEnvelopeRaw("mikcb", 2.5, "sync"))
        assertTrue(isCompatibleSnapshotEnvelopeRaw("mikcb", 2.0, "sync"))
        assertFalse(isCompatibleSnapshotEnvelopeRaw(null, 2, "sync"))
    }

    @Test
    fun `hasUserAuthoredData mirrors dart signals`() {
        val empty = SnapshotUserDataSignals()
        assertFalse(hasUserAuthoredData(empty))
        assertTrue(hasUserAuthoredData(empty.copy(teacherRecordsNotEmpty = true)))
        assertTrue(hasUserAuthoredData(empty.copy(partnerBindingPresent = true)))
        assertTrue(hasUserAuthoredData(empty.copy(profileCount = 2)))
        assertTrue(hasUserAuthoredData(empty.copy(timeSchemeCount = 2)))
        assertTrue(
            hasUserAuthoredData(
                empty.copy(timeSchemeCount = 1, timeSchemeMatchesFactoryDefault = false),
            ),
        )
        assertFalse(
            hasUserAuthoredData(
                empty.copy(timeSchemeCount = 1, timeSchemeMatchesFactoryDefault = true),
            ),
        )
        assertTrue(hasUserAuthoredData(empty.copy(profilesHaveCourses = true)))
        assertTrue(hasUserAuthoredData(empty.copy(renamedAwayFromDefaultPresent = true)))
    }

    @Test
    fun `live testing fixture ids are detected`() {
        assertTrue(isLiveTestingFixtureCourseId("live_test_abc"))
        assertFalse(isLiveTestingFixtureCourseId("course-1"))
        assertEquals(
            listOf("course-1"),
            stripLiveTestingFixtureCourseIds(listOf("live_test_a", "course-1")),
        )
    }
}
