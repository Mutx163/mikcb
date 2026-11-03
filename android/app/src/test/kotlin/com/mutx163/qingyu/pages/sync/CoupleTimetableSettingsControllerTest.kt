package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.GetBytesResult
import com.mutx163.qingyu.sync.HistoryListResult
import com.mutx163.qingyu.sync.WebdavHeadResult
import com.mutx163.qingyu.sync.WebdavWriteResult
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 情侣课表控制器（源：`lib/services/couple_webdav_service.dart` 的
 * `pullPartnerTimetable` / `uploadMyTimetableForPartner` / `connect` / `disconnect`
 * + 页面九个 `_xxx` 方法）。
 *
 * 这里钉的全是**用户看得见的差别**：错误码归到哪一条文案、「无变化」会不会重导入、
 * 落盘失败会不会假装成功、周偏移会不会越界。
 */
class CoupleTimetableSettingsControllerTest {

    // ── 测试替身 ──

    private class FakeConfigStore(
        var config: CoupleWebdavConfig = CoupleWebdavConfig(),
        var password: String? = null,
    ) : CoupleConfigStorePort {
        var saveCount = 0
        var failSave = false
        override fun loadConfig(): CoupleWebdavConfig = config
        override fun saveConfig(config: CoupleWebdavConfig) {
            if (failSave) throw IllegalStateException("disk_full")
            this.config = config
            saveCount++
        }
        override fun hasStoredPassword(): Boolean = !password.isNullOrEmpty()
        override fun readPassword(): String? = password
        override fun storePassword(password: String) {
            this.password = password
        }
        override fun clearPassword() {
            password = null
        }
    }

    private class FakePartnerPort(
        var binding: PartnerTimetableBindingModel? = null,
        var courses: Int = 0,
        var profileName: String? = null,
        var week: Int = 3,
    ) : CouplePartnerPort {
        var importCalls = 0
        var importOutcome: () -> CoupleImportOutcome = { CoupleImportOutcome(updated = true, droppedTotal = 0) }
        var buildCalls = 0
        var failSave = false
        var notifyCount = 0
        var unlinkCount = 0
        override fun loadBinding(): PartnerTimetableBindingModel? = binding
        override fun saveBinding(binding: PartnerTimetableBindingModel) {
            if (failSave) throw IllegalStateException("disk_full")
            this.binding = binding
        }
        override fun unlink() {
            unlinkCount++
            binding = null
            courses = 0
            profileName = null
        }
        override fun partnerCourseCount(): Int = courses
        override fun partnerProfileName(): String? = profileName
        override fun importPackage(content: String): CoupleImportOutcome {
            importCalls++
            return importOutcome()
        }
        override fun buildMyPackage(): String {
            buildCalls++
            return "{\"app\":\"mikcb\"}"
        }
        override fun currentWeek(): Int = week
        override fun notifyTimetableChanged() {
            notifyCount++
        }
    }

    private class FakeTransport : WebdavRemoteTransport {
        var getResult: GetBytesResult = GetBytesResult.notFound()
        var putResult: WebdavWriteResult = WebdavWriteResult.ok(201, null)
        var folderResult: WebdavWriteResult = WebdavWriteResult.ok(201, null)
        var testFailure: String? = null
        var getCalls = 0
        var putCalls = 0
        override fun listHistoryBackupFiles(historyRemoteFolder: String): HistoryListResult =
            HistoryListResult()
        override fun getBytes(remotePath: String): GetBytesResult {
            getCalls++
            return getResult
        }
        override fun putBytes(remotePath: String, bytes: ByteArray): WebdavWriteResult {
            putCalls++
            return putResult
        }
        override fun getRemoteEtag(remotePath: String): String? = null
        override fun ensureRemoteFolder(remoteFolder: String): WebdavWriteResult = folderResult
        override fun head(remotePath: String): WebdavHeadResult = WebdavHeadResult.missing(404)
        override fun testConnection(): String? = testFailure
        override fun deleteRemoteFile(remotePath: String): WebdavWriteResult =
            WebdavWriteResult.ok(204, null)
    }

    private val connectedConfig = CoupleWebdavConfig(username = "me@example.com", mySlot = 1)

