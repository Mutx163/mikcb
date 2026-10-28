package com.mutx163.qingyu.pages.import.warehouse

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.webkit.ConsoleMessage
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

/**
 * 教务网页登录的**真 WebView 宿主**（能力缺口 B3，P3-G2 域）。
 *
 * 背景：`WarehouseWebLoginPage.kt` 的「WebView 视口占位与引导」原本只是一块灰 Box + 文案，
 * 全仓 `AndroidView` 出现 0 次——教务网页登录在 Compose 侧根本没有浏览器。本文件补上宿主。
 *
 * 硬约束（本泳道不许违反）：
 * - **只用 Android 平台自带的 `android.webkit.WebView`**，零新依赖（`build.gradle` 属 Lead 专属）；
 * - 纯逻辑（UA 选择 / 错误码分类 / Cookie 拼装 / 导航白名单 / JS 结果解码 / 视口脚本）
 *   全部在同包模型层 `main/.../WarehouseWebViewLogic.kt`，本文件只做「接到平台上」这一层。
 *
 * 参照物（只读）：`lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart`。
 * 接线方式见同目录 `WIRING-NOTE.md`（**由 Lead 执行**，本泳道不改 `WarehouseWebLoginPage.kt`）。
 *
 * ⚠️ 只有真机能验的部分（本泳道**未验**）：Cookie 在真实教务站上的同步时机、
 * `QingyuBridge` JS 通道的实际收发、键盘弹出时网页是否被 IME insets 挤压、
 * 明文 HTTP 站点是否被 NSC 拦成 `ERR_CLEARTEXT_NOT_PERMITTED`。
 */

/** 平台 JS 通道名，**逐字对齐 Dart**（`addJavaScriptChannel('QingyuBridge', …)`）。 */
const val WAREHOUSE_WEBVIEW_BRIDGE_NAME: String = "QingyuBridge"

/**
 * WebView 的操作句柄。渲染层从它发指令、页面层从它读状态。
 *
 * 状态字段是 Compose `State`，所以页面里读 `controller.currentUrl` / `loadingProgress`
 * 会随网页变化自动重组。
 *
 * 线程约定：所有方法都按**主线程调用**设计（`WebView` 本身只能在主线程碰）。
 * 唯一例外是 [cookiesForUrl] / [cookieHeaderForUrl]（只读 `CookieManager`，任意线程可用）。
 */
@Stable
class WarehouseWebViewController {

    /** 底层视图；未挂载（还没进组合）时为 null。 */
    internal var webView: WebView? = null
        private set

    /** 还没挂载时先记下来的目标地址，挂载后补发（避免「先点按钮、后进页面」丢导航）。 */
    private var pendingUrl: String? = null

    /** 当前是否为桌面版 UA。 */
    var isDesktopMode: Boolean by mutableStateOf(true)
        private set

    /** 最近一次「开始加载 / 加载完成」的地址。 */
    var currentUrl: String? by mutableStateOf(null)
        private set

    /** 加载进度 0..100（`WebChromeClient.onProgressChanged`）。 */
    var loadingProgress: Int by mutableIntStateOf(0)
        private set

    /** 最近一次**主框架**加载失败。 */
    var lastError: WarehouseWebViewError? by mutableStateOf(null)
        private set

    // --- 导航 ---

    /** 加载地址；视图未挂载时先记住，挂载后补发。 */
    fun loadUrl(url: String) {
        val target = url.trim()
        if (target.isEmpty()) return
        val view = webView
        if (view == null) {
            pendingUrl = target
            currentUrl = target
            return
        }
        currentUrl = target
        view.loadUrl(target)
    }

    /** 重新加载当前页（顶栏「刷新」按钮）。 */
    fun reload() {
        webView?.reload()
    }

    /** 停止加载。 */
    fun stopLoading() {
        webView?.stopLoading()
    }

