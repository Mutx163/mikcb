package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.import.ImportActionButton
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.AppRecording
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Phone
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.ScreenMirroring
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 教务网页登录与脚本执行容器页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart`：
 * 1. 顶栏操作：刷新、桌面/移动版切换、更多（复制地址/浏览器打开）；
 * 2. 教务会话状态提示与已存账号自动填入浮条；
 * 3. 宏录制状态与底部动作栏（开始/结束录制、执行导入脚本）。
 */
@Composable
fun WarehouseWebLoginPage(
    /** 顶栏标题；发布版传空（Dart `SizedBox.shrink()`），网页导入页通常不显示标题。 */
    title: String,
    sessionState: WarehouseWebLoginSessionState,
    // ---- task-21 接线新增：全部带默认值，不破坏任何现有调用点 ----
    // 控制句柄：调用方想自己持有（比如要在壳里发脚本）就传进来，否则页面自己记住一个。
    webViewController: WarehouseWebViewController = rememberWarehouseWebViewController(),
    /** 加载进度 0..100；由调用方回写 `sessionState`（页面是无状态渲染）。 */
    onWebProgress: (Int) -> Unit = {},
    /** 主框架导航开始 / 完成（地址已非空归一）。 */
    onWebPageStarted: (String) -> Unit = {},
    onWebPageFinished: (String) -> Unit = {},
    /** 主框架加载失败（子资源失败不会到这里）。 */
    onWebError: (WarehouseWebViewError) -> Unit = {},
    /**
     * `QingyuBridge` 收到的**已过门禁**的原始消息。
     *
     * ⚠️ 页面在把它交出去之前已经过 §6.2 的门禁（UI 类消息只在导入执行期放行）；
     * 调用方拿到的就是「可以处理」的消息，不需要再判一次。
     */
    onWebBridgeMessage: ((String) -> Unit)? = null,
    /**
     * 受信登录地址集合（适配器登记地址 + 受信自定义地址，见宿主）。
     * `loginAttempt` 门禁的「当前页在受信 host 上」放行锚点从这里来；
     * 空集合时该放行路径永不生效（门禁只会更严）。
     */
    trustedLoginUrls: List<String> = emptyList(),
    /** 前台宏回放中（宿主真实状态）：回放导航阶段的 UI 类消息靠它过 §6.2 门禁。 */
    foregroundReplayActive: Boolean = false,
    onBack: () -> Unit = {},
    onReload: () -> Unit = {},
    onToggleDesktopMode: () -> Unit = {},
    onMoreOptions: () -> Unit = {},
    onAutofillLogin: () -> Unit = {},
    onDismissAutofill: () -> Unit = {},
    onSaveRememberedLogin: () -> Unit = {},
    onDismissSaveLogin: () -> Unit = {},
    onToggleMacroRecording: () -> Unit = {},
    onExecuteImport: () -> Unit = {},
) {
    // 与 Dart 侧 warehouse_adapter_web_login_screen.dart:841-844 对齐
    // （title: SizedBox.shrink()、collapsibleLargeTitle: false）：这一页滚动发生在 WebView
    // 内部，大标题永远不会被收起，只会常驻占掉一行高度；用官方「单行小标题」变体钉死。
    // 骨架、返回键、主题桥统一走共享套件（R1）。
    QingyuPageScaffold(
        title = title,
        onBack = onBack,
        smallTopBar = true,
        // 教务导入页正文是真 WebView：不能把 WebView 录进顶栏毛玻璃的实时 backdrop 层
        // （layerBackdrop 每帧重录自绘控件 ⇒ 网页持续闪烁）。关掉实时模糊，顶栏用不透明页底色。
        enableTopBarBlur = false,
        actions = {
            // 宏录制开关（对齐 Dart 顶栏 FHeaderAction：只有图标 + 无障碍文案，
            // 执行导入期间禁用 `_isExecutingImport ? null : _toggleMacroRecording`）。
            // 录制中换 error 色提示状态；P1 起接真实现，不再是「不可用」实话。
            //
            // 图标取 `AppRecording`（应用窗口 + 声波），语义是「录制这个窗口里的操作」。
            // 换掉的是原来的 `RecordingTape`：那是一盘磁带（两个卷轴 + 外壳），
            // 缩到 24dp 只剩一个圆角方块里两个圆点，读起来像「小机器人脸」，不像录制。
            val isRecording = sessionState.macroState == WarehouseMacroActionState.RECORDING
            IconButton(
                onClick = onToggleMacroRecording,
                enabled = sessionState.stage != WarehouseWebLoginStage.EXECUTING,
            ) {
                Icon(
                    imageVector = MiuixIcons.AppRecording,
                    contentDescription = if (isRecording) {
                        WarehouseStrings.stopRecordingTooltip.text
                    } else {
                        WarehouseStrings.startRecordingTooltip.text
                    },
                    tint = if (isRecording) {
                        MiuixTheme.colorScheme.error
                    } else {
                        MiuixTheme.colorScheme.primary
                    },
                )
            }
            // 桌面/移动切换（Dart `_toggleWebPageMode`）。换 UA 之外还会重载当前页
            // （`toggleDesktopMode` 内部做），因为教务站按 UA 决定回哪个登录页。
            //
            // 图标按 Dart 语义：**按钮描述的是「点了会切到哪边」**。
            // - 切电脑版 → `ScreenMirroring`（显示器 + 投射三角）：miuix-icons 0.9.4 里
            //   唯一带"屏幕/显示器"形状的图标，不再拿 `GridView`（四个小方块＝宫格）充当电脑；
            // - 切手机版 → `Phone`（话筒）：图标集里没有任何手机/竖屏设备形状，
            //   话筒是「手机」在中文语境下最不容易误读的近邻。
            IconButton(onClick = {
                webViewController.toggleDesktopMode()
                onToggleDesktopMode()
            }) {
                Icon(
                    imageVector = if (webViewController.isDesktopMode) MiuixIcons.Phone else MiuixIcons.ScreenMirroring,
                    contentDescription = if (webViewController.isDesktopMode) {
                        WarehouseStrings.switchToMobileWebTooltip.text
                    } else {
                        WarehouseStrings.switchToDesktopWebTooltip.text
                    },
                )
            }
            IconButton(onClick = {
                // 真视图刷新（原来只调外部回调，页面根本没在动）
                webViewController.reload()
                onReload()
            }) {
                Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.text)
            }
            IconButton(onClick = onMoreOptions) {
                Icon(imageVector = MiuixIcons.More, contentDescription = WarehouseStrings.moreActionsTooltip.text)
            }
        },
        bottomBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MiuixTheme.colorScheme.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                // 底部操作主按钮（Dart 底栏只有「执行导入脚本」一个按钮；宏录制开关在顶栏）
                //
                // 只有 LOADED 才允许执行：页面没加载完就点，脚本注入进去没有 `document`
                // 可操作，宿主只会挡掉。之前按钮恒可点、点了回一句泛泛的「脚本执行失败」，
                // 用户读作「点导入没反应」（审核 G1）。禁用态旁边给一句实话，别让按钮
                // 灰着却不说为什么。
                val scriptReady = sessionState.stage == WarehouseWebLoginStage.LOADED
                if (!scriptReady && sessionState.stage != WarehouseWebLoginStage.ERROR) {
                    Text(
                        text = WarehouseStrings.macroReplayWaitPageLoad.text,
                        style = MiuixTheme.textStyles.footnote2,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    )
                }
                // 主操作走导入域统一的整宽主按钮（`ImportActionButton`，主色实心 = 官方
                // `buttonColorsPrimary()`）：之前这里裸用官方 `Button(` 的**默认（次要）配色**，
                // 浅色下底衬色与底栏一样是白的 ⇒ 整颗按钮读成「一行悬空白字」，看着像没有按钮
                // （用户实报「下面的导入按钮这么奇怪」）。同域 ICS / 表格导入页底栏都是主色实心，
                // 这里改成同一套，形态、配色、按压反馈、loading 位就全部对上了。
                ImportActionButton(
                    label = WarehouseStrings.executeImportScriptAction.text,
                    onClick = onExecuteImport,
                    enabled = scriptReady,
                )
            }
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // 会话状态横幅
            if (sessionState.sessionActive) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MiuixTheme.colorScheme.primary.copy(alpha = 0.12f))
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = WarehouseStrings.warehouseSessionAlreadyActive.text,
                        style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                        color = MiuixTheme.colorScheme.primary
                    )
                }
            }

            // 真 WebView 宿主（task-21 接线）：原来是「灰底 + 引导文案」的占位块，
            // 教务登录页在 Compose 侧根本没有浏览器。这一段是本次接线的核心。
            WarehouseWebViewHost(
                initialUrl = sessionState.currentUrl,
                controller = webViewController,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                desktopMode = webViewController.isDesktopMode,
                onProgress = onWebProgress,
                onPageStarted = onWebPageStarted,
                onPageFinished = onWebPageFinished,
                onError = onWebError,
                onBridgeMessage = { raw ->
                    // ---- §6.2 消息门禁（**不许省**，Dart 修过的钓鱼洞）----
                    // 宿主对任意页面开放 QingyuBridge：UI 类消息（toast/confirm/prompt/
                    // singleSelection/error）的唯一合法生产者是导入执行期的适配脚本；
                    // macro:event 只认录制态、loginAttempt 认 执行期/录制态/受信 host
                    //（2026-11-02 安全审计对齐）。不判就会让任意网页在原生层弹任意
                    // 标题/内容的对话框，或把伪造的登录尝试送进后续消费者。
                    // 判定放在 WarehouseWebLoginWebState 里（纯逻辑、有 JVM 测试），
                    // 且页面源码级守卫钉着「这里必须调它」。
                    if (WarehouseWebLoginWebState.shouldDeliverBridgeMessage(
                            raw,
                            sessionState.stage,
                            currentUrl = sessionState.currentUrl,
                            trustedLoginUrls = trustedLoginUrls,
                            macroRecordingActive =
                            sessionState.macroState == WarehouseMacroActionState.RECORDING,
                            foregroundReplayActive = foregroundReplayActive,
                        )
                    ) {
                        onWebBridgeMessage?.invoke(raw)
                    }
                },
            )
        }
    }

    // 「记住密码」确认弹窗（发布版是 showAppConfirmDialog）。旧实现是底栏卡片：
    // 两个小按钮挤在一行、还和主按钮抢底部高度，用户实报「有点怪」。
    WarehouseRememberPasswordDialog(
        show = sessionState.shouldPromptSave,
        username = sessionState.candidateAccount.username,
        onDismiss = onDismissSaveLogin,
        onConfirm = onSaveRememberedLogin,
    )

    // 「自动填充登录信息」确认弹窗（发布版同为 showAppConfirmDialog）。
    // 旧实现是底栏「已记住账号：X」卡片，两个小按钮挤一行，与主按钮抢高度。
    WarehouseAutofillLoginDialog(
        // 回放中不弹模态框（发布版 `macroRecord != null` 时直接填充、不问）。
        // 模态比原卡片更挡人：它会把正在无人值守跑的回放盖住。
        show = sessionState.shouldPromptAutofill && !foregroundReplayActive,
        username = sessionState.rememberedAccount?.username.orEmpty(),
        onDismiss = onDismissAutofill,
        onConfirm = onAutofillLogin,
    )
    // 回放旁路：与发布版同口径，静默填充而不是等用户点。
    LaunchedEffect(sessionState.shouldPromptAutofill, foregroundReplayActive) {
        if (foregroundReplayActive && sessionState.shouldPromptAutofill) {
            onAutofillLogin()
        }
    }
}