    private fun controller(
        configStore: FakeConfigStore = FakeConfigStore(config = connectedConfig, password = "pw"),
        partnerPort: FakePartnerPort = FakePartnerPort(),
        transport: FakeTransport = FakeTransport(),
        exported: MutableList<Pair<String, String>> = mutableListOf(),
    ): CoupleTimetableSettingsController = CoupleTimetableSettingsController(
        configStore = configStore,
        partnerPort = partnerPort,
        transportFactory = { _, _ -> transport },
        exportSink = { content, fileName ->
            exported.add(content to fileName)
            true
        },
        nowIso = { "2026-10-29T12:00:00.000" },
        nowMicros = { 1_700_000_000_000_000L },
        packageSalt = { 42 },
        zone = ZoneId.of("Asia/Shanghai"),
    )

    // ── 拉取 ──

    @Test
    fun pullWithoutCredentialsReportsNotConnected() {
        val toast = controller(
            configStore = FakeConfigStore(config = CoupleWebdavConfig(), password = null),
        ).pullNow()
        assertEquals(CoupleStrings.coupleWebdavNotConnectedError.zh, toast.message)
        assertTrue(toast.isError)
    }

    @Test
    fun pullMissingRemoteFileReportsPartnerFileMissing() {
        val transport = FakeTransport().apply { getResult = GetBytesResult.notFound() }
        val toast = controller(transport = transport).pullNow()
        assertEquals(CoupleStrings.coupleWebdavPartnerFileMissing.zh, toast.message)
        assertTrue(toast.isError)
    }

    @Test
    fun pullFullBackupIsRejected() {
        val transport = FakeTransport().apply {
            getResult = GetBytesResult.ok(
                "{\"backupType\":\"full\"}".toByteArray(Charsets.UTF_8),
            )
        }
        val partner = FakePartnerPort()
        val toast = controller(partnerPort = partner, transport = transport).pullNow()
        assertEquals(CoupleStrings.partnerImportRequiresSingleProfile.zh, toast.message)
        assertEquals(0, partner.importCalls)
    }

    @Test
    fun pullNonJsonIsRejected() {
        val transport = FakeTransport().apply {
            getResult = GetBytesResult.ok("<html>404</html>".toByteArray(Charsets.UTF_8))
        }
        val partner = FakePartnerPort()
        val toast = controller(partnerPort = partner, transport = transport).pullNow()
        // 裁决：不复刻 Dart 的折叠口径（Dart 这里显示「发生未知错误」）。
        // 非 JSON 的对方包按「文件无效」提示，复用既有 `importFailedInvalidFile` 键。
        assertEquals(CoupleStrings.importFailedInvalidFile.zh, toast.message)
        assertEquals(0, partner.importCalls)
    }

    @Test
    fun pullInvalidUtf8IsRejected() {
        val transport = FakeTransport().apply {
            // 0xFF 在 UTF-8 里不合法；比「当成课表导入」更该被拒。
            getResult = GetBytesResult.ok(byteArrayOf(0xFF.toByte(), 0xFE.toByte()))
        }
        val partner = FakePartnerPort()
        val toast = controller(partnerPort = partner, transport = transport).pullNow()
        assertEquals(CoupleStrings.importFailedInvalidFile.zh, toast.message)
        assertEquals(0, partner.importCalls)
    }

    @Test
    fun pullImportsAndPersistsHashAndTimestamp() {
        val content = "{\"app\":\"mikcb\",\"courses\":[]}"
        val transport = FakeTransport().apply {
            getResult = GetBytesResult.ok(content.toByteArray(Charsets.UTF_8))
        }
        val store = FakeConfigStore(config = connectedConfig, password = "pw")
        val partner = FakePartnerPort()
        val toast = controller(configStore = store, partnerPort = partner, transport = transport).pullNow()

        assertEquals(CoupleStrings.coupleWebdavPullUpdated.zh, toast.message)
        assertEquals(1, partner.importCalls)
        assertEquals("2026-10-29T12:00:00.000", store.config.lastPulledAtIso)
        // 内容哈希必须落盘，否则下一次拉取永远短路不到「无变化」。
        assertEquals(WebdavSyncCoordinator.rawSha256Hex(content.toByteArray(Charsets.UTF_8)),
            store.config.lastRemoteContentHash)
    }

