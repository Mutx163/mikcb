package com.mutx163.qingyu.pages.transfer

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.LanEditForegroundService
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.pages.ShellWiring
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.share.LanAddressScoring
import com.mutx163.qingyu.share.LanEditSession
import com.mutx163.qingyu.transfer.lan.LanEditApiRouter
import com.mutx163.qingyu.transfer.lan.LanEditHttpServer
import com.mutx163.qingyu.transfer.lan.LanEditRepositoryHost
import com.mutx163.qingyu.transfer.lan.LanEditStaticAssets
import com.mutx163.qingyu.transfer.lan.LanTransferUndoStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface

/**
 * 局域网编辑页的**宿主**（壳 → 真服务的那一段接线）。
 *
 * 对应 Dart `lib/screens/lan_edit_screen.dart` + `LanEditServerService.shared`：
 * 页面不持业务状态，只画；起停、IP、端口、PIN、客户端数全在 [LanEditServiceRuntime]。
 *
 * ## 这一层之前缺什么
 *
 * 壳里原来是 `LanEditPage(model = LanEditModel(), onToggleRunning = {}, onCopyAddress = {},
 * onKeepAliveChange = {})` —— 一个**新建的空模型** + 三个空回调：开关不启服务、地址永远
 * 「未检测到局域网 IP」、复制点了没反应。底层（`LanEditHttpServer` / `LanEditApiRouter` /
 * `LanEditRepositoryHost` / `LanEditForegroundService`）其实全都写好了，缺的就是这一段。
 *
 * ## 与 Dart 对齐的几条行为
 *
 * - **服务是进程级单例**（Dart `LanEditServerService.shared`）：退出页面再进来，还要看到
 *   同一个 PIN / 端口 / 已连接台数，而不是「又开了一个」；
 * - **前台服务跟着服务起停**：起服务先起前台服务，起不来就把服务停回去并报「启动失败：
 *   原因」（Dart `_startServer` 的 `foreground_start_failed` 分支，**不许**留着「服务在跑
 *   但通知栏没有常驻条目」的半截状态）；
 * - **离开页面**：`离开后保持开启` 关着就停服（Dart `dispose` 读的是服务上的
 *   `retainAfterLeave`，不是本地字段——见 [LanEditPageLogic.shouldStopOnLeave]）；
 * - **最近活动时间**每秒刷新一次（Dart 是 2 秒状态定时器；这里只刷屏上文字，代价可忽略）。
 *
 * ## 诚实边界（不假装能跑的部分）
 *
 * 1. 静态资源**已接线**（`staticAssets = LanEditStaticAssets { …readFlutterAsset… }`）：
 *    控制台页面由 `transfer/lan/LanEditStaticAssets.kt` 从 Flutter asset 发，装配漏了这一项
 *    浏览器就是一片空白。**但「浏览器真能打开」没在真机上验过**，仍归用户验收。
 * 2. `import/apply` **不再是 501**：`378b801f`（2026-10-30）接上了真应用
 *    （`transfer/lan/LanTransferLogic.kt` 算差异 + `LanTransferApplier.kt` 写仓储）；
 *    2026-11-02 补上撤销点（`apply` 回真实 `transferId`，`POST /api/v1/import/undo`
 *    只回退这一批、保留用户之后的操作）。仍缺的是「设置只应用已移植子集」。
 * 3. 真机没对照过：端口是否真能连、通知栏常驻、关掉后是否真的打不开，全部归用户验收。
 */
