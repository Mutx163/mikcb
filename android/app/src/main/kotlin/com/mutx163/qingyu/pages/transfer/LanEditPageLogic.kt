package com.mutx163.qingyu.pages.transfer

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * 局域网编辑页的**运行时快照**：服务真正报出来的那一组状态。
 *
 * 与 [LanEditModel] 的关系是「原始值 → 屏上文字」：这里只装原始值
 * （毫秒时间戳、裸 IP、端口号），一切给人看的拼装都在 [LanEditModel] 里做
 * （那些拼装已有 18 例单测钉着）。这样同一份快照换到二维码 / 通知栏里
 * 复用时不用重算文案。
 */
data class LanEditRuntimeSnapshot(
    val running: Boolean = false,
    /** 局域网 IPv4；null / 空串 = 没探测到。 */
    val ipAddress: String? = null,
    /** 服务真正绑上的端口；0 / null = 未就绪。 */
    val port: Int? = null,
    /** 本次会话 PIN（电脑端要输入）。 */
    val pin: String? = null,
    val connectedClients: Int = 0,
    /** 最近一次活动时间（epoch 毫秒）；null = 还没有活动。 */
    val lastActivityAtMillis: Long? = null,
    val keepAliveWhenLeaving: Boolean = false,
    /** 启动失败原因；null = 没出错。 */
    val startFailedReason: String? = null,
)

/** 主按钮该做什么。`NONE` = 现在点了也不该动（正在起停 / 状态未知）。 */
enum class LanEditToggle { START, STOP, NONE }

/**
 * 局域网编辑页的纯逻辑（可进 JVM 单测的部分）。
 *
 * 起停服务、枚举网卡、写剪贴板都是 Android 依赖，留在
 * `composeP1/pages/transfer/LanEditHost.kt`；这里只留「能不问 Android 就判对」的四件事：
 *
 * 1. **快照 → 模型**：最近活动时间戳要格式化成人能读的串（Dart `DateFormat.yMd().add_Hms()`）；
 * 2. **主按钮意图**：正在起停时必须不响应，运行中必须给「停止」；
 * 3. **复制地址**：没有可用地址时**不许把提示句复制进剪贴板**（Dart `_copyAddress` 里
 *    `if (address == null) return;` 同义）；
 * 4. **「离开后保持开启」的落盘键**：与 Dart `LanEditPreferences.keepAliveWhenLeavingKey`
 *    逐字一致，否则两边各读各的值。
 */
object LanEditPageLogic {

    /**
     * 「离开后保持开启」的偏好键。
     *
     * **必须与 Dart 逐字一致**：`lib/services/lan_edit_preferences.dart:14`
     * （`lan_edit_keep_alive_when_leaving`）。Flutter 的 `shared_preferences` 在 Android 上
     * 落进 `FlutterSharedPreferences` 并以 `flutter.` 前缀存键，`PrefsKeyValueStore` 会自动补前缀，
     * 所以这里给的是**逻辑键**（不带 `flutter.`）。
     */
    const val KEEP_ALIVE_PREF_KEY = "lan_edit_keep_alive_when_leaving"

    /** 与 Dart `LanEditPreferences.defaultKeepAliveWhenLeaving` 一致：默认关（退出页面即停服）。 */
    const val DEFAULT_KEEP_ALIVE_WHEN_LEAVING = false

    /**
     * 最近活动时间的格式：`2026/10/29 22:31:05`。
     *
     * Dart 用 `DateFormat.yMd().add_Hms()`（**跟随系统区域**，英文区会印成 `10/29/2026`）。
     * 这里固定 `yyyy/M/d`：一页说明文字里混两种日期顺序更让人困惑，且固定格式可单测。
     * 差异记在认领文件「差异与风险」里。
     */
    private val LAST_ACTIVITY_FORMATTER: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy/M/d HH:mm:ss")

    fun formatLastActivity(millis: Long, zone: ZoneId = ZoneId.systemDefault()): String =
        LAST_ACTIVITY_FORMATTER.format(Instant.ofEpochMilli(millis).atZone(zone))

    /** 快照 → 屏上模型。`null` 的时间戳保持 null（模型层据此整行不画，而不是印一个占位符）。 */
    fun modelFrom(snapshot: LanEditRuntimeSnapshot, zone: ZoneId = ZoneId.systemDefault()): LanEditModel =
        LanEditModel(
            running = snapshot.running,
            ipAddress = snapshot.ipAddress,
            port = snapshot.port,
            pin = snapshot.pin,
            connectedClients = snapshot.connectedClients,
            lastActivityText = snapshot.lastActivityAtMillis?.let { formatLastActivity(it, zone) },
            keepAliveWhenLeaving = snapshot.keepAliveWhenLeaving,
            startFailedReason = snapshot.startFailedReason,
        )

    /**
     * 「复制地址」要放进剪贴板的内容；没有可用地址时返回 null（宿主据此不写剪贴板、不弹提示）。
     *
     * 不能退化成 `model.addressText`：那句话是**给人看的提示**（「未检测到局域网 IP…」），
     * 复制进剪贴板后用户粘到浏览器里会打不开，还会以为复制成功了。
     */
    fun addressToCopy(model: LanEditModel): String? =
        if (model.hasAddress) model.addressText else null

    /**
     * 主按钮这一下该做什么。
     *
     * @param busy 正在起 / 正在停。此时必须 `NONE`：Dart 侧 `_isStarting` / `_isStopping`
     *   期间按钮直接 `onPressed: null`，连点两次会真的起两个服务再停掉一个。
     */
    fun toggleIntent(running: Boolean, busy: Boolean): LanEditToggle = when {
        busy -> LanEditToggle.NONE
        running -> LanEditToggle.STOP
        else -> LanEditToggle.START
    }

    /**
     * 离开页面时该不该停服务。
     *
     * Dart `dispose` 读的是**服务上的** `retainAfterLeave`（开关一改就同步过去），
     * 不是本地字段——异步 bootstrap 与用户点击会赛跑。Kotlin 侧同一个坑：
     * 传进来的必须是宿主当前持有的那份值，不要让渲染层另存一份。
     */
    fun shouldStopOnLeave(keepAliveWhenLeaving: Boolean): Boolean = !keepAliveWhenLeaving
}