    @Test
    fun pullSkipsWhenHashUnchangedAndBound() {
        val content = "{\"app\":\"mikcb\",\"courses\":[]}"
        val hash = WebdavSyncCoordinator.rawSha256Hex(content.toByteArray(Charsets.UTF_8))
        val store = FakeConfigStore(
            config = connectedConfig.copyWith(lastRemoteContentHash = hash),
            password = "pw",
        )
        val transport = FakeTransport().apply {
            getResult = GetBytesResult.ok(content.toByteArray(Charsets.UTF_8))
        }
        val partner = FakePartnerPort(binding = PartnerTimetableBindingModel(partnerName = "小屿"))
        val toast = controller(configStore = store, partnerPort = partner, transport = transport).pullNow()

        assertEquals(CoupleStrings.coupleWebdavPullUnchanged.zh, toast.message)
        assertEquals(0, partner.importCalls)
    }

    @Test
    fun pullBusyStateExposesEllipsisLabel() {
        val transport = FakeTransport().apply {
            getResult = GetBytesResult.ok("{\"app\":\"mikcb\"}".toByteArray(Charsets.UTF_8))
        }
        val c = controller(transport = transport)
        c.pullNow()
        // 动作结束后忙碌态必须复位，否则按钮永远停在「...」且不可点。
        val labels = c.viewState().webdavButtons.map { it.label }
        assertFalse(labels.any { it.endsWith("...") })
        assertTrue(c.viewState().webdavButtons.all { it.enabled })
    }

    // ── 上传 ──

    @Test
    fun uploadWithoutCredentialsReportsNotConnected() {
        val toast = controller(
            configStore = FakeConfigStore(config = CoupleWebdavConfig(), password = null),
        ).uploadMine()
        assertEquals(CoupleStrings.coupleWebdavNotConnectedError.zh, toast.message)
    }

    @Test
    fun uploadSuccessUsesArbCopy() {
        val transport = FakeTransport()
        val partner = FakePartnerPort()
        val toast = controller(partnerPort = partner, transport = transport).uploadMine()
        assertEquals(CoupleStrings.coupleWebdavUploadSuccess.zh, toast.message)
        assertEquals(1, partner.buildCalls)
        assertEquals(1, transport.putCalls)
    }

    @Test
    fun uploadFailureMapsErrorCode() {
        val transport = FakeTransport().apply {
            putResult = WebdavWriteResult.failed("sync_network_timeout")
        }
        val toast = controller(transport = transport).uploadMine()
        assertTrue(toast.isError)
        assertTrue("错误码要落到人话，实际=${toast.message}", toast.message != "sync_network_timeout")
    }

    // ── 连接 / 断开 ──

    @Test
    fun connectFailsWhenTestConnectionFails() {
        val store = FakeConfigStore(config = CoupleWebdavConfig(), password = null)
        val transport = FakeTransport().apply { testFailure = "unauthorized" }
        val outcome = controller(configStore = store, transport = transport)
            .connect("me@example.com", "pw", 2)
        assertFalse(outcome.ok)
        assertNull(store.password)
    }

    @Test
    fun connectStoresCredentialsAndPullsOnce() {
        val store = FakeConfigStore(config = CoupleWebdavConfig(), password = null)
        val transport = FakeTransport().apply {
            getResult = GetBytesResult.notFound()
        }
        val outcome = controller(configStore = store, transport = transport)
            .connect(" me@example.com ", "pw", 2)

        assertTrue(outcome.ok)
        assertEquals("pw", store.password)
        assertEquals("me@example.com", store.config.username)
        assertEquals(2, store.config.mySlot)
        // 连接成功会串一次拉取：远端没有对方文件时那句「未找到对方课表文件」就是它的结局。
        assertEquals(CoupleStrings.coupleWebdavPartnerFileMissing.zh, outcome.pullToast?.message)
    }

    @Test
    fun disconnectClearsConfigAndPassword() {
        val store = FakeConfigStore(
            config = connectedConfig.copyWith(lastPulledAtIso = "2026-10-29T10:00:00.000"),
            password = "pw",
        )
        val toast = controller(configStore = store).disconnect()
        assertNull(toast)
        assertEquals("", store.config.username)
        assertNull(store.config.lastPulledAtIso)
        assertNull(store.password)
    }

    @Test
    fun disconnectReportsSaveFailure() {
        val store = FakeConfigStore(config = connectedConfig, password = "pw").apply { failSave = true }
        val toast = controller(configStore = store).disconnect()
        assertEquals(CoupleStrings.saveFailed.zh, toast?.message)
    }