@Composable
fun LanEditHost(
    wiring: ShellWiring,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val appContext = context.applicationContext
    val repository = wiring.timetable

    val store: KeyValueStore = remember(appContext) { PrefsKeyValueStore(appContext) }
    val scope = rememberCoroutineScope()

    var keepAlive by remember { mutableStateOf(LanEditPageLogic.DEFAULT_KEEP_ALIVE_WHEN_LEAVING) }
    var busy by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }
    // 每秒 +1：只为让下面读到的快照（客户端数 / 最近活动）重新求值。
    var tick by remember { mutableIntStateOf(0) }

    // 首帧就把「离开后保持开启」读出来：Dart 在此之前按钮是禁用的，
    // 因为它要用这个值决定「起服务后能不能活过页面退出」，读晚了会先按默认值起一次。
    LaunchedEffect(store) {
        keepAlive = withContext(Dispatchers.IO) {
            runCatching {
                store.getBool(
                    LanEditPageLogic.KEEP_ALIVE_PREF_KEY,
                    LanEditPageLogic.DEFAULT_KEEP_ALIVE_WHEN_LEAVING,
                )
            }.getOrDefault(LanEditPageLogic.DEFAULT_KEEP_ALIVE_WHEN_LEAVING)
        }
    }

    LaunchedEffect(Unit) {
        while (true) {
            delay(1_000)
            // 服务可能被自己的空闲看门狗停掉（会话过期）：这里顺手收尾，
            // 否则页面会一直显示「停止」按钮却没有服务在跑。
            if (LanEditServiceRuntime.hasStoppedUnexpectedly()) {
                LanEditServiceRuntime.stop()
            }
            tick++
        }
    }

    // 离开页面：按开关决定停不停（Dart `dispose`）。这里读的是**当前**开关值，
    // 不是首次组合时的那份快照。
    DisposableEffect(Unit) {
        onDispose {
            if (LanEditPageLogic.shouldStopOnLeave(keepAlive)) {
                LanEditServiceRuntime.stop()
            }
        }
    }

    val snapshot = remember(tick, keepAlive, failure) {
        LanEditServiceRuntime.snapshot().copy(
            keepAliveWhenLeaving = keepAlive,
            startFailedReason = failure,
        )
    }
    val model = LanEditPageLogic.modelFrom(snapshot)

    LanEditPage(
        model = model,
        onBack = onBack,
        onToggleRunning = {
            when (LanEditPageLogic.toggleIntent(running = snapshot.running, busy = busy)) {
                LanEditToggle.START -> {
                    busy = true
                    failure = null
                    scope.launch {
                        val error = withContext(Dispatchers.IO) {
                            LanEditServiceRuntime.start(repository, appContext)
                        }
                        failure = error
                        busy = false
                    }
                }

                LanEditToggle.STOP -> {
                    busy = true
                    scope.launch {
                        withContext(Dispatchers.IO) { LanEditServiceRuntime.stop() }
                        failure = null
                        busy = false
                    }
                }

                LanEditToggle.NONE -> Unit
            }
        },
        onCopyAddress = {
            // 没有可用地址时**什么都不做**：把「未检测到局域网 IP…」复制进剪贴板，
            // 用户粘到浏览器里打不开，还会以为复制成功了（Dart `_copyAddress` 同义）。
            val address = LanEditPageLogic.addressToCopy(model)
            if (address != null) {
                val clipboard = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                clipboard?.setPrimaryClip(ClipData.newPlainText(model.addressLabel, address))
                Toast.makeText(appContext, model.copiedMessage, Toast.LENGTH_SHORT).show()
            }
        },
        onKeepAliveChange = { enabled ->
            keepAlive = enabled
            scope.launch {
                withContext(Dispatchers.IO) {
                    runCatching {
                        store.putBool(LanEditPageLogic.KEEP_ALIVE_PREF_KEY, enabled)
                    }
                }
            }
        },
    )
}

/**
 * 进程内唯一的局域网编辑服务（Dart `LanEditServerService.shared` 的对应物）。
 *
 * 为什么必须是单例：服务活着的期间会亮一条常驻通知、绑一个端口、持一个 PIN。
 * 页面重建（转屏、返回再进、进程还没死）时若各起一份，就会出现「两个端口两套 PIN，
 * 电脑连上的是上一个」这种查不出来的问题。
 *
 * 线程：起停都要绑套接字 / 亮通知，**调用方用 `Dispatchers.IO`**；本对象内部加锁，
 * 保证并发调用不会起两份。
 */
object LanEditServiceRuntime {

    private val lock = Any()

    private var server: LanEditHttpServer? = null
    private var session: LanEditSession? = null
    private var lanAddress: String? = null

    /**
     * 启动时那次 `applicationContext`：停服时要靠它去 `stopService`。
     *
     * 存 applicationContext 不会泄漏（它跟着进程生命周期走），也因此**页面退出后**
     * 仍能停掉常驻通知——停服可能发生在页面已经销毁之后（`onDispose`）。
     */
    private var appContext: Context? = null

    val isRunning: Boolean
        get() = synchronized(lock) { server != null && server?.isRunning == true }

    /** 服务还挂着、但套接字已经不在（空闲看门狗停的）——页面据此收尾。 */
    fun hasStoppedUnexpectedly(): Boolean = synchronized(lock) {
        server != null && server?.isRunning != true
    }

    /** 当前状态（没起来就是全空，页面会显示「开启局域网编辑」）。 */
    fun snapshot(): LanEditRuntimeSnapshot = synchronized(lock) {
        val active = server
        val current = session
        if (active == null || current == null || !active.isRunning) {
            return LanEditRuntimeSnapshot()
        }
        LanEditRuntimeSnapshot(
            running = true,
            ipAddress = lanAddress,
            port = active.port.takeIf { it > 0 },
            pin = current.pin,
            connectedClients = current.connectedClientCount,
            lastActivityAtMillis = current.lastActivityAtMillis,
        )
    }

