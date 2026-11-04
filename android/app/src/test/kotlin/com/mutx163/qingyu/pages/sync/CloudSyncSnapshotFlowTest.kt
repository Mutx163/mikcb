package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.sync.WebdavSyncConfig
import com.mutx163.qingyu.sync.decodeSnapshotObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
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
    fun `自动同步_远近一致时不重复发布且返回已一致`() {
        // Dart `decideWebdavAutoUpload`：远端哈希 == 本机字节哈希 → upToDate，
        // 不发布新版本化正文、不写历史文件。此前 Kotlin 没有这道闸，每次自动同步
        // 都会在云端多堆一份一模一样的备份。
        val repository = repository()
        repository.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val controller = controller(repository, transport)
        controller.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, controller.createBackup())
        val backupsBefore = transport.files.keys.count { it.endsWith(".mikcb") }

        assertEquals(SyncResultKind.UP_TO_DATE, controller.syncNow())
        assertEquals(
            "已一致时不得再写任何快照文件",
            backupsBefore,
            transport.files.keys.count { it.endsWith(".mikcb") },
        )
    }

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

    // ---------- 下载：空壳本机的冲突预决策 ----------

    @Test
    fun `空壳本机首次同步_不弹选边框直接采用云端`() {
        // Dart `resolveManualPullConflictChoice`：本机没有用户亲手沉淀的数据
        //（全新设备 / 只有出厂默认档案）时，首次同步分歧不弹「选边」框，直接以云端为准。
        // 此前 Kotlin 恒传 hasLocalUserData = true，空壳设备也会被弹框拦住。
        val repository = repository() // 盘上没有任何档案
        val transport = FakeRemoteTransport()
        val controller = controller(repository, transport)
        controller.connect("me@example.com", "pw")
        seedRemoteSnapshot(
            transport = transport,
            config = controller.config,
            bytes = remoteSnapshotBytes("remote-course"),
            deviceId = "devB",
        )

        assertEquals(SyncResultKind.DOWNLOADED, controller.syncNow())
        assertNull("空壳本机没有可保护的数据，不该挂起冲突", controller.pendingSyncConflict)
        assertTrue(
            "应直接把云端课表写回本机",
            repository.snapshot.profiles.flatMap { it.courses }.any { it.id == "remote-course" },
        )
    }

    @Test
    fun `有本地课表时首次同步分歧_仍挂起选边`() {
        // 同一路径的另一侧：本机确有自己的课时 → 必须让用户选边，绝不静默覆盖。
        val repository = repository()
        repository.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val controller = controller(repository, transport)
        controller.connect("me@example.com", "pw")
        seedRemoteSnapshot(
            transport = transport,
            config = controller.config,
            bytes = remoteSnapshotBytes("remote-course"),
            deviceId = "devB",
        )

        assertEquals(SyncResultKind.CANCELLED, controller.syncNow())
        val conflict = controller.pendingSyncConflict
        assertNotNull("有本地用户数据必须挂起冲突", conflict)
        assertTrue(conflict!!.localHasUserData)
        assertTrue(
            "挂起期间本机课表不得被覆盖",
            repository.snapshot.profiles.flatMap { it.courses }.any { it.id == "local-course" },
        )
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
    fun `数千条课时与多档案的大快照恢复成功且可撤销`() {
        // 2026-11-03 大包硬化：6 档案 × 400 课时 = 2400 条课时，快照 JSON ≈ 数 MB。
        // 钉两件事：①整条「编码 → 下载 → 应用 → 撤销点」链路不因规模退化/抛错；
        // ②撤销后回到恢复前的档案数，撤销点不被大字节截断。
        val remote = repository()
        val profiles = (1..6).map { p ->
            TimetableProfile(
                id = "big-p$p",
                name = "档案$p",
                courses = (1..400).map { c -> course("big-$p-$c") },
                currentWeek = 3,
                createdAt = java.time.LocalDateTime.of(2026, 2, 1, 0, 0),
                lastUsedAt = java.time.LocalDateTime.of(2026, 2, 2, 0, 0),
            )
        }
        remote.replaceAllProfiles(profiles, "big-p1")
        val local = repository()
        local.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val folder = WebdavSyncConfig().historyRemoteFolder
        val result = TimetableSnapshotBridge.buildSnapshotBytes(
            repository = remote,
            deviceId = "devBig",
            exportedAtIso = "2026-03-06T08:00:00.000",
        )
        assertTrue(result is SnapshotBuildResult.Success)
        val bytes = result as SnapshotBuildResult.Success
        transport.files["${folder}backup.mikcb"] = bytes.bytes
        val controller = controller(local, transport)
        controller.connect("me@example.com", "pw")
        controller.refreshBackups()

        assertEquals(SyncResultKind.DOWNLOADED, controller.openBackup("backup.mikcb"))
        assertEquals(6, local.snapshot.profiles.size)
        assertEquals(2400, local.snapshot.profiles.sumOf { it.courses.size })
        assertTrue("恢复成功必须留下撤销点", controller.canUndoLastRestore)
        assertTrue(bytes.bytes.size > 200_000)

        assertTrue(controller.undoLastRestore())
        assertEquals(1, local.snapshot.profiles.size)
        assertEquals("local-course", local.snapshot.courses.single().id)
        assertFalse(controller.canUndoLastRestore)
    }

    @Test
    fun `恢复提交落盘失败后重启再恢复_不产生重复档案与课时`() {
        // 2026-11-03 硬化：模拟「persist 写一半就被杀」——本机快照与课表都已写入，
        // 但基线钉落盘失败，commitRestoredSnapshot 回滚；随后用户重开 App（撤销点是内存态，
        // 重启即丢）再恢复同一份备份。钉两件事：
        // ①第一次失败后本机必须回到恢复前那份；②第二次恢复按整份替换，档案/课时绝不翻倍。
        val remote = repository()
        remote.replaceAllProfiles(
            (1..3).map { p ->
                TimetableProfile(
                    id = "idem-p$p",
                    name = "档案$p",
                    courses = (1..5).map { c -> course("idem-$p-$c") },
                    currentWeek = 2,
                    createdAt = java.time.LocalDateTime.of(2026, 2, 1, 0, 0),
                    lastUsedAt = java.time.LocalDateTime.of(2026, 2, 2, 0, 0),
                )
            },
            "idem-p1",
        )
        val build = TimetableSnapshotBridge.buildSnapshotBytes(
            repository = remote,
            deviceId = "devIdem",
            exportedAtIso = "2026-03-06T08:00:00.000",
        )
        assertTrue(build is SnapshotBuildResult.Success)
        val bytes = (build as SnapshotBuildResult.Success).bytes

        val transport = FakeRemoteTransport()
        transport.files["${WebdavSyncConfig().historyRemoteFolder}backup.mikcb"] = bytes
        val local = repository()
        local.addCourse(course("local-course"))
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        fun controllerForAttempt(): CloudSyncController = CloudSyncController(
            store = store,
            snapshotStore = snapshotStore,
            transportFactory = { _, _ -> transport },
            deviceLabel = "测试机",
            clock = { "2026-03-07T09:05:00+08:00" },
            repository = local,
            undoStore = CloudSyncUndoStore(),
        )

        // 第一次：连接/列表正常，恢复临门一脚时配置落盘失败。
        val first = controllerForAttempt()
        first.connect("me@example.com", "pw")
        first.refreshBackups()
        store.failSave = true
        assertEquals(SyncResultKind.FAILED, first.openBackup("backup.mikcb"))
        assertEquals("backup_restore_commit_failed", first.lastErrorCode)
        assertEquals("第一次失败必须回滚到恢复前", 1, local.snapshot.profiles.size)
        assertEquals(listOf("local-course"), local.snapshot.courses.map { it.id })

        // 重开 App：同一份存储与仓储，重新建控制器（撤销点已随进程消失）。
        store.failSave = false
        val second = controllerForAttempt()
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals(SyncResultKind.DOWNLOADED, second.openBackup("backup.mikcb"))

        assertEquals("重开后恢复不得叠加档案", 3, local.snapshot.profiles.size)
        assertEquals(
            "重开后恢复不得叠加课时",
            listOf("idem-p1", "idem-p2", "idem-p3"),
            local.snapshot.profiles.map { it.id },
        )
        assertEquals(
            "课时总数应是 3×5，而不是 3×5×2",
            15,
            local.snapshot.profiles.sumOf { it.courses.size },
        )
        assertEquals(
            "课时 id 不允许重复",
            15,
            local.snapshot.profiles.flatMap { it.courses }.map { it.id }.toSet().size,
        )
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

    // ---------- 进程被杀在中途（第四轮：恢复 / 上传各 3 个中断点） ----------

    /** 同一份存储 + 同一份假远端重建控制器 = 「杀进程后重开 App」。 */
    private fun restartingController(
        store: FakeConfigStore,
        snapshotStore: FakeLocalSnapshotStore,
        transport: FakeRemoteTransport,
        repository: TimetableRepository,
        snapshotApplier: ((ByteArray) -> SnapshotApplyResult)? = null,
    ): CloudSyncController = CloudSyncController(
        store = store,
        snapshotStore = snapshotStore,
        transportFactory = { _, _ -> transport },
        deviceLabel = "测试机",
        clock = { "2026-03-07T09:05:00+08:00" },
        repository = repository,
        snapshotApplier = snapshotApplier,
        undoStore = CloudSyncUndoStore(),
    )

    private fun FakeRemoteTransport.versionedBodies(): List<String> =
        files.keys.filter { it.endsWith(".mikcb") && !it.contains("/history/") }

    private fun FakeRemoteTransport.historyFiles(): List<String> =
        files.keys.filter { it.contains("/history/") && it.endsWith(".mikcb") }

    @Test
    fun `上传中断_正文已写meta未写_重启续跑只留一份`() {
        // 被杀点：版本化正文已 PUT，meta 指针还没发。远端处于「有正文、无指针」的半写状态。
        val local = repository()
        local.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        val first = restartingController(store, snapshotStore, transport, local)
        first.connect("me@example.com", "pw")
        var putCount = 0
        transport.beforePut = {
            putCount++
            if (putCount == 2) throw KilledMidway() // 第 2 个 PUT = meta（正文已是第 1 个）
        }
        try {
            first.createBackup()
            fail("应在 meta 之前被杀")
        } catch (_: KilledMidway) {
        }
        transport.beforePut = {}
        assertFalse("被杀在 meta 前：指针不存在", transport.files.containsKey(first.config.metaRemotePath))
        assertEquals("正文已经落地", 1, transport.versionedBodies().size)

        val second = restartingController(store, snapshotStore, transport, local)
        second.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.UPLOADED, second.syncNow())

        assertTrue("续跑必须补上指针", transport.files.containsKey(second.config.metaRemotePath))
        assertEquals("同一内容只留一份正文", 1, transport.versionedBodies().size)
        assertEquals("只写一条历史", 1, transport.historyFiles().size)
        assertNull(second.pendingSyncConflict)
    }

    @Test
    fun `上传中断_meta已写历史未写_重启不弹假冲突也不重复发布`() {
        // 被杀点：meta 已发布，历史文件还没写。重启时本机课表 == 远端，绝不能再弹「选边」。
        val local = repository()
        local.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        val first = restartingController(store, snapshotStore, transport, local)
        first.connect("me@example.com", "pw")
        var putCount = 0
        transport.beforePut = {
            putCount++
            if (putCount == 3) throw KilledMidway() // 第 3 个 PUT = 历史文件
        }
        try {
            first.createBackup()
            fail("应在历史文件之前被杀")
        } catch (_: KilledMidway) {
        }
        transport.beforePut = {}
        assertTrue("meta 已经发布", transport.files.containsKey(first.config.metaRemotePath))
        assertTrue("历史还没写", transport.historyFiles().isEmpty())

        val second = restartingController(store, snapshotStore, transport, local)
        second.connect("me@example.com", "pw")
        val kind = second.syncNow()

        assertEquals(SyncResultKind.DOWNLOADED, kind)
        assertNull("本机与远端一致时不得挂起冲突", second.pendingSyncConflict)
        assertTrue("已一致时不得重复写历史", transport.historyFiles().isEmpty())
        assertEquals("正文不得翻倍", 1, transport.versionedBodies().size)
    }

    @Test
    fun `上传中断_历史已写索引未写_重启列表从listing自愈`() {
        // 被杀点：历史文件已写，index.json 还没写。重启后备份列表必须从 listing 恢复出这一条。
        val local = repository()
        local.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        val first = restartingController(store, snapshotStore, transport, local)
        first.connect("me@example.com", "pw")
        var putCount = 0
        transport.beforePut = {
            putCount++
            if (putCount == 4) throw KilledMidway() // 第 4 个 PUT = index.json
        }
        try {
            first.createBackup()
            fail("应在索引之前被杀")
        } catch (_: KilledMidway) {
        }
        transport.beforePut = {}
        assertFalse(
            "索引还没写",
            transport.files.containsKey(first.config.historyIndexRemotePath),
        )
        assertEquals("历史已经落盘", 1, transport.historyFiles().size)

        val second = restartingController(store, snapshotStore, transport, local)
        second.connect("me@example.com", "pw")
        assertEquals(SyncResultKind.DOWNLOADED, second.syncNow())
        assertNull(second.pendingSyncConflict)
        second.refreshBackups()

        assertEquals("索引缺失时按 listing 重建出一条，不许丢备份", 1, second.backupListViewState().rows.size)
    }

    @Test
    fun `恢复中断_远端已取回但本机快照没写成_重启重试成功`() {
        // 被杀点：远端字节已取回，写本机快照时进程死掉。磁盘上什么都不该变。
        val local = repository()
        local.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        transport.files["${WebdavSyncConfig().historyRemoteFolder}backup.mikcb"] =
            remoteSnapshotBytes("remote-course")
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        val first = restartingController(store, snapshotStore, transport, local)
        first.connect("me@example.com", "pw")
        first.refreshBackups()
        snapshotStore.failNextWrite = true
        try {
            first.openBackup("backup.mikcb")
            fail("应在写本机快照时被杀")
        } catch (_: IllegalIOException) {
        }
        assertNull("被杀在写快照前：文件不得留下远端内容", snapshotStore.stored)
        assertEquals(listOf("local-course"), local.snapshot.profiles.flatMap { it.courses }.map { it.id })

        val second = restartingController(store, snapshotStore, transport, local)
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals(SyncResultKind.DOWNLOADED, second.openBackup("backup.mikcb"))
        assertEquals(listOf("remote-course"), local.snapshot.profiles.flatMap { it.courses }.map { it.id })
    }

    @Test
    fun `恢复中断_快照文件已写课表还没写回_重启重试成功`() {
        // 被杀点：本机快照文件已被协调器覆盖，写回课表之前进程死掉。
        // 重启后文件「看起来像远端」，课表却还是旧的——重试必须把课表也换过去。
        val local = repository()
        local.addCourse(course("local-course"))
        val transport = FakeRemoteTransport()
        val remoteBytes = remoteSnapshotBytes("remote-course")
        transport.files["${WebdavSyncConfig().historyRemoteFolder}backup.mikcb"] = remoteBytes
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        val first = restartingController(
            store,
            snapshotStore,
            transport,
            local,
            snapshotApplier = { throw KilledMidway() },
        )
        first.connect("me@example.com", "pw")
        first.refreshBackups()
        try {
            first.openBackup("backup.mikcb")
            fail("应在写回课表时被杀")
        } catch (_: KilledMidway) {
        }
        assertArrayEquals("快照文件已换成远端那份", remoteBytes, snapshotStore.stored)
        assertEquals("课表还没被写回", listOf("local-course"), local.snapshot.profiles.flatMap { it.courses }.map { it.id })

        val second = restartingController(store, snapshotStore, transport, local)
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals(SyncResultKind.DOWNLOADED, second.openBackup("backup.mikcb"))
        assertEquals(listOf("remote-course"), local.snapshot.profiles.flatMap { it.courses }.map { it.id })
    }

    @Test
    fun `恢复中断_课表已写回收口未完成_重启不弹假冲突且不叠加`() {
        // 被杀点：课表已经写回，撤销点/基线钉还没写。重启后「本机==远端」，
        // 同步不得把它当成首次分歧弹「选边」，再恢复一次也不许让档案翻倍。
        val remote = repository()
        remote.replaceAllProfiles(
            (1..3).map { p ->
                TimetableProfile(
                    id = "kill-p$p",
                    name = "档案$p",
                    courses = (1..4).map { c -> course("kill-$p-$c") },
                    currentWeek = 2,
                    createdAt = java.time.LocalDateTime.of(2026, 2, 1, 0, 0),
                    lastUsedAt = java.time.LocalDateTime.of(2026, 2, 2, 0, 0),
                )
            },
            "kill-p1",
        )
        val remoteBytes = TimetableSnapshotBridge.buildSnapshotBytes(
            repository = remote,
            deviceId = "devKill",
            exportedAtIso = "2026-03-06T08:00:00.000",
        ).let { (it as SnapshotBuildResult.Success).bytes }
        val transport = FakeRemoteTransport()
        transport.files["${WebdavSyncConfig().historyRemoteFolder}backup.mikcb"] = remoteBytes
        val local = repository()
        local.addCourse(course("local-course"))
        val store = FakeConfigStore()
        val snapshotStore = FakeLocalSnapshotStore()

        val first = restartingController(
            store,
            snapshotStore,
            transport,
            local,
            snapshotApplier = { bytes ->
                TimetableSnapshotBridge.applySnapshot(local, bytes)
                throw KilledMidway() // 课表已写回，收口（撤销点/基线）还没做
            },
        )
        first.connect("me@example.com", "pw")
        first.refreshBackups()
        try {
            first.openBackup("backup.mikcb")
            fail("应在收口前被杀")
        } catch (_: KilledMidway) {
        }
        assertEquals("课表已写回", 3, local.snapshot.profiles.size)

        val second = restartingController(store, snapshotStore, transport, local)
        second.connect("me@example.com", "pw")
        second.refreshBackups()
        assertEquals(SyncResultKind.DOWNLOADED, second.openBackup("backup.mikcb"))

        assertEquals("重复恢复不得叠加档案", 3, local.snapshot.profiles.size)
        assertEquals(12, local.snapshot.profiles.sumOf { it.courses.size })
        assertEquals(
            "档案 id 不允许重复",
            3,
            local.snapshot.profiles.map { it.id }.toSet().size,
        )
        // 基线钉在收口之前就丢了，重启后的同步走「推本地」而不是再拉一次；
        // 这里只钉住用户可感知的一点：本机与远端一致，绝不能挂起「选边」。
        assertTrue("不得返回 CANCELLED（那是挂起选边）", second.syncNow() != SyncResultKind.CANCELLED)
        assertNull("本机==远端时不得弹假冲突", second.pendingSyncConflict)
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
