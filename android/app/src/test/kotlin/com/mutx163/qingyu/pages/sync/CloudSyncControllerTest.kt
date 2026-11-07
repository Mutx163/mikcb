package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.HistoryListResult
import com.mutx163.qingyu.sync.SyncConflictChoice
import com.mutx163.qingyu.sync.WebdavSyncConfig
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.atomic.AtomicReference

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
        undoStore: CloudSyncUndoStore = CloudSyncUndoStore(),
    ): CloudSyncController = CloudSyncController(
        store = store,
        snapshotStore = snapshotStore,
        transportFactory = { _, _ -> transport },
        deviceLabel = "测试机",
        clock = { "2026-03-07T09:05:00+08:00" },
        undoStore = undoStore,
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
    fun `连接失败错误码写进status供页面提示`() {
        // 2026-11-02：连接挪到 IO 线程后，弹层不再无条件关闭——页面按返回值留人重试，
        // 可见提示走 status.lastErrorCode 这条既有通道，所以失败码必须真的写进去。
        val transport = FakeRemoteTransport()
        transport.connectionErrorCode = "connection_timeout"
        val controller = controller(transport = transport)

        val revisionBefore = controller.revision
        val result = controller.connect("me@example.com", "pw")

        assertFalse(result.success)
        assertEquals("connection_timeout", controller.lastErrorCode)
        // 写错误码必须广播（revision 自增），否则页面不会重组、提示不会出现。
        assertTrue(controller.revision > revisionBefore)
        // 连接成功路径会清掉错误码（既有测试钉过），这里钉失败→再成功的恢复。
        transport.connectionErrorCode = null
        assertTrue(controller.connect("me@example.com", "pw").success)
        assertNull(controller.lastErrorCode)
    }

    @Test
    fun `测试连接失败错误码写进status且不落盘`() {
        val transport = FakeRemoteTransport()
        transport.connectionErrorCode = "auth_failed"
        val store = FakeConfigStore()
        val controller = controller(transport = transport, store = store)

        val ok = controller.testConnection("me@example.com", "pw")

        assertFalse(ok)
        assertEquals("auth_failed", controller.lastErrorCode)
        // 测试连接不落盘：配置与密码都不动。
        assertEquals("", controller.config.username)
        assertNull(store.password)
    }

    @Test
    fun `监听器并发增删与通知不抛并发修改异常`() {
        // 2026-11-02：连接/测试连接挪到 IO 线程后，notifyChanged 会在 IO 线程迭代监听器，
        // 而主线程在进出组合时增删监听。旧实现 LinkedHashSet 的 toList() 与并发写不互斥，
        // 会抛 ConcurrentModificationException（咬合探针实测会红）；CopyOnWriteArrayList 不抛。
        val controller = controller()
        // 常驻几个监听器：让每次通知的迭代窗口足够大，保证旧实现必红而不是靠运气。
        repeat(32) { controller.addListener {} }
        val failure = AtomicReference<Throwable?>(null)
        val notifyRuns = java.util.concurrent.atomic.AtomicLong()
        val subscriberRuns = java.util.concurrent.atomic.AtomicLong()
        // 固定迭代次数，不用「跑满 2 秒」作为结束条件：
        // 机器负载高时 2 秒窗口内的迭代数不可控（可能 <1000 恒红、也可能空转恒绿）；
        // 固定次数 + 宽松 join 只把「线程是否被调度」留作时间依赖，次数本身是确定的。
        val iterations = 2_000
        val subscriber = Thread {
            try {
                repeat(iterations) {
                    if (failure.get() == null) {
                        val listener: () -> Unit = {}
                        controller.addListener(listener)
                        controller.removeListener(listener)
                        subscriberRuns.incrementAndGet()
                    }
                }
            } catch (t: Throwable) {
                failure.set(t)
            }
        }
        val notifier = Thread {
            try {
                repeat(iterations) {
                    if (failure.get() == null) {
                        // 公开的纯通知入口：改草稿 + notifyChanged，不碰网络与落盘。
                        controller.onBaseUrlChanged("http://example.com/dav/")
                        notifyRuns.incrementAndGet()
                    }
                }
            } catch (t: Throwable) {
                failure.set(t)
            }
        }
        subscriber.start()
        notifier.start()
        subscriber.join(10_000)
        notifier.join(10_000)

        // 先报异常：异常会让循环提前跳过计数，误报成「没跑满」会掩盖真正原因。
        assertNull("并发增删/通知抛了异常：${failure.get()}", failure.get())
        // 两条循环都必须真的跑满，否则测试空转恒绿。
        assertFalse("并发压力线程未在 10s 内完成", subscriber.isAlive || notifier.isAlive)
        assertEquals("并发增删没跑满", iterations.toLong(), subscriberRuns.get())
        assertEquals("并发通知没跑满", iterations.toLong(), notifyRuns.get())
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
        // index 缺失 → 从 listing 重建：体必须是合法快照（坏体按 Dart 口径跳过不显示）。
        transport.files["${folder}20260307-170501-abcdef12.mikcb"] = buildSyncSnapshotBytes()
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
    fun `刷新成功即清上次错误码`() {
        // 2026-11-06 第三轮返工①-2：refreshBackups 的 OK/EMPTY 分支原先不清
        // status.lastErrorCode——刷新成功后仍显示陈旧错误 + 死重试提示（错误条挂着，
        // 点重试其实已经没事了）。成功即清，OK 与 EMPTY 都是「刷新成功」。
        val transport = FakeRemoteTransport()
        val controller = controller(transport = transport)
        controller.connect("me@example.com", "pw")

        transport.listResultOverride = HistoryListResult.failed("connection_timeout")
        assertEquals(SyncOpKind.FAILED, controller.refreshBackups().kind)
        assertEquals("connection_timeout", controller.lastErrorCode)

        transport.listResultOverride = null
        transport.files["${WebdavSyncConfig().historyRemoteFolder}20260307-170501-abcdef12.mikcb"] =
            buildSyncSnapshotBytes()
        assertEquals(SyncOpKind.OK, controller.refreshBackups().kind)
        assertNull("刷新成功（OK）必须清掉陈旧错误码", controller.lastErrorCode)

        transport.listResultOverride = HistoryListResult.failed("connection_timeout")
        assertEquals("connection_timeout", controller.refreshBackups().let { controller.lastErrorCode })

        transport.listResultOverride = HistoryListResult.ok(emptyList())
        controller.refreshBackups()
        assertNull("刷新成功（EMPTY，云端空也算成功）同样必须清掉陈旧错误码", controller.lastErrorCode)
    }

    @Test
    fun `断开后账号清零_密码清除_列表清空`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}20260307-170501-abcdef12.mikcb"] = buildSyncSnapshotBytes()
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

    // ---------- 同步基线落盘（2026-11-02 修「基线从来没写盘」） ----------

    @Test
    fun `立即备份成功后写入上传基线_isCurrent生效`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes())
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertNull(controller.config.lastUploadedLocalHash)

        assertEquals(SyncResultKind.UPLOADED, controller.createBackup())

        // 上传基线必须真的落盘（此前 markSynced 只写时间，基线恒 null）。
        val uploadedHash = controller.config.lastUploadedLocalHash
        assertNotNull("上传成功后 lastUploadedLocalHash 必须有值", uploadedHash)
        assertEquals(
            "落盘值必须等于上传内容的内容哈希",
            WebdavSyncCoordinator.snapshotContentHash(buildSyncSnapshotBytes()),
            uploadedHash,
        )
        // 列表里这条就是「当前版本」：isCurrent 与删除按钮的显隐都靠它。
        val rows = controller.backupListViewState().rows
        assertEquals(1, rows.size)
        assertTrue("刚上传的那条应显示为当前版本", rows.first().isCurrent)
    }

    @Test
    fun `恢复成功后两个基线钉到远端内容`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        val remoteBytes = buildSyncSnapshotBytes(profileId = "pRemote")
        transport.files["${folder}backup.mikcb"] = remoteBytes
        val controller = controller(transport = transport)
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()

        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))

        val remoteHash = WebdavSyncCoordinator.snapshotContentHash(remoteBytes)
        assertEquals(remoteHash, controller.config.lastAppliedRemoteHash)
        assertEquals(remoteHash, controller.config.lastUploadedLocalHash)
    }

    @Test
    fun `删除当前备份被拒绝_错误码cannot_delete_current_backup`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes())
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.createBackup())
        val currentId = controller.backupListViewState().rows.single().entryId

        assertEquals(SyncResultKind.FAILED, controller.deleteBackup(currentId))

        assertEquals("cannot_delete_current_backup", controller.lastErrorCode)
        // 远端文件必须原地不动。
        assertTrue(
            transport.files.containsKey("${WebdavSyncConfig().historyRemoteFolder}$currentId"),
        )
    }

    // ---------- 进程被杀在中途（第四轮：删除 3 个中断点） ----------

    /**
     * 造一个「远端已有一条旧备份 + 本机刚上传一条新备份」的现场：
     * index.json 已落盘（含两条），旧那条可删，新那条是当前版本。
     */
    private fun seededBackups(
        transport: FakeRemoteTransport,
        store: FakeConfigStore,
    ): CloudSyncController {
        transport.files["${WebdavSyncConfig().historyRemoteFolder}old.mikcb"] =
            buildSyncSnapshotBytes(profileId = "pOld")
        val controller = controller(
            transport = transport,
            store = store,
            snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pNew")),
        )
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.createBackup())
        controller.refreshBackups()
        assertEquals(2, controller.backupListViewState().rows.size)
        return controller
    }

    @Test
    fun `删除中断_删之前断线_重启重试仍可删且只删这一条`() {
        val transport = FakeRemoteTransport()
        val store = FakeConfigStore()
        val first = seededBackups(transport, store)
        transport.deleteFailureCode = "connection_failed"

        assertEquals(SyncResultKind.FAILED, first.deleteBackup("old.mikcb"))
        assertEquals("connection_failed", first.lastErrorCode)
        assertTrue(
            "被杀在删之前：旧文件必须还在",
            transport.files.containsKey("${WebdavSyncConfig().historyRemoteFolder}old.mikcb"),
        )

        transport.deleteFailureCode = null
        val second = controller(
            transport = transport,
            store = store,
            snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pNew")),
        )
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals(SyncResultKind.BACKUP_DELETED, second.deleteBackup("old.mikcb"))

        val folder = WebdavSyncConfig().historyRemoteFolder
        assertFalse(transport.files.containsKey("${folder}old.mikcb"))
        assertEquals("重试只删这一条", 1, second.backupListViewState().rows.size)
        assertTrue("当前版本不得被误删", transport.files.keys.any { it.startsWith(folder) })
    }

    @Test
    fun `删除中断_文件已删索引没存上_重启后重删可清掉幽灵行`() {
        // 被杀点：远端文件已删，index.json 还没保存。重启后索引里那条是幽灵，
        // 再点一次删除必须成功把索引摘干净，且不得动到别的备份。
        val transport = FakeRemoteTransport()
        val store = FakeConfigStore()
        val first = seededBackups(transport, store)
        transport.putFailureCode = "connection_failed"

        assertEquals(SyncResultKind.FAILED, first.deleteBackup("old.mikcb"))
        assertEquals("connection_failed", first.lastErrorCode)
        val folder = WebdavSyncConfig().historyRemoteFolder
        assertFalse("文件已经删了", transport.files.containsKey("${folder}old.mikcb"))

        transport.putFailureCode = null
        val second = controller(
            transport = transport,
            store = store,
            snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pNew")),
        )
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals("索引没更新，重启后仍会看到幽灵行", 2, second.backupListViewState().rows.size)

        assertEquals("重删应把索引摘干净", SyncResultKind.BACKUP_DELETED, second.deleteBackup("old.mikcb"))
        assertEquals(1, second.backupListViewState().rows.size)
        assertArrayEquals(
            "另一条备份必须原封不动",
            buildSyncSnapshotBytes(profileId = "pNew"),
            transport.files["${folder}${second.backupListViewState().rows.single().entryId}"],
        )
    }

    @Test
    fun `删除中断_索引已存列表刷新被杀_重启状态干净`() {
        // 被杀点：文件已删、index.json 已保存，列表刷新（listing）时进程死掉。
        // 磁盘状态已是最终态，重启后不得残留条目，重复删除按 backup_not_found 处理。
        val transport = FakeRemoteTransport()
        val store = FakeConfigStore()
        val first = seededBackups(transport, store)
        val indexRemotePath = first.config.historyIndexRemotePath
        transport.afterPut = { path ->
            if (path == indexRemotePath) throw KilledMidway() // 索引刚写完，列表刷新前被杀
        }

        try {
            first.deleteBackup("old.mikcb")
            throw AssertionError("应在索引写完后被杀")
        } catch (_: KilledMidway) {
        }
        transport.afterPut = {}

        val folder = WebdavSyncConfig().historyRemoteFolder
        assertFalse("文件已删", transport.files.containsKey("${folder}old.mikcb"))

        val second = controller(
            transport = transport,
            store = store,
            snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "pNew")),
        )
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals("索引已保存，重启后只剩一条", 1, second.backupListViewState().rows.size)

        assertEquals(SyncResultKind.FAILED, second.deleteBackup("old.mikcb"))
        assertEquals("已删干净的条目再删应是 not found", "backup_not_found", second.lastErrorCode)
        assertEquals(1, transport.files.keys.count { it.startsWith(folder) && it.endsWith(".mikcb") })
    }

    // ---------- 立即同步：先拉后推（2026-11-02 修「不比对远端就 PUT 覆盖」） ----------

    /** 读当前 meta 指针指向的正文（Flutter 协议下「云端当前版本」的唯一读法）。 */
    private fun remoteCurrentBody(
        transport: FakeRemoteTransport,
        config: WebdavSyncConfig,
    ): ByteArray? {
        val metaBytes = transport.files[config.metaRemotePath] ?: return null
        @Suppress("UNCHECKED_CAST")
        val meta = MiniJson.parse(String(metaBytes, Charsets.UTF_8)) as Map<String, Any?>
        return meta["snapshotPath"]?.let { transport.files[it] }
    }

    @Test
    fun `syncNow_远端为空时直接推本地`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes())
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")

        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())

        // 推本地后远端必须有 meta 指针（Flutter 协议的「当前版本」指针）。
        assertTrue(transport.files.containsKey(controller.config.metaRemotePath))
        assertNotNull(controller.config.lastUploadedLocalHash)
    }

    @Test
    fun `syncNow_远端仍是基线而本地有改动时推本地`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "p1"))
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())

        // 本机改了、远端没动：推本地是正确语义（远端没有别人的新数据可丢）。
        snapshotStore.stored = buildSyncSnapshotBytes(profileId = "p1-edited")
        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())

        assertArrayEquals(
            buildSyncSnapshotBytes(profileId = "p1-edited"),
            remoteCurrentBody(transport, controller.config),
        )
        assertNull(controller.pendingSyncConflict)
    }

    @Test
    fun `syncNow_仅远端更新本地没改时以云端为准`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "p1"))
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())

        // 另一台设备推了新版本（Flutter 布局：meta 指向新正文）；本机一个字没改。
        val remoteNew = buildSyncSnapshotBytes(profileId = "pOther")
        seedRemoteSnapshot(transport, controller.config, remoteNew, deviceId = "devOther")
        assertEquals(SyncResultKind.DOWNLOADED, controller.syncNow())

        assertArrayEquals("本机应被拉成云端那份", remoteNew, snapshotStore.stored)
        assertNull(controller.pendingSyncConflict)
    }

    @Test
    fun `syncNow_两边都改过时挂起冲突不覆盖任何一端`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "p1"))
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())

        val remoteDrifted = buildSyncSnapshotBytes(profileId = "pRemote")
        val driftedPath = seedRemoteSnapshot(transport, controller.config, remoteDrifted, deviceId = "devOther")
        snapshotStore.stored = buildSyncSnapshotBytes(profileId = "pLocal")

        assertEquals(SyncResultKind.CANCELLED, controller.syncNow())

        val conflict = controller.pendingSyncConflict
        assertNotNull("两边都改过必须挂起冲突等用户选边", conflict)
        assertFalse(conflict!!.isFirstSyncDivergence)
        // 挂起期间两端都必须原地不动：绝不静默覆盖。
        assertArrayEquals(remoteDrifted, transport.files[driftedPath])
        assertArrayEquals(buildSyncSnapshotBytes(profileId = "pLocal"), snapshotStore.stored)

        // 放弃选边：仍然什么都不动，挂起冲突被消费掉。
        assertEquals(SyncResultKind.CANCELLED, controller.resolveSyncConflict(SyncConflictChoice.CANCEL))
        assertNull(controller.pendingSyncConflict)
        assertArrayEquals(remoteDrifted, transport.files[driftedPath])
        assertArrayEquals(buildSyncSnapshotBytes(profileId = "pLocal"), snapshotStore.stored)
    }

    @Test
    fun `syncNow_冲突选本机后覆盖远端并写基线`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "p1"))
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())
        seedRemoteSnapshot(transport, controller.config, buildSyncSnapshotBytes(profileId = "pRemote"), deviceId = "devOther")
        snapshotStore.stored = buildSyncSnapshotBytes(profileId = "pLocal")
        assertEquals(SyncResultKind.CANCELLED, controller.syncNow())

        assertEquals(SyncResultKind.UPLOADED, controller.resolveSyncConflict(SyncConflictChoice.KEEP_LOCAL))

        assertArrayEquals(
            buildSyncSnapshotBytes(profileId = "pLocal"),
            remoteCurrentBody(transport, controller.config),
        )
        assertEquals(
            WebdavSyncCoordinator.snapshotContentHash(buildSyncSnapshotBytes(profileId = "pLocal")),
            controller.config.lastUploadedLocalHash,
        )
        assertNull(controller.pendingSyncConflict)
    }

    // ---------- 保留策略接线（2026-11-02 修「prune 从未执行」） ----------

    /** 改本地快照内容再上传：不同 profileId ⇒ 不同内容哈希 ⇒ 不同的版本化文件。 */
    private fun uploadAsNewVersion(
        controller: CloudSyncController,
        snapshotStore: FakeLocalSnapshotStore,
        profileId: String,
        exportedAt: String,
        manual: Boolean,
    ) {
        snapshotStore.stored = buildSyncSnapshotBytes(profileId = profileId, exportedAt = exportedAt)
        val kind = if (manual) controller.createBackup() else controller.syncNow()
        assertEquals(SyncResultKind.UPLOADED, kind)
    }

    private fun historyFileNames(transport: FakeRemoteTransport): Set<String> =
        transport.files.keys
            .filter { it.contains("/history/") }
            .map { it.substringAfterLast('/') }
            .filter { it.endsWith(".mikcb") }
            .toSet()

    /** Dart 历史命名的 backupId 前缀（本地时刻 yyyyMMdd-HHmmss；哈希段不计）。 */
    private fun backupIdPrefix(exportedAtIso: String): String =
        CloudBackupIndexCodec.buildBackupId(exportedAtIso, "").let { it.substringBeforeLast('-') }

    @Test
    fun `prune_超上限后上传真的删掉远端最旧一条`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore()
        val store = FakeConfigStore(
            config = WebdavSyncConfig(maxBackupCount = 2, manualBackupProtected = false),
        )
        val controller = controller(transport = transport, store = store, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")

        uploadAsNewVersion(controller, snapshotStore, "p1", "2026-03-05T09:00:00.000", manual = true)
        uploadAsNewVersion(controller, snapshotStore, "p2", "2026-03-06T09:00:00.000", manual = true)
        assertEquals(2, historyFileNames(transport).size)
        uploadAsNewVersion(controller, snapshotStore, "p3", "2026-03-07T09:00:00.000", manual = true)

        val remaining = historyFileNames(transport)
        assertEquals("超过上限 2 后远端必须只剩 2 条", 2, remaining.size)
        val oldestPrefix = backupIdPrefix("2026-03-05T09:00:00.000")
        assertTrue(
            "最旧的一条必须被删",
            remaining.none { it.startsWith(oldestPrefix) },
        )
    }

    @Test
    fun `prune_手动备份受保护_超限也不删`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore()
        // 上限 1 + 手动保护（默认开）：手动那条即便最老也豁免。
        val store = FakeConfigStore(config = WebdavSyncConfig(maxBackupCount = 1))
        val controller = controller(transport = transport, store = store, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")

        uploadAsNewVersion(controller, snapshotStore, "pManual", "2026-03-01T09:00:00.000", manual = true)
        uploadAsNewVersion(controller, snapshotStore, "pAuto1", "2026-03-06T09:00:00.000", manual = false)
        uploadAsNewVersion(controller, snapshotStore, "pAuto2", "2026-03-07T09:00:00.000", manual = false)

        val remaining = historyFileNames(transport)
        assertEquals("手动（豁免）+ 当前版本（豁免）留下，中间的自动备份被裁", 2, remaining.size)
        val manualPrefix = backupIdPrefix("2026-03-01T09:00:00.000")
        assertTrue(
            "受保护的手动备份必须存活",
            remaining.any { it.startsWith(manualPrefix) },
        )
    }

    @Test
    fun `prune_超过天数上限的过期备份上传后被裁`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore()
        val store = FakeConfigStore(
            config = WebdavSyncConfig(maxBackupCount = 30, maxBackupAgeDays = 7, manualBackupProtected = false),
        )
        val controller = controller(transport = transport, store = store, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        // clock() = 2026-03-07T09:05+08:00：这条比「now-7天」还老 3 天多。
        uploadAsNewVersion(controller, snapshotStore, "pOld", "2026-02-01T09:00:00.000", manual = true)
        uploadAsNewVersion(controller, snapshotStore, "pFresh", "2026-03-07T09:00:00.000", manual = true)

        val remaining = historyFileNames(transport)
        val expiredPrefix = backupIdPrefix("2026-02-01T09:00:00.000")
        assertTrue("过期备份必须被删", remaining.none { it.startsWith(expiredPrefix) })
        assertEquals(1, remaining.size)
    }

    @Test
    fun `备份来源不再硬编码_手动备份如实标MANUAL`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore()
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")

        uploadAsNewVersion(controller, snapshotStore, "pManual", "2026-03-06T09:00:00.000", manual = true)
        val manualEntry = controller.backupListViewState().rows.single()
        assertEquals(CloudBackupSource.MANUAL, controller.backupEntry(manualEntry.entryId)?.source)

        uploadAsNewVersion(controller, snapshotStore, "pAuto", "2026-03-07T09:00:00.000", manual = false)
        val entries = controller.backupListViewState().rows
        val sources = entries.map { controller.backupEntry(it.entryId)?.source }.toSet()
        assertEquals(setOf(CloudBackupSource.MANUAL, CloudBackupSource.AUTO), sources)
    }

    @Test
    fun `syncNow_冲突选云端后应用远端并写基线`() {
        val transport = FakeRemoteTransport()
        val snapshotStore = FakeLocalSnapshotStore(initial = buildSyncSnapshotBytes(profileId = "p1"))
        val controller = controller(transport = transport, snapshotStore = snapshotStore)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.syncNow())
        val remoteDrifted = buildSyncSnapshotBytes(profileId = "pRemote")
        val driftedPath = seedRemoteSnapshot(transport, controller.config, remoteDrifted, deviceId = "devOther")
        snapshotStore.stored = buildSyncSnapshotBytes(profileId = "pLocal")
        assertEquals(SyncResultKind.CANCELLED, controller.syncNow())

        assertEquals(SyncResultKind.DOWNLOADED, controller.resolveSyncConflict(SyncConflictChoice.KEEP_REMOTE))

        assertArrayEquals(remoteDrifted, snapshotStore.stored)
        assertArrayEquals(remoteDrifted, transport.files[driftedPath])
        val remoteHash = WebdavSyncCoordinator.snapshotContentHash(remoteDrifted)
        assertEquals(remoteHash, controller.config.lastAppliedRemoteHash)
        assertEquals(remoteHash, controller.config.lastUploadedLocalHash)
        assertNull(controller.pendingSyncConflict)
    }

    // ---------- 撤销点进程级共享（2026-11-02 修「换页就丢撤销入口」） ----------

    /** 造一个带远端备份、已连接已刷新、且撤销链路（快照构建 + 写回）可用的控制器。 */
    private fun controllerWithRemoteBackup(
        transport: FakeRemoteTransport,
        undoStore: CloudSyncUndoStore,
    ): CloudSyncController {
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}backup.mikcb"] = buildSyncSnapshotBytes(profileId = "pRemote")
        val controller = CloudSyncController(
            store = FakeConfigStore(),
            snapshotStore = FakeLocalSnapshotStore(),
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
            snapshotProvider = { SnapshotBuildResult.Success(buildSyncSnapshotBytes(profileId = "pLocal")) },
            snapshotApplier = { SnapshotApplyResult.Applied },
            undoStore = undoStore,
        )
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()
        return controller
    }

    @Test
    fun `撤销点跨控制器共享_列表页恢复_同步页能看到并撤销`() {
        val sharedStore = CloudSyncUndoStore()
        try {
            // 模拟壳里两条分支：备份列表页与云同步页各 remember 一个控制器。
            val listPageController = controllerWithRemoteBackup(FakeRemoteTransport(), sharedStore)

            assertEquals(SyncResultKind.DOWNLOADED, listPageController.openBackup("backup.mikcb"))
            assertTrue(listPageController.canUndoLastRestore)

            // 「换页」：同一个共享撤销点，另一个全新控制器实例必须看得到
            //（真壳里两个入口都传仓储 ⇒ 都有写回落点，这里注入等价的假写回）。
            val syncPageController = CloudSyncController(
                store = FakeConfigStore(),
                snapshotStore = FakeLocalSnapshotStore(),
                transportFactory = { _, _ -> FakeRemoteTransport() },
                deviceLabel = "测试机",
                clock = { "2026-03-07T09:05:00+08:00" },
                snapshotApplier = { SnapshotApplyResult.Applied },
                undoStore = sharedStore,
            )
            assertTrue("另一入口必须能看到撤销点", syncPageController.canUndoLastRestore)
            // viewState 里撤销卡片还要求业务区可见（未连接整段隐藏），那是另一条既有判据。

            // 在同步页撤销成功：撤销点被消费，两个入口同时消失。
            assertTrue(syncPageController.undoLastRestore())
            assertFalse(syncPageController.canUndoLastRestore)
            assertFalse(listPageController.canUndoLastRestore)
        } finally {
            // shared 单例若被复用必须清干净；这里注入独立实例，清一次兜底。
            sharedStore.clear()
        }
    }

    @Test
    fun `断开连接清掉共享撤销点`() {
        val sharedStore = CloudSyncUndoStore()
        val controller = controllerWithRemoteBackup(FakeRemoteTransport(), sharedStore)
        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))
        assertTrue(controller.canUndoLastRestore)

        controller.disconnect()

        assertFalse("断开后撤销点必须失效", controller.canUndoLastRestore)
        assertNull(sharedStore.peek())
    }

}
