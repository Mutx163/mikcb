package com.mutx163.qingyu.pages.import.warehouse

/**
 * 网页登录页把**宿主回调**翻译成**页面状态**的纯逻辑（能力缺口 B3 的接线部分，task-21）。
 *
 * 为什么单独一个文件而不是直接写在 `WarehouseWebLoginPage.kt` 里：
 * 那个文件在 `composeP1` 源集，**不在 L0（`test-kotlin-module.ps1`）的编译范围里**，
 * 写在那里的判定只能靠真机/人工看；而本目录（`main/.../pages/import/warehouse/`）
 * 是 `-Module "pages/import/warehouse"` 的模块目录，判定放这里就能被纯 JVM 测试钉住。
 *
 * 三个判定的出处都在 Dart（只读参照物 `warehouse_adapter_web_login_screen.dart`）：
 * - 进度 → 阶段：Dart `onProgress` 只更新进度条；这里把「满了算加载完成」固化下来；
 * - 错误 → 阶段 + 文案：Dart `onWebResourceError` 只对明文拦截弹提示，其余留日志；
 *   这里统一成「一律 ERROR + 文案优先取 ARB」；
 * - **桥接消息门禁**：Dart `lib/domain/warehouse_bridge_gate.dart` 的
 *   `shouldProcessWarehouseBridgeMessage`，配合本包 [warehouseBridgeMessageType]。
 */
object WarehouseWebLoginWebState {

    /** 进度 → 阶段。100 才算「加载完成」，与 Dart 里 `_loadingProgress = 100` 的落点一致。 */
    fun stageForProgress(progress: Int): WarehouseWebLoginStage =
        if (progress >= 100) WarehouseWebLoginStage.LOADED else WarehouseWebLoginStage.LOADING

    /** 主框架加载失败一律进 ERROR 阶段（文案由 [errorText] 决定）。 */
    fun stageForError(): WarehouseWebLoginStage = WarehouseWebLoginStage.ERROR

    /**
     * 错误 → 给用户看的那句话。
     *
     * 优先用 ARB（宿主只给键名 [WarehouseWebViewError.arbKey]，**不硬写中文**——
     * 那会被仓库的中文字面量棘轮门禁拦下）；ARB 里没有对应键时回退到系统原文
     * （`description`，英文/系统消息），总比空白好。
     *
     * @param arbText 键名 → 本地化文案；取不到返回 null。
     */
    fun errorText(error: WarehouseWebViewError, arbText: (String) -> String?): String {
        val key = error.arbKey
        if (key != null) {
            val localized = arbText(key)
            if (!localized.isNullOrBlank()) return localized
        }
        return error.description
    }

    /**
     * **桥接消息门禁**（WIRING-NOTE §6.2，Dart 修过的钓鱼洞）。
     *
     * 宿主对任意页面开放 `QingyuBridge`，页面随时可以 `postMessage`；UI 类消息
     * （`toast` / `confirm` / `prompt` / `singleSelection` / `error`）的唯一合法生产者
     * 是**导入执行期**正在跑的适配脚本。不判就会让任意网页在原生层弹任意标题/内容的
     * 对话框（伪造「请输入身份证号」一类）。`macro:event` / `loginAttempt` 的放行
     * 条件见 [shouldProcessWarehouseBridgeMessage]（2026-11-02 安全审计对齐）。
     *
     * 把「取类型 + 判阶段」绑在这一个函数里，页面只调它一次：
     * 调用点少一处，绕过门禁的机会就少一处（页面源码级守卫也钉着这条，见测试）。
     *
     * @param currentUrl 当前页地址（WebView 现值），算 [trustedPageOrigin] 用。
     * @param trustedLoginUrls 受信地址集合（适配器登记地址 + 受信自定义地址），
     *   host 化后与 [currentUrl] 的 host 比对；空集合 ⇒ 受信放行永不生效（只会更严）。
     * @param macroRecordingActive 录制态（会话真实状态；录制引擎未移植时恒 false）。
     */
    fun shouldDeliverBridgeMessage(
        raw: String?,
        stage: WarehouseWebLoginStage,
        currentUrl: String? = null,
        trustedLoginUrls: List<String> = emptyList(),
        macroRecordingActive: Boolean = false,
    ): Boolean = shouldProcessWarehouseBridgeMessage(
        type = warehouseBridgeMessageType(raw),
        importExecutionActive = stage == WarehouseWebLoginStage.EXECUTING,
        macroRecordingActive = macroRecordingActive,
        // 前台回放引擎尚未移植（F08-8c）：Kotlin 侧没有对应状态，恒 false（默认值）。
        trustedPageOrigin = warehouseUrlOnTrustedHosts(
            currentUrl,
            warehouseTrustedLoginHosts(*trustedLoginUrls.toTypedArray()),
        ),
    )
}
