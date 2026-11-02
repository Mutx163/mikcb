package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.WebdavBaseUrlScheme
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.WebdavSyncMode
import com.mutx163.qingyu.sync.WebdavSyncProvider
import com.mutx163.qingyu.sync.inspectWebdavBaseUrlScheme
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云同步页模型层测试（源：`lib/screens/cloud_sync_screen.dart`）。
 *
 * 期望值按 Dart 原文手推，重点钉这几条容易漂移的判据：
 * - 「已连接」= 用户名 trim 后非空 **且** 本机存有密码（Dart `_isAccountConnected`）；
 * - 退出/未启用时，同步按钮、备份区、保留策略区**整段不出现**（Dart `if (_config.enabled)`）；
 * - baseUrl 三级闸门：空 → 坚果云默认 https；http → 要二次确认；其余 → 非法；
 * - 断开连接时清用户名、关开关、清两个 hash（Dart `clearLastAppliedRemoteHash` 等）；
 * - 备份预览只取前 3 条，超过 3 条才出现「查看全部备份版本」。
 */
class CloudSyncModelTest {

    private val zone: ZoneId = ZoneId.of("Asia/Shanghai")

    private fun config(
        enabled: Boolean = true,
        username: String = "me@example.com",
        provider: WebdavSyncProvider = WebdavSyncProvider.JIANGUOYUN,
        syncMode: WebdavSyncMode = WebdavSyncMode.AUTO,
        lastSyncedAtIso: String? = null,
        lastAppliedRemoteHash: String? = "remote-hash",
        lastUploadedLocalHash: String? = "local-hash",
    ): WebdavSyncConfig = WebdavSyncConfig(
        enabled = enabled,
        provider = provider,
        syncMode = syncMode,
        username = username,
        lastSyncedAtIso = lastSyncedAtIso,
        lastAppliedRemoteHash = lastAppliedRemoteHash,
        lastUploadedLocalHash = lastUploadedLocalHash,
    )

    private fun entry(
        id: String,
        exportedAtIso: String = "2026-03-07T09:05:30.000",
        isCurrent: Boolean = false,
    ): CloudBackupEntryModel = CloudBackupEntryModel(
        id = id,
        fileName = "$id.mikcb",
        exportedAtIso = exportedAtIso,
        contentSha256 = "hash-$id",
        deviceId = "device-1",
        deviceLabel = "我的手机",
        isCurrent = isCurrent,
        profileCount = 2,
        courseCount = 30,
    )

    // ==========================================
    // 1. 账号 / 提供商 / 同步方式
    // ==========================================

    @Test
    fun `已连接需要用户名非空且本机存有密码`() {
        assertTrue(CloudSyncLogic.isAccountConnected("me@example.com", hasStoredPassword = true))
        assertTrue(CloudSyncLogic.isAccountConnected("  me@example.com  ", hasStoredPassword = true))
        assertFalse(CloudSyncLogic.isAccountConnected("me@example.com", hasStoredPassword = false))
        assertFalse(CloudSyncLogic.isAccountConnected("", hasStoredPassword = true))
        assertFalse(CloudSyncLogic.isAccountConnected("   ", hasStoredPassword = true))
    }

    @Test
    fun `提供商与同步方式的文案`() {
        assertEquals("坚果云", CloudSyncLogic.providerLabel(WebdavSyncProvider.JIANGUOYUN))
        assertEquals("自定义 WebDAV", CloudSyncLogic.providerLabel(WebdavSyncProvider.CUSTOM))
        assertEquals("自动同步", CloudSyncLogic.modeLabel(WebdavSyncMode.AUTO))
        assertEquals("手动同步", CloudSyncLogic.modeLabel(WebdavSyncMode.MANUAL))
        assertEquals(listOf("坚果云", "自定义 WebDAV"), CloudSyncLogic.providerLabels())
        assertEquals(listOf("自动同步", "手动同步"), CloudSyncLogic.modeLabels())
    }

    // ==========================================
    // 2. 状态区
    // ==========================================

    @Test
    fun `从未同步时上次同步显示短横线`() {
        val status = CloudSyncLogic.buildStatusView(
            CloudSyncStatusSource(isSyncing = false, lastSyncedAtIso = null, lastErrorCode = null),
            zone,
        )
        assertEquals("-", status.lastSyncedAtText)
        assertNull(status.lastErrorText)
        assertFalse(status.isSyncing)
    }

