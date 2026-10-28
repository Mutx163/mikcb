package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.sync.WebdavSyncConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云同步状态持有者单测（C1 · 页面接线契约）。
 *
 * 这里钉的是**页面真正要用的三件事**：
 * 1. 连接成功后账号/开关/密码状态正确（渲染层据此显示已连接）；
 * 2. 刷新列表后 viewState 里真的有远端备份行（不再是示例空列表）；
 * 3. 立即备份后远端多一条 + 上次同步时间被写上；断开后账号清零、列表清空。
 *
 * 期望值人推，不抄实现：
 * - 默认配置的远程目录是 `/Apps/qingyu-sync/`，历史目录在其下 `history/`；
 * - 「立即备份成功」后上周同步时间不可能是占位符 `-`；
 * - 「断开」= 用户名空 + 无密码 + 不能再同步。
 */
class CloudSyncControllerTest {

    private fun controller(
        transport: FakeRemoteTransport = FakeRemoteTransport(),
        store: FakeConfigStore = FakeConfigStore(),
        snapshotStore: FakeLocalSnapshotStore = FakeLocalSnapshotStore(),
    ): CloudSyncController = CloudSyncController(
        store = store,
        snapshotStore = snapshotStore,
        transportFactory = { _, _ -> transport },
        deviceLabel = "测试机",
        clock = { "2026-03-07T09:05:00+08:00" },
    )

    @Test
    fun `连接成功_落密码并启用账号`() {
        val store = FakeConfigStore()
        val controller = controller(store = store)

        val result = controller.connect("me@example.com", "pw")

        assertTrue(result.success)
        assertEquals("me@example.com", controller.config.username)
        assertTrue(controller.config.enabled)
        assertEquals("pw", store.password)
        assertTrue(controller.cloudSyncViewState().account.connected)
    }

    @Test
    fun `连接自检失败不落密码不启用`() {
        val transport = FakeRemoteTransport()
        transport.connectionErrorCode = "auth_failed"
        val store = FakeConfigStore()
        val controller = controller(transport = transport, store = store)

        val result = controller.connect("me@example.com", "pw")

        assertFalse(result.success)
        assertEquals("auth_failed", result.errorCode)
        assertNull(store.password)
        assertFalse(controller.config.enabled)
    }

    @Test
    fun `空用户名连接直接拒绝`() {
        val controller = controller()
        val result = controller.connect("   ", "pw")
        assertFalse(result.success)
        assertEquals("missing_credentials", result.errorCode)
    }

    @Test
    fun `刷新列表后viewState里有远端备份行`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}snapshot-abc123-1700000000000000-devA.mikcb"] = byteArrayOf(1)
        val controller = controller(transport = transport)
        controller.connect("me@example.com", "pw")

        val outcome = controller.refreshBackups()

        assertEquals(SyncOpKind.OK, outcome.kind)
        val viewState = controller.cloudSyncViewState()
        assertEquals(1, viewState.backupRows.size)
        assertTrue(viewState.showBackups)
        assertEquals(1, controller.backupListViewState().rows.size)
    }

    @Test
    fun `立即备份后远端多一条且上次同步时间被写上`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes())
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")

        val kind = controller.createBackup()

        assertEquals(SyncResultKind.UPLOADED, kind)
        // 历史目录里现在正好 1 条。
        assertEquals(1, controller.backupListViewState().rows.size)
        // 上次同步时间不再是占位符。
        assertNotEquals("-", controller.cloudSyncViewState().status.lastSyncedAtText)
    }

    @Test
    fun `未连接时刷新列表直接失败`() {
        val controller = controller()
        val outcome = controller.refreshBackups()
        assertEquals(SyncOpKind.FAILED, outcome.kind)
        assertEquals("missing_credentials", outcome.errorCode)
    }

    @Test
    fun `断开后账号清零_密码清除_列表清空`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}snapshot-abc123-1700000000000000-devA.mikcb"] = byteArrayOf(1)
        val store = FakeConfigStore()
        val controller = controller(transport = transport, store = store)
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()
        assertTrue(controller.cloudSyncViewState().account.connected)

        controller.disconnect()

        assertEquals("", controller.config.username)
        assertFalse(controller.config.enabled)
        assertNull(store.password)
        assertFalse(controller.cloudSyncViewState().account.connected)
        assertTrue(controller.backupListViewState().rows.isEmpty())
    }

    @Test
    fun `高级设置非法地址被拦下`() {
        val controller = controller()
        controller.onBaseUrlChanged("ftp://nope/")
        assertEquals(BaseUrlVerdict.INVALID, controller.saveAdvanced())
    }

    @Test
    fun `明文http需要二次确认_确认后落盘`() {
        val controller = controller()
        controller.onBaseUrlChanged("http://192.168.1.5:5005/dav/")

        assertEquals(BaseUrlVerdict.NEED_HTTP_CONFIRM, controller.saveAdvanced())
        assertEquals(BaseUrlVerdict.PROCEED, controller.saveAdvanced(allowedInsecureHttp = true))
        assertEquals("http://192.168.1.5:5005/dav/", controller.config.baseUrl)
    }
}
