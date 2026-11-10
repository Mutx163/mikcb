package com.mutx163.qingyu.pages.transfer

import java.net.URLEncoder

/**
 * 局域网编辑页（`lib/screens/lan_edit_screen.dart`，489 行）模型层。
 *
 * ## 这一页在做什么
 *
 * 在手机上开一个局域网 HTTP 服务，同一 WiFi 下的电脑用浏览器连上来改课表。
 * 页面要显示：开关（开启/停止）、访问地址（IP:端口）、PIN、已连接客户端数、
 * 最近活动时间、二维码、以及「宿舍 WiFi 连不上就用热点」这类说明。
 *
 * ## 算数与生命周期不在这里
 *
 * 服务起停、IP 探测、端口占用、客户端计数都是 Android 侧的事
 * （Dart 对应 `LanEditServerService`；Kotlin 对应 `share/LanEditSession`）。
 * 本类只负责**把服务状态翻译成屏上文字**，这几条正是最容易写错、又最值得单测的：
 *
 * 1. **访问地址**：没拿到 IP 时显示「未检测到局域网 IP…」而不是 `:8080` 这种半截地址；
 * 2. **地址拼法**：`http://ip:port?pin=<PIN>`（发布版 `encodeLanEditUrl` 同口径，
 *    电脑扫码/粘贴后网页端按 `?pin=` 自动登录，不用手输 6 位 PIN）；
 * 3. **已连接客户端**：0 台时 Dart 显示「暂无」，不是「0 台」；
 * 4. **开关态**：运行中显示「停止」，停止时显示「开启局域网编辑」。
 */
class LanEditModel(
    /** 服务是否在跑。 */
    val running: Boolean = false,
    /** 局域网 IPv4；null / 空串 = 没探测到。 */
    val ipAddress: String? = null,
    /** 监听端口；0 / null = 未就绪。 */
    val port: Int? = null,
    /** 会话 PIN（电脑端要输入）。 */
    val pin: String? = null,
    /** 当前已连接的电脑台数。 */
    val connectedClients: Int = 0,
    /** 最近一次活动时间文本（已格式化）；null = 还没有活动。 */
    val lastActivityText: String? = null,
    /** 「离开后保持开启」开关当前值。 */
    val keepAliveWhenLeaving: Boolean = false,
    /** 启动失败的原因（已在别处格式化）；null = 没出错。 */
    val startFailedReason: String? = null,
) {

    val title: String get() = TransferExtStrings.lanEditTitle.text
    val intro: String get() = TransferExtStrings.lanEditIntro.text
    val runningLabel: String get() = TransferExtStrings.lanEditStatusRunning.text
    val addressLabel: String get() = TransferExtStrings.lanEditAddressLabel.text
    val pinLabel: String get() = TransferExtStrings.lanEditPinLabel.text
    val portLabel: String get() = TransferExtStrings.lanEditPortLabel.text
    val copyAddressLabel: String get() = TransferExtStrings.lanEditCopyAddress.text
    val copiedMessage: String get() = TransferExtStrings.lanEditCopied.text
    val hotspotHint: String get() = TransferExtStrings.lanEditHotspotHint.text
    val qrHint: String get() = TransferExtStrings.lanEditQrHint.text
    val keepAliveTitle: String get() = TransferExtStrings.lanEditKeepAliveWhenLeavingTitle.text
    val keepAliveSubtitle: String get() = TransferExtStrings.lanEditKeepAliveWhenLeavingSubtitle.text
    val clientsLabel: String get() = TransferExtStrings.lanEditConnectedClientsLabel.text
    val lastActivityLabel: String get() = TransferExtStrings.lanEditLastActivityLabel.text

    /** 主按钮文字：运行中显示「停止」，否则显示「开启局域网编辑」（Dart 三态里的两态）。 */
    val primaryActionLabel: String
        get() = if (running) TransferExtStrings.lanEditStop.text else TransferExtStrings.lanEditStart.text

    /**
     * 访问地址（二维码与「复制地址」都用它）。
     *
     * 没 IP / 没端口时**必须**显示那句提示，不能拼出 `http://:8080`：用户拿这个地址去浏览器
     * 打不开，会误以为是 App 坏了。基形与发布版 `encodeLanEditUrl` 逐字一致：**端口后带尾斜杠**
     * （`http://host:port/`），有 PIN 时再接 `?pin=`——电脑扫二维码打开网页后会自动登录；
     * 不发这条查询参数，用户就得从手机上再抄 6 位 PIN（发布版不需要）。
     */
    val addressText: String
        get() {
            val ip = ipAddress?.trim().orEmpty()
            val p = port ?: 0
            if (ip.isEmpty() || p <= 0) {
                return TransferExtStrings.lanEditAddressUnavailable.text
            }
            // 发布版 encodeLanEditUrl：final base = 'http://$host:$port/'; 查询串接在尾斜杠后。
            val base = "http://$ip:$p/"
            val pinValue = pin?.trim().orEmpty()
            if (pinValue.isEmpty()) {
                return base
            }
            return "$base?pin=${URLEncoder.encode(pinValue, "UTF-8")}"
        }

    /** 地址是否可用（渲染层据此决定「复制地址」能不能点）。 */
    val hasAddress: Boolean
        get() = !ipAddress.isNullOrBlank() && (port ?: 0) > 0

    /** 端口行文本；没端口时给空串（渲染层据此隐藏整行）。 */
    val portText: String
        get() = (port ?: 0).takeIf { it > 0 }?.toString() ?: ""

    /** PIN 行文本；没 PIN 时给空串。 */
    val pinText: String get() = pin?.takeIf { it.isNotBlank() } ?: ""

    /**
     * 已连接客户端文本。
     *
     * 0 台时是「暂无」而**不是**「0 台」—— Dart 侧就是两套文案
     * （`lanEditConnectedClientsNone` / `lanEditConnectedClientsValue`）。
     */
    val clientsText: String
        get() = if (connectedClients <= 0) {
            TransferExtStrings.lanEditConnectedClientsNone.text
        } else {
            TransferExtStrings.lanEditConnectedClientsValue.filled(
                "count" to connectedClients.toString(),
            )
        }

    /** 最近活动行；没有活动时给 null（渲染层据此不画这一行，而不是显示「-」）。 */
    val lastActivityLine: String?
        get() = lastActivityText?.takeIf { it.isNotBlank() }

    /** 启动失败提示；成功时 null。 */
    val startFailedText: String?
        get() = startFailedReason?.takeIf { it.isNotBlank() }?.let {
            TransferExtStrings.lanEditStartFailed.text + "：" + it
        }

    /** 页面该不该显示「会话信息块」（地址 / PIN / 端口 / 客户端）：只有跑起来才有意义。 */
    val showSessionBlock: Boolean get() = running && hasAddress
}