    @Test
    fun `上次同步按本地时间格式化错误码本地化`() {
        val status = CloudSyncLogic.buildStatusView(
            CloudSyncStatusSource(
                isSyncing = true,
                lastSyncedAtIso = "2026-10-27T11:42:09.000",
                lastErrorCode = "connection_timeout",
            ),
            zone,
        )
        assertEquals("2026-10-27 11:42", status.lastSyncedAtText)
        assertTrue(status.isSyncing)
        assertEquals("连接超时", status.lastErrorText)
    }

    // ==========================================
    // 3. baseUrl 三级闸门
    // ==========================================

    @Test
    fun `空地址回落到坚果云默认https地址`() {
        val empty = CloudSyncLogic.resolveBaseUrl("")
        assertEquals(BaseUrlVerdict.PROCEED, empty.verdict)
        assertEquals("https://dav.jianguoyun.com/dav/", empty.resolvedUrl)

        val blank = CloudSyncLogic.resolveBaseUrl("    ")
        assertEquals(BaseUrlVerdict.PROCEED, blank.verdict)
        assertEquals("https://dav.jianguoyun.com/dav/", blank.resolvedUrl)
    }

    @Test
    fun `https地址去掉首尾空白后放行`() {
        val result = CloudSyncLogic.resolveBaseUrl("  https://dav.example.com/dav/  ")
        assertEquals(BaseUrlVerdict.PROCEED, result.verdict)
        assertEquals("https://dav.example.com/dav/", result.resolvedUrl)
    }

    @Test
    fun `明文http要先二次确认`() {
        val result = CloudSyncLogic.resolveBaseUrl("http://192.168.1.5:5005/dav/")
        assertEquals(BaseUrlVerdict.NEED_HTTP_CONFIRM, result.verdict)
        assertEquals("http://192.168.1.5:5005/dav/", result.resolvedUrl)
    }

    @Test
    fun `其它协议与相对地址都判非法`() {
        for (raw in listOf("ftp://example.com/dav/", "dav.example.com/dav/", "file:///sdcard/x/")) {
            val result = CloudSyncLogic.resolveBaseUrl(raw)
            assertEquals("地址 $raw 应判非法", BaseUrlVerdict.INVALID, result.verdict)
            assertNull(result.resolvedUrl)
        }
    }

    @Test
    fun `远程目录为空回落默认值否则保留原样`() {
        assertEquals("/Apps/qingyu-sync/", CloudSyncLogic.resolveRemoteFolder(""))
        assertEquals("/Apps/qingyu-sync/", CloudSyncLogic.resolveRemoteFolder("   "))
        assertEquals("/Custom/", CloudSyncLogic.resolveRemoteFolder("  /Custom/  "))
    }

    // ==========================================
    // 4. 配置变更构造函数
    // ==========================================

    @Test
    fun `连接账号写入用户名并启用同步`() {
        val next = CloudSyncLogic.buildConnectConfig(config(enabled = false, username = ""), "  me@example.com  ")
        assertEquals("me@example.com", next.username)
        assertTrue(next.enabled)
    }

    @Test
    fun `断开账号清空用户名关闭开关并清两个哈希`() {
        val next = CloudSyncLogic.buildDisconnectConfig(
            config(lastSyncedAtIso = "2026-10-27T11:42:09.000"),
        )
        assertEquals("", next.username)
        assertFalse(next.enabled)
        assertNull(next.lastAppliedRemoteHash)
        assertNull(next.lastUploadedLocalHash)
        assertNull(next.lastSyncedAtIso)
        // 其余字段（地址、目录、保留策略）不动。
        assertEquals(WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL, next.baseUrl)
        assertEquals(WebdavSyncConfig.DEFAULT_REMOTE_FOLDER, next.remoteFolder)
        assertEquals(WebdavSyncConfig.DEFAULT_MAX_BACKUP_COUNT, next.maxBackupCount)
    }

