package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.decodeSnapshotObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 云同步「上传 → 恢复」真路径契约测试（修 P0：立即备份必然失败 / 恢复点了没效果）。
 *
 * ## 钉的是什么
 *
 * 1. **上传的字节来自当前课表**，不是某个从未写过的本地快照文件；
 * 2. **没有本机数据时如实失败**，不把空包推上云端；
 * 3. **恢复真的把快照写回仓储**，课表内容随之改变；
 * 4. **写回失败如实报错**，不返回 DOWNLOADED；
 * 5. **进页会自己加载备份列表**，不再恒空；
 * 6. 恢复前的课表可被 [CloudSyncController.undoLastRestore] 撤销回来。
 *
 * 期望值人推：`course("local-course")` 与 `course("remote-course")` 是两份不同的课表，
 * 恢复后本机必须变成远端那份；撤销后必须变回本地那份。
 */
class CloudSyncSnapshotFlowTest {

    private fun repository(): TimetableRepository =
        TimetableRepository(TimetableStore(InMemoryKeyValueStore()))

    private fun course(id: String): Course = Course(
        id = id,
        name = "课程-$id",
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun controller(
        repository: TimetableRepository,
        transport: FakeRemoteTransport = FakeRemoteTransport(),
        snapshotStore: FakeLocalSnapshotStore = FakeLocalSnapshotStore(),
        snapshotApplier: ((ByteArray) -> SnapshotApplyResult)? = null,
        undoStore: CloudSyncUndoStore = CloudSyncUndoStore(),
    ): CloudSyncController = CloudSyncController(
        store = FakeConfigStore(),
        snapshotStore = snapshotStore,
        transportFactory = { _, _ -> transport },
        deviceLabel = "测试机",
        clock = { "2026-03-07T09:05:00+08:00" },
        repository = repository,
        snapshotApplier = snapshotApplier,
        undoStore = undoStore,
    )

    /** 用另一份仓储造一份「远端备份」字节（同一套 bridge，保证信封/校验和合法）。 */
    private fun remoteSnapshotBytes(courseId: String): ByteArray {
        val remote = repository()
        remote.addCourse(course(courseId))
        val result = TimetableSnapshotBridge.buildSnapshotBytes(
            repository = remote,
            deviceId = "devB",
            exportedAtIso = "2026-03-06T08:00:00.000",
        )
        assertTrue("远端快照应构建成功", result is SnapshotBuildResult.Success)
        return (result as SnapshotBuildResult.Success).bytes
    }

    // ---------- 上传 ----------

    @Test
    fun `立即备份_上传字节来自当前课表`() {
        val repository = repository()
        repository.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val controller = controller(repository, transport)
        controller.connect("me@example.com", "pw")

        val kind = controller.createBackup()

        assertEquals(SyncResultKind.UPLOADED, kind)
        // Flutter 协议：当前版本 = meta.snapshotPath 指向的不可变正文。
        @Suppress("UNCHECKED_CAST")
        val meta = decodeSnapshotObject(
            String(transport.files[controller.config.metaRemotePath]!!, Charsets.UTF_8),
        ) as Map<String, Any?>
        val bodyPath = meta["snapshotPath"] as String
        val uploaded = transport.files[bodyPath]
        assertNotNull("上传后远端应存在 meta 指向的快照正文", uploaded)
        val json = decodeSnapshotObject(String(uploaded!!, Charsets.UTF_8))
        val profiles = json["profiles"] as List<*>
        assertTrue("上传的快照里必须带档案", profiles.isNotEmpty())
        assertTrue("快照里必须含当前课表的课程 id", String(uploaded, Charsets.UTF_8).contains("local-course"))
    }

    @Test
    fun `没有本机数据时上传如实失败且不推空包`() {
        val repository = repository() // 盘上没有任何档案
        val transport = FakeRemoteTransport()
        val controller = controller(repository, transport)
        controller.connect("me@example.com", "pw")

        val kind = controller.createBackup()

        assertEquals(SyncResultKind.FAILED, kind)
        assertEquals("no_local_user_data", controller.lastErrorCode)
        assertTrue("不应向远端写入任何东西", transport.files.isEmpty())
    }

    // ---------- 恢复 ----------

    private fun controllerWithRemote(
        local: TimetableRepository,
        remoteCourseId: String,
        snapshotApplier: ((ByteArray) -> SnapshotApplyResult)? = null,
    ): Pair<CloudSyncController, FakeRemoteTransport> {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}backup.mikcb"] = remoteSnapshotBytes(remoteCourseId)
        val controller = controller(local, transport, snapshotApplier = snapshotApplier)
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()
        return controller to transport
    }