    /**
     * 起服务。
     *
     * @return null = 成功；非 null = 失败原因（原文交给页面拼成「启动失败：…」，与 Dart 一样
     *   直接把异常文本透出去，不在这里编人话）。
     */
    fun start(repository: TimetableRepository, context: Context): String? {
        synchronized(lock) {
            if (server != null) return null
            var startedServer: LanEditHttpServer? = null
            appContext = context.applicationContext
            return try {
                val newSession = LanEditSession.create()
                val router = LanEditApiRouter(
                    // 撤销点按进程存活：停服再开仍能撤销上一个导入（杀进程才失效）。
                    host = LanEditRepositoryHost(repository, undoStore = LanTransferUndoStore.shared),
                    session = newSession,
                )
                val newServer = LanEditHttpServer(
                    router = router,
                    // 控制台页面与静态资源：不传这一项，电脑浏览器打开地址就是一片空白
                    // （`/` 落到路由层是 404，而 `/api/v1/*` 全通，现象上很难反推）。
                    staticAssets = LanEditStaticAssets { assetPath -> readConsoleAsset(context, assetPath) },
                )
                newServer.start()
                startedServer = newServer
                server = newServer
                session = newSession
                lanAddress = pickLanIPv4()

                val foregroundStarted = startForegroundService(context)
                if (!foregroundStarted) {
                    // 与 Dart 一致：前台服务起不来就**回滚**，不留「服务在跑但通知栏没有
                    // 常驻条目」的半截状态（那种状态下用户切后台，服务会被系统回收，
                    // 电脑端却在界面上显示「已连接」）。
                    stopLocked()
                    "foreground_service_unavailable"
                } else {
                    null
                }
            } catch (error: Throwable) {
                runCatching { startedServer?.stop("start_failed") }
                server = null
                session = null
                lanAddress = null
                runCatching { appContext?.let { stopForegroundService(it) } }
                appContext = null
                error.message?.takeIf { it.isNotBlank() } ?: (error::class.simpleName ?: "start_failed")
            }
        }
    }

    /** 停服务（幂等）。 */
    fun stop() {
        synchronized(lock) {
            stopLocked()
        }
    }

    private fun stopLocked() {
        val active = server
        val context = appContext
        server = null
        session = null
        lanAddress = null
        appContext = null
        runCatching { active?.stop("manual") }
        if (context != null) {
            runCatching { stopForegroundService(context) }
        }
    }

    private fun startForegroundService(context: Context): Boolean = runCatching {
        val intent = LanEditForegroundService.buildStartIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        true
    }.getOrDefault(false)

    private fun stopForegroundService(context: Context) {
        context.stopService(
            Intent(context, LanEditForegroundService::class.java).apply {
                action = LanEditForegroundService.ACTION_STOP
            },
        )
    }

    /**
     * 本机最可能的局域网 IPv4。
     *
     * 枚举网卡是 IO（`NetworkInterface.list` 的等价物），挑哪一条是纯逻辑，
     * 用已在仓库里的 [LanAddressScoring]（192.168 > 10 > 172.16-31 > 其它，
     * 并过滤环回与 169.254 链路本地），不在这里另写一套排序。
     */
    private fun pickLanIPv4(): String? {
        val candidates = mutableListOf<String>()
        runCatching {
            for (networkInterface in NetworkInterface.getNetworkInterfaces()) {
                if (!networkInterface.isUp || networkInterface.isLoopback) continue
                for (address: InetAddress in networkInterface.inetAddresses) {
                    if (address !is Inet4Address) continue
                    if (address.isLoopbackAddress || address.isLinkLocalAddress) continue
                    address.hostAddress?.let { candidates.add(it) }
                }
            }
        }
        return LanAddressScoring.pickPreferredLanIPv4(candidates)
    }

    /**
     * 读一个打包在**主 assets** 里的控制台资源（Dart 侧 `rootBundle.load('assets/lan_edit/index.html')`
     * 的对应物）。
     *
     * ## 为什么只有一条路径
     *
     * 2026-11-02 资产迁移：`assets/lan_edit/`（含 `mapAssetPath` 里 favicon 用的
     * `assets/branding/launcher_icon.png`）已拷进 `android/app/src/main/assets/`，
     * Compose 不再依赖 Flutter 工具链打进 APK 的 `flutter_assets/` 目录——删 Flutter 后
     * 那个目录**永不再生成**。原先「先 `flutter_assets/` 再裸路径」的双前缀回退已删：
     * 留着它，删 Flutter 后每次读取都要先撞一条死路径。
     *
     * @return null = 资产没打包进去（调用方回 404，与「页面没打包进去」这个事实一致）。
     */
    private fun readConsoleAsset(context: Context, assetPath: String): ByteArray? {
        val bytes = runCatching {
            context.assets.open(assetPath).use { it.readBytes() }
        }.getOrNull()
        return if (bytes != null && bytes.isNotEmpty()) bytes else null
    }
}