    @Test
    fun `切回坚果云强制默认地址切到自定义沿用确认后的地址`() {
        val custom = CloudSyncLogic.buildProviderChangeConfig(
            config(),
            WebdavSyncProvider.CUSTOM,
            confirmedBaseUrl = "https://my.dav.example.com/dav/",
        )
        assertEquals(WebdavSyncProvider.CUSTOM, custom.provider)
        assertEquals("https://my.dav.example.com/dav/", custom.baseUrl)

        val backToJianguoyun = CloudSyncLogic.buildProviderChangeConfig(
            config(provider = WebdavSyncProvider.CUSTOM),
            WebdavSyncProvider.JIANGUOYUN,
            confirmedBaseUrl = null,
        )
        assertEquals(WebdavSyncProvider.JIANGUOYUN, backToJianguoyun.provider)
        assertEquals(WebdavSyncConfig.DEFAULT_JIANGUOYUN_BASE_URL, backToJianguoyun.baseUrl)
    }

    @Test
    fun `高级设置保存地址与目录目录为空回落默认`() {
        val saved = CloudSyncLogic.buildAdvancedConfig(
            config(),
            confirmedBaseUrl = "https://my.dav.example.com/dav/",
            rawRemoteFolder = "   ",
        )
        assertEquals("https://my.dav.example.com/dav/", saved.baseUrl)
        assertEquals(WebdavSyncConfig.DEFAULT_REMOTE_FOLDER, saved.remoteFolder)
    }

    // ==========================================
    // 5. 冲突弹框
    // ==========================================

    @Test
    fun `普通冲突与首次同步分歧用不同解释文案`() {
        val normal = CloudSyncLogic.conflictDialog(isFirstSyncDivergence = false)
        assertEquals("检测到同步冲突", normal.title)
        assertEquals("本机和云端都有新的修改，请选择保留哪一边的数据", normal.message)
        assertEquals("取消", normal.cancelLabel)
        assertEquals("使用云端", normal.useRemoteLabel)
        assertEquals("保留本机", normal.keepLocalLabel)

        val first = CloudSyncLogic.conflictDialog(isFirstSyncDivergence = true)
        assertEquals("本机与云端数据不一致", first.title)
        assertEquals(
            "云端与本机数据不一致。保留本机将上传并覆盖云端，使用云端将下载并覆盖本机。",
            first.message,
        )
    }

    // ==========================================
    // 6. 整页 viewState（分段显隐 + 按钮状态）
    // ==========================================