    @Test
    fun `恢复_快照写回仓储_课表变成远端那份`() {
        val local = repository()
        local.addCourse(course("local-course"))
        val (controller, _) = controllerWithRemote(local, remoteCourseId = "remote-course")

        val kind = controller.openBackup("backup.mikcb")

        assertEquals(SyncResultKind.DOWNLOADED, kind)
        val courseIds = local.snapshot.courses.map { it.id }
        assertTrue("恢复后应含远端课程，实际=$courseIds", courseIds.contains("remote-course"))
        assertTrue("恢复后不应再含本地课程，实际=$courseIds", !courseIds.contains("local-course"))
    }

    @Test
    fun `恢复写回失败_返回FAILED并带错误码`() {
        val local = repository()
        local.addCourse(course("local-course"))
        val (controller, _) = controllerWithRemote(
            local,
            remoteCourseId = "remote-course",
            snapshotApplier = { SnapshotApplyResult.Failed("sync_snapshot_apply_failed") },
        )

        val kind = controller.openBackup("backup.mikcb")

        assertEquals(SyncResultKind.FAILED, kind)
        assertEquals("sync_snapshot_apply_failed", controller.lastErrorCode)
        // 写回失败时本机课表一个字都不该变。
        assertEquals(listOf("local-course"), local.snapshot.courses.map { it.id })
    }