    /** 从 WebView 现取地址（可能比 [currentUrl] 更新，含 `#` 片段跳转）。 */
    fun liveUrl(): String? = webView?.url ?: currentUrl

    fun canGoBack(): Boolean = webView?.canGoBack() == true

    fun canGoForward(): Boolean = webView?.canGoForward() == true

    fun goBack(): Boolean {
        val view = webView ?: return false
        if (!view.canGoBack()) return false
        view.goBack()
        return true
    }

    fun goForward(): Boolean {
        val view = webView ?: return false
        if (!view.canGoForward()) return false
        view.goForward()
        return true
    }

    // --- 桌面 / 移动 ---

    /**
     * 切换桌面/移动版。**换 UA 之外还要重新加载**：教务站按 UA 决定回哪个登录页，
     * 不重载的话页面还是上一次渲染出来的那份，用户会以为按钮没生效（对齐 Dart
     * `_toggleWebPageMode`：`setUserAgent` 之后 `loadRequest(currentUrl)`）。
     */
    fun toggleDesktopMode(reload: Boolean = true) {
        setDesktopMode(!isDesktopMode, reload = reload)
    }

    /**
     * 设置桌面/移动版。
     *
     * @param reload 是否按 Dart 的口径重新加载当前地址；`false` 只换 UA（组合期同步用）。
     */
    fun setDesktopMode(desktop: Boolean, reload: Boolean = true) {
        val changed = isDesktopMode != desktop
        isDesktopMode = desktop
        val view = webView ?: return
        applyUserAgent(view, desktop)
        if (reload && changed) {
            val target = view.url ?: currentUrl
            loadingProgress = 0
            if (target.isNullOrEmpty()) view.reload() else view.loadUrl(target)
        }
    }

    /**
     * 组合期同步：只保证「视图上的 UA / 宽视口设置」与 [desktop] 一致，**不触发重载**。
     * 供宿主 `update` 调用，避免每次重组都重载页面。
     */
    internal fun syncDesktopMode(desktop: Boolean) {
        isDesktopMode = desktop
        webView?.let { applyUserAgent(it, desktop) }
    }

    /** 与 Dart 的 `setUseWideViewPort(true)` 对齐：恢复标准 viewport 语义，见 [warehouseViewportOverrideScript]。 */
    internal fun applyUserAgent(view: WebView, desktop: Boolean) {
        val ua = WarehouseWebViewUserAgents.forDesktopMode(desktop)
        if (view.settings.userAgentString != ua) {
            view.settings.userAgentString = ua
        }
    }

    // --- Cookie ---

    /**
     * 取某地址能看到的 Cookie。`CookieManager.getCookie` 是同步的，不需要 WebView 实例，
     * 任意线程可调（宿主约定主线程）。
     */
    fun cookiesForUrl(url: String): List<WarehouseCookie> =
        parseWarehouseCookieHeader(CookieManager.getInstance().getCookie(url))

    /** 取某地址的 Cookie 请求头值（`a=1; b=2`），没有则空串。 */
    fun cookieHeaderForUrl(url: String): String = buildWarehouseCookieHeader(cookiesForUrl(url))

    /** 当前页面的 Cookie 请求头值。 */
    fun currentCookieHeader(): String {
        val url = liveUrl() ?: return ""
        return cookieHeaderForUrl(url)
    }

    // --- JS ---

    /** 注入脚本，不关心返回值。 */
    fun injectJavaScript(script: String) {
        if (script.isEmpty()) return
        webView?.evaluateJavascript(script, null)
    }

    /**
     * 注入脚本并取返回值。平台回调给的是 **JSON 文本**，这里已用
     * [decodeWarehouseJsResult] 解码：JS 字符串去掉引号与转义，`null`/`undefined` 归一成 null。
     */
    fun evaluateJavaScript(script: String, onResult: (String?) -> Unit) {
        val view = webView
        if (view == null) {
            onResult(null)
            return
        }
        view.evaluateJavascript(script) { raw -> onResult(decodeWarehouseJsResult(raw)) }
    }