    @Test
    fun `未连接时只显示引导与账号区`() {
        val state = CloudSyncLogic.buildViewState(
            config = config(enabled = false, username = ""),
            hasStoredPassword = false,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = emptyList(),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertFalse(state.account.connected)
        assertEquals("连接坚果云", state.account.title)
        assertEquals("可在多设备间同步课表与导入数据", state.account.subtitle)
        assertFalse(state.showSyncSettings)
        assertFalse(state.showSyncNow)
        assertFalse(state.showBackups)
        assertFalse(state.showRetention)
        assertTrue(state.backupRows.isEmpty())
    }

    @Test
    fun `撤销恢复入口只在备份业务区可见时出现`() {
        val connected = CloudSyncLogic.buildViewState(
            config = config(enabled = true),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = emptyList(),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
            canUndoRestore = true,
        )
        assertTrue(connected.showBackups)
        assertTrue(connected.canUndoRestore)
        assertEquals("撤销上次恢复", connected.undoRestoreTitle)
        assertEquals("重启应用后失效", connected.undoRestoreSummary)
        assertEquals("撤销", connected.undoRestoreActionLabel)

        // 同步开关关掉后备份区整段不出现，撤销入口也不能单独悬空。
        val disabled = CloudSyncLogic.buildViewState(
            config = config(enabled = false),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = emptyList(),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
            canUndoRestore = true,
        )
        assertFalse(disabled.showBackups)
        assertFalse(disabled.canUndoRestore)
    }

    @Test
    fun `已连接且启用时显示设置同步与保留策略`() {
        val state = CloudSyncLogic.buildViewState(
            config = config(),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(isSyncing = false, lastSyncedAtIso = "2026-10-27T11:42:09.000"),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = listOf(entry("a")),
            isLoading = false,
            deviceLabel = "我的手机",
            zone = zone,
        )
        assertTrue(state.account.connected)
        assertEquals("已连接：me@example.com", state.account.title)
        assertEquals("坚果云", state.account.subtitle)
        assertTrue(state.showSyncSettings)
        assertTrue(state.showSyncNow)
        assertTrue(state.showBackups)
        assertTrue(state.showRetention)
        assertTrue(state.syncEnabled)
        assertTrue(state.syncNowButton.enabled)
        assertTrue(state.createBackupButton.enabled)
        assertEquals("我的手机", state.deviceLabel)
    }

    @Test
    fun `已连接但关闭同步时同步按钮与备份区整段不出现`() {
        val state = CloudSyncLogic.buildViewState(
            config = config(enabled = false),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = listOf(entry("a")),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertTrue(state.account.connected)
        assertTrue(state.showSyncSettings)
        assertFalse(state.showSyncNow)
        assertFalse(state.showBackups)
        assertFalse(state.showRetention)
        // 按钮显隐与使能是两件事：按钮状态仍按「未启用 = 不可点」算。
        assertFalse(state.syncNowButton.enabled)
    }

    @Test
    fun `同步中与备份中的按钮互斥禁用`() {
        val syncing = CloudSyncLogic.buildViewState(
            config = config(),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(isSyncing = true),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = emptyList(),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertTrue(syncing.syncNowButton.loading)
        assertFalse(syncing.syncNowButton.enabled)
        assertFalse(syncing.createBackupButton.enabled)

        val creating = CloudSyncLogic.buildViewState(
            config = config(),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(isSyncing = false),
            isCreatingBackup = true,
            loadingBackups = false,
            backupEntries = emptyList(),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertTrue(creating.createBackupButton.loading)
        assertFalse(creating.createBackupButton.enabled)
        assertTrue(creating.syncNowButton.enabled)
    }

    @Test
    fun `备份预览只取前三条超过三条才出现查看全部`() {
        val five = (1..5).map { entry("e$it", "2026-03-0${it}T09:00:00.000") }
        val state = CloudSyncLogic.buildViewState(
            config = config(),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = five,
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertEquals(3, state.backupRows.size)
        assertTrue(state.hasMoreBackups)
        // 预览沿用服务层倒序：最新的 3 月 5 日排第一。
        assertEquals("2026-03-05 09:00", state.backupRows.first().title)
        assertEquals("查看全部备份版本", state.viewAllLabel)

        val three = CloudSyncLogic.buildViewState(
            config = config(),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = five.take(3),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertEquals(3, three.backupRows.size)
        assertFalse(three.hasMoreBackups)
    }

    // ==========================================
    // 7. 保留策略
    // ==========================================

    @Test
    fun `保留份数与天数选项文案`() {
        assertEquals(listOf(5, 10, 15, 20, 30), CloudSyncLogic.MAX_BACKUP_COUNT_OPTIONS)
        assertEquals(listOf(7, 14, 30, 60, 90), CloudSyncLogic.MAX_BACKUP_AGE_OPTIONS)
        assertEquals(listOf("5 份", "10 份", "15 份", "20 份", "30 份"),
            CloudSyncLogic.maxCountOptionLabels())
        assertEquals(listOf("7 天", "14 天", "30 天", "60 天", "90 天"),
            CloudSyncLogic.maxAgeOptionLabels())
    }

    @Test
    fun `保留策略下拉当前值映射到选项下标`() {
        val state = CloudSyncLogic.buildViewState(
            config = config().copyWith(maxBackupCount = 20, maxBackupAgeDays = 60, manualBackupProtected = false),
            hasStoredPassword = true,
            status = CloudSyncStatusSource(),
            isCreatingBackup = false,
            loadingBackups = false,
            backupEntries = emptyList(),
            isLoading = false,
            deviceLabel = "",
            zone = zone,
        )
        assertEquals(3, state.maxCountSelectedIndex)
        assertEquals(3, state.maxAgeSelectedIndex)
        assertFalse(state.manualBackupProtected)
    }

    // ==========================================
    // 8. 与既有模型层的一致性（baseUrl 判据必须同源）
    // ==========================================

    @Test
    fun `baseUrl 判据与 sync 包 inspectWebdavBaseUrlScheme 同源`() {
        assertEquals(
            WebdavBaseUrlScheme.INSECURE_HTTP,
            inspectWebdavBaseUrlScheme("http://192.168.1.5/dav/"),
        )
        assertEquals(
            BaseUrlVerdict.NEED_HTTP_CONFIRM,
            CloudSyncLogic.resolveBaseUrl("http://192.168.1.5/dav/").verdict,
        )
        assertEquals(
            BaseUrlVerdict.PROCEED,
            CloudSyncLogic.resolveBaseUrl("https://dav.jianguoyun.com/dav/").verdict,
        )
    }
}