    @Test
    fun `撤销恢复_课表回到恢复前`() {
        val local = repository()
        local.addCourse(course("local-course"))
        val (controller, _) = controllerWithRemote(local, remoteCourseId = "remote-course")
        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))
        assertEquals(listOf("remote-course"), local.snapshot.courses.map { it.id })

        val undone = controller.undoLastRestore()

        assertTrue(undone)
        assertEquals(listOf("local-course"), local.snapshot.courses.map { it.id })
    }

    @Test
    fun `撤销不抹掉恢复后的编辑_按id只回退仍是恢复后值的条目`() {
        val local = repository()
        local.addCourse(course("local-course"))
        val (controller, _) = controllerWithRemote(local, remoteCourseId = "remote-course")
        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))

        // 恢复成功后用户又加了一门课，然后才点撤销。
        local.addCourse(course("user-added"))

        assertTrue(controller.undoLastRestore())

        val ids = local.snapshot.courses.map { it.id }
        assertTrue("恢复前的本地课程必须写回", ids.contains("local-course"))
        assertTrue("恢复之后用户加的课绝不能被撤销抹掉", ids.contains("user-added"))
        assertFalse("恢复带入且未被改过的课程应被撤销", ids.contains("remote-course"))
    }

    @Test
    fun `恢复成功才有可撤销点_撤销后页面状态同步消失`() {
        val local = repository()
        local.addCourse(course("local-course"))
        val (controller, _) = controllerWithRemote(local, remoteCourseId = "remote-course")

        // 恢复前：两份 viewState 都不该露出撤销入口。
        assertFalse(controller.canUndoLastRestore)
        assertFalse(controller.backupListViewState().canUndoRestore)
        assertFalse(controller.cloudSyncViewState().canUndoRestore)

        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))
        assertTrue(controller.canUndoLastRestore)
        assertTrue(controller.backupListViewState().canUndoRestore)
        assertTrue(controller.cloudSyncViewState().canUndoRestore)

        assertTrue(controller.undoLastRestore())
        assertFalse(controller.canUndoLastRestore)
        assertFalse(controller.backupListViewState().canUndoRestore)
        assertFalse(controller.cloudSyncViewState().canUndoRestore)
        // 撤销成功后旧的失败码要清掉，页面状态栏不该继续挂着错误。
        assertNull(controller.lastErrorCode)
    }

    @Test
    fun `恢复失败不产生可撤销点`() {
        val local = repository()
        local.addCourse(course("local-course"))
        val (controller, _) = controllerWithRemote(
            local,
            remoteCourseId = "remote-course",
            snapshotApplier = { SnapshotApplyResult.Failed("sync_snapshot_apply_failed") },
        )

        assertEquals(SyncResultKind.FAILED, controller.openBackup("backup.mikcb"))
        assertFalse(controller.canUndoLastRestore)
        assertFalse(controller.backupListViewState().canUndoRestore)
        assertFalse(controller.cloudSyncViewState().canUndoRestore)
    }

    @Test
    fun `本机原本没有课表时恢复成功也没有可撤销点`() {
        val local = repository() // 没有任何档案 → 恢复前的快照构建不出来
        val (controller, _) = controllerWithRemote(local, remoteCourseId = "remote-course")

        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))
        // 没有「恢复前」可回退的东西，就不能给用户一个点了没用的撤销按钮。
        assertFalse(controller.canUndoLastRestore)
        assertFalse(controller.backupListViewState().canUndoRestore)
    }

    @Test
    fun `撤销写回失败时保留撤销点并记录错误码`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        val remoteBytes = buildSyncSnapshotBytes(profileId = "pRemote")
        transport.files["${folder}backup.mikcb"] = remoteBytes
        // 「当前现场」可控：恢复前 = 本地那份；恢复成功后 = 远端那份（模拟真实写回生效）。
        var currentBytes = buildSyncSnapshotBytes(profileId = "pLocal")
        var applyCalls = 0
        val controller = CloudSyncController(
            store = FakeConfigStore(),
            snapshotStore = FakeLocalSnapshotStore(),
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
            snapshotProvider = { SnapshotBuildResult.Success(currentBytes) },
            snapshotApplier = {
                applyCalls++
                if (applyCalls == 1) {
                    SnapshotApplyResult.Applied // 模拟恢复写回成功
                } else {
                    SnapshotApplyResult.Failed("sync_snapshot_apply_failed")
                }
            },
            undoStore = CloudSyncUndoStore(),
        )
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()
        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))
        currentBytes = remoteBytes

        assertFalse(controller.undoLastRestore())
        assertEquals("sync_snapshot_apply_failed", controller.lastErrorCode)
        // 写回失败时撤销点不能丢：用户还可以再试一次。
        assertTrue(controller.canUndoLastRestore)
    }

    // ---------- 进页加载 ----------

    /** 已配置好账号（存档里有用户名 + 密码）但没有「本次会话连接」的控制器：模拟重启后进页。 */
    private fun configuredController(
        repository: TimetableRepository,
        transport: FakeRemoteTransport,
    ): CloudSyncController {
        val store = FakeConfigStore(
            config = WebdavSyncConfig().copyWith(username = "me@example.com", enabled = true),
            password = "pw",
        )
        return CloudSyncController(
            store = store,
            snapshotStore = FakeLocalSnapshotStore(),
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
            repository = repository,
            passwordProvider = { store.password },
            undoStore = CloudSyncUndoStore(),
        )
    }

    @Test
    fun `进页自动加载_备份列表不再恒空`() {
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        transport.files["${folder}backup.mikcb"] = remoteSnapshotBytes("remote-course")
        val controller = configuredController(repository(), transport)
        assertTrue(controller.backupListViewState().rows.isEmpty())

        controller.refreshOnEnter()

        assertEquals(1, controller.backupListViewState().rows.size)
    }

    @Test
    fun `未配置账号时进页加载不写错误码`() {
        val controller = controller(repository())

        controller.refreshOnEnter()

        assertNull(controller.lastErrorCode)
        assertTrue(controller.backupListViewState().rows.isEmpty())
    }

    @Test
    fun `拉取失败时空态文案换成失败原因`() {
        val transport = FakeRemoteTransport()
        val controller = configuredController(repository(), transport)
        transport.listResultOverride =
            com.mutx163.qingyu.sync.HistoryListResult.failed("connection_failed")

        controller.refreshOnEnter()

        val state = controller.backupListViewState()
        assertTrue(state.isEmpty)
        assertEquals(SyncStrings.syncErrorConnectionFailed.zh, state.errorText)
    }
}