    // --- 生命周期（由宿主调用）---

    internal fun bind(view: WebView) {
        webView = view
        view.settings.userAgentString = WarehouseWebViewUserAgents.forDesktopMode(isDesktopMode)
    }

    /**
     * 取走「挂载前请求过的地址」。挂载时若存在，它比构造参数里的 `initialUrl` 更新，
     * 宿主应优先加载它（见 [WarehouseWebViewHost] 的 factory）。
     */
    internal fun consumePendingUrl(): String? {
        val url = pendingUrl
        pendingUrl = null
        return url
    }

    internal fun onPageStarted(url: String?) {
        if (!url.isNullOrEmpty()) currentUrl = url
        loadingProgress = 0
        lastError = null
    }

    internal fun onPageFinished(url: String?) {
        if (!url.isNullOrEmpty()) currentUrl = url
        loadingProgress = 100
    }

    internal fun onProgress(progress: Int) {
        loadingProgress = progress.coerceIn(0, 100)
    }

    internal fun onError(error: WarehouseWebViewError) {
        lastError = error
    }

    /**
     * 宿主离开组合时销毁底层视图。
     *
     * ⚠️ 销毁 = 这一页的 JS 执行上下文没了（Cookie 由 `CookieManager` 留在进程级）。
     * 后台导入（Dart 的 `runInBackground`）要求 WebView 在导入期间一直活着，
     * 所以那条路径**不能让宿主离开组合**（放在尺寸 >0 的离屏容器里，而不是条件插拔）。
     */
    internal fun release(view: WebView) {
        if (webView === view) webView = null
        view.stopLoading()
        view.destroy()
    }

    /** 主动销毁（页面级收尾，等价于宿主离开组合）。 */
    fun destroy() {
        val view = webView ?: return
        release(view)
    }
}

/** 记住一个跨重组存活的控制器。 */
@Composable
fun rememberWarehouseWebViewController(): WarehouseWebViewController =
    remember { WarehouseWebViewController() }

/**
 * 平台 JS 通道的接收端。JS 里的调用形如 `QingyuBridge.postMessage(JSON.stringify({...}))`。
 *
 * ⚠️ `@JavascriptInterface` 方法运行在 WebView 的 JavaBridge 线程上，**不是主线程**；
 * 宿主里已经 `post` 回主线程再交给调用方，所以 `onBridgeMessage` 的回调里可以安全碰 UI。
 */
private class WarehouseBridgeProxy {
    var onMessage: ((String) -> Unit)? = null

    @JavascriptInterface
    fun postMessage(message: String) {
        onMessage?.invoke(message)
    }
}

/**
 * Compose 侧的 WebView 宿主。
 *
 * 用法（接线细节见 `WIRING-NOTE.md`）：
 * ```
 * val controller = rememberWarehouseWebViewController()
 * WarehouseWebViewHost(
 *     initialUrl = state.currentUrl,
 *     controller = controller,
 *     modifier = Modifier.fillMaxSize(),
 *     onProgress = { ... },
 *     onError = { err -> ... },
 *     onBridgeMessage = { raw -> ... },   // 记得按 Dart 门禁过滤 UI 类消息
 * )
 * ```
 *
 * @param initialUrl 首次加载地址（对齐 Dart 的 `initialUrl`）。
 * @param controller 操作句柄；默认用 [rememberWarehouseWebViewController]。
 * @param desktopMode 桌面/移动版；默认跟随 [WarehouseWebViewController.isDesktopMode]，
 *   切换请调 `controller.toggleDesktopMode()`（它会重载页面）。
 * @param autoInjectViewportOverride 加载完成后是否自动注入视口改写脚本（对齐 Dart
 *   `_applyViewportOverrideJs`）。桌面/移动的布局差异靠它才真的出现。
 * @param onProgress 加载进度 0..100。
 * @param onPageStarted / onPageFinished 主框架导航起止（地址已做非空归一）。
 * @param onError 主框架加载失败（子资源失败不会回调到这里）。
 * @param onNavigationBlocked 被导航 scheme 白名单拦下的地址（见 [warehouseAllowsMainFrameNavigation]）。
 * @param onConsoleMessage 网页 console，`level` 为小写（`error` / `warn` / `log` / `debug`）。
 * @param onBridgeMessage `QingyuBridge` 收到的原始消息文本；为 null 时消息被直接丢弃
 *   （通道本身仍按 Dart 一样常驻注册）。**接线时务必用
 *   [shouldProcessWarehouseBridgeMessage] 过滤 UI 类消息**，否则任意网页都能在原生层弹窗。
 */