    // ── 周偏移 / 换色 ──

    @Test
    fun shiftWeekOffsetClampsAtUpperBound() {
        val partner = FakePartnerPort(binding = PartnerTimetableBindingModel(partnerName = "小屿", weekOffset = 15))
        val toast = controller(partnerPort = partner).shiftWeekOffset(3)
        assertNull(toast)
        assertEquals(15, partner.binding?.weekOffset)
    }

    @Test
    fun shiftWeekOffsetWritesAndNotifies() {
        val partner = FakePartnerPort(binding = PartnerTimetableBindingModel(partnerName = "小屿", weekOffset = 0))
        val toast = controller(partnerPort = partner).shiftWeekOffset(-2)
        assertNull(toast)
        assertEquals(-2, partner.binding?.weekOffset)
        assertEquals(1, partner.notifyCount)
    }

    @Test
    fun shiftWeekOffsetFailureKeepsOldValue() {
        val partner = FakePartnerPort(
            binding = PartnerTimetableBindingModel(partnerName = "小屿", weekOffset = 1),
        )
        partner.failSave = true
        val toast = controller(partnerPort = partner).shiftWeekOffset(1)
        assertEquals(CoupleStrings.saveFailed.zh, toast?.message)
        assertEquals(1, partner.binding?.weekOffset)
    }

    @Test
    fun pickColorWritesEachRow() {
        val partner = FakePartnerPort(binding = PartnerTimetableBindingModel(partnerName = "小屿"))
        val c = controller(partnerPort = partner)
        assertNull(c.pickColor(0, "#111111"))
        assertNull(c.pickColor(1, "#222222"))
        assertNull(c.pickColor(2, "#333333"))
        assertEquals("#111111", partner.binding?.mineColorHex)
        assertEquals("#222222", partner.binding?.partnerColorHex)
        assertEquals("#333333", partner.binding?.togetherColorHex)
    }

    @Test
    fun pickColorFailureReportsSaveFailed() {
        val partner = FakePartnerPort(binding = PartnerTimetableBindingModel(partnerName = "小屿"))
        partner.failSave = true
        val toast = controller(partnerPort = partner).pickColor(0, "#111111")
        assertEquals(CoupleStrings.saveFailed.zh, toast?.message)
    }

    // ── 解绑 / 导入 / 导出 ──

    @Test
    fun unlinkClearsBindingAndNotifies() {
        val partner = FakePartnerPort(binding = PartnerTimetableBindingModel(partnerName = "小屿"))
        val toast = controller(partnerPort = partner).unlink()
        assertEquals(CoupleStrings.coupleTimetableUnlinkSuccess.zh, toast.message)
        assertNull(partner.binding)
        assertEquals(1, partner.unlinkCount)
        assertEquals(1, partner.notifyCount)
    }

    @Test
    fun importUsesPackageErrorCodeCopy() {
        val partner = FakePartnerPort().apply {
            importOutcome = { throw CouplePackageException(CouplePartnerPackageCodec.ERR_REQUIRES_SINGLE_PROFILE) }
        }
        val toast = controller(partnerPort = partner).importFromContent("{}")
        assertEquals(CoupleStrings.partnerImportRequiresSingleProfile.zh, toast.message)
        assertTrue(toast.isError)
    }

    @Test
    fun importSuccessAppendsDroppedSuffix() {
        val partner = FakePartnerPort().apply {
            importOutcome = { CoupleImportOutcome(updated = true, droppedTotal = 3) }
        }
        val toast = controller(partnerPort = partner).importFromContent("{}")
        // Dart：`已更新对方课表` + `，其中 3 条格式损坏已跳过`
        assertTrue(toast.message.startsWith(CoupleStrings.coupleTimetableImportUpdated.zh))
        assertTrue(toast.message.endsWith("3 条格式损坏已跳过"))
        assertFalse(toast.isError)
    }

    @Test
    fun exportHandsPackageToSink() {
        val exported = mutableListOf<Pair<String, String>>()
        val c = controller(exported = exported)
        val toast = c.exportMine()
        assertNull(toast)
        assertEquals(1, exported.size)
        assertTrue(exported.first().second.endsWith(".json"))
    }
}