@Composable
fun WarehouseWebViewHost(
    initialUrl: String,
    controller: WarehouseWebViewController = rememberWarehouseWebViewController(),
    modifier: Modifier = Modifier,
    desktopMode: Boolean = controller.isDesktopMode,
    autoInjectViewportOverride: Boolean = true,
    onProgress: (Int) -> Unit = {},
    onPageStarted: (String) -> Unit = {},
    onPageFinished: (String) -> Unit = {},
    onError: (WarehouseWebViewError) -> Unit = {},
    onNavigationBlocked: (String) -> Unit = {},
    onConsoleMessage: (String, String) -> Unit = { _, _ -> },
    onBridgeMessage: ((String) -> Unit)? = null,
) {
    // 回调用 rememberUpdatedState 兜住：WebViewClient 只在 factory 里建一次，
    // 直接捕获形参会永远调用第一次组合时的那份 lambda（重组后就是旧的）。
    val currentOnProgress by rememberUpdatedState(onProgress)
    val currentOnPageStarted by rememberUpdatedState(onPageStarted)
    val currentOnPageFinished by rememberUpdatedState(onPageFinished)
    val currentOnError by rememberUpdatedState(onError)
    val currentOnNavigationBlocked by rememberUpdatedState(onNavigationBlocked)
    val currentOnConsoleMessage by rememberUpdatedState(onConsoleMessage)
    val currentOnBridgeMessage by rememberUpdatedState(onBridgeMessage)
    val currentAutoInject by rememberUpdatedState(autoInjectViewportOverride)
    val currentDesktopMode by rememberUpdatedState(desktopMode)

    AndroidView(
        factory = { context ->
            createWarehouseWebView(
                context = context,
                controller = controller,
                initialUrl = initialUrl,
                desktopMode = currentDesktopMode,
                onProgress = { currentOnProgress(it) },
                onPageStarted = { currentOnPageStarted(it) },
                onPageFinished = {
                    if (currentAutoInject) {
                        controller.injectJavaScript(
                            warehouseViewportOverrideScript(controller.isDesktopMode),
                        )
                    }
                    currentOnPageFinished(it)
                },
                onError = { currentOnError(it) },
                onNavigationBlocked = { currentOnNavigationBlocked(it) },
                onConsoleMessage = { level, message -> currentOnConsoleMessage(level, message) },
                onBridgeMessage = { raw -> currentOnBridgeMessage?.invoke(raw) },
            )
        },
        modifier = modifier,
        update = { view -> controller.syncDesktopMode(desktopMode) },
        onRelease = { view -> controller.release(view) },
    )
}

/**
 * 建视图并把平台回调接到 [controller] 上。
 *
 * 这里**只用平台 API**：`WebSettings` / `WebViewClient` / `WebChromeClient` / `CookieManager`。
 * 与 Dart 侧的对应关系逐条写在各自回调旁。
 */
@SuppressLint("SetJavaScriptEnabled")
private fun createWarehouseWebView(
    context: Context,
    controller: WarehouseWebViewController,
    initialUrl: String,
    desktopMode: Boolean,
    onProgress: (Int) -> Unit,
    onPageStarted: (String) -> Unit,
    onPageFinished: (String) -> Unit,
    onError: (WarehouseWebViewError) -> Unit,
    onNavigationBlocked: (String) -> Unit,
    onConsoleMessage: (String, String) -> Unit,
    onBridgeMessage: (String) -> Unit,
): WebView {
    val webView = WebView(context)

    // --- WebSettings：对齐 Dart initState 里的 controller 配置 ---
    webView.settings.apply {
        // Dart: setJavaScriptMode(JavaScriptMode.unrestricted)
        javaScriptEnabled = true
        // 教务站登录态大多存 localStorage / sessionStorage
        domStorageEnabled = true
        // Dart: enableZoom(true)
        setSupportZoom(true)
        builtInZoomControls = true
        displayZoomControls = false
        // Dart: setUseWideViewPort(true)——桌面/移动的布局视口差异靠它 + 视口脚本才出现
        useWideViewPort = true
        userAgentString = WarehouseWebViewUserAgents.forDesktopMode(desktopMode)
    }
    controller.bind(webView)
    controller.syncDesktopMode(desktopMode)

    // 明文 http 的教务站要能存 Cookie（NSC 白名单由仓库的网络安全配置负责，不在这里放开）
    CookieManager.getInstance().setAcceptCookie(true)

    // Dart: addJavaScriptChannel('QingyuBridge', …)
    val bridgeProxy = WarehouseBridgeProxy()
    bridgeProxy.onMessage = { message ->
        // @JavascriptInterface 回调在 JavaBridge 线程上，post 回主线程再交给页面层
        webView.post { onBridgeMessage(message) }
    }
    webView.addJavascriptInterface(bridgeProxy, WAREHOUSE_WEBVIEW_BRIDGE_NAME)

    webView.webViewClient = object : WebViewClient() {
        /**
         * Dart: NavigationDelegate.onNavigationRequest + `warehouseAllowsMainFrameNavigation`。
         * 返回 true = 由宿主吞掉这次导航（不回给 WebView），即拒绝。
         * 子框架导航不会走到这里。
         */
        override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
            val url = request?.url?.toString() ?: return false
            if (warehouseAllowsMainFrameNavigation(url)) return false
            onNavigationBlocked(url)
            return true
        }

        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
            controller.onPageStarted(url)
            url?.let(onPageStarted)
        }

        override fun onPageFinished(view: WebView?, url: String?) {
            controller.onPageFinished(url)
            url?.let(onPageFinished)
        }

        /**
         * Dart: NavigationDelegate.onWebResourceError。
         * 只报主框架失败：一次页面加载会为每个挂掉的图片/脚本回调，全报会刷屏。
         */
        override fun onReceivedError(
            view: WebView?,
            request: WebResourceRequest?,
            error: WebResourceError?,
        ) {
            val isMainFrame = request?.isForMainFrame ?: true
            if (!isMainFrame) return
            val description = error?.description?.toString().orEmpty()
            val errorCode = error?.errorCode ?: WarehouseWebViewErrorCodes.UNKNOWN
            val url = request?.url?.toString() ?: view?.url ?: controller.currentUrl
            val snapshot = WarehouseWebViewError(
                errorCode = errorCode,
                description = description,
                url = url,
            )
            controller.onError(snapshot)
            onError(snapshot)
        }
    }

    webView.webChromeClient = object : WebChromeClient() {
        override fun onProgressChanged(view: WebView?, newProgress: Int) {
            controller.onProgress(newProgress)
            onProgress(newProgress)
        }

        /** Dart: setOnConsoleMessage——网页 console 进导入执行日志，排障全靠它。 */
        override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
            val message = consoleMessage ?: return false
            onConsoleMessage(
                message.messageLevel().name.lowercase(),
                message.message().orEmpty(),
            )
            return false
        }
    }

    controller.loadUrl(controller.consumePendingUrl() ?: initialUrl)
    return webView
}
