package com.mutx163.qingyu.pages.import.warehouse

/**
 * 登录页**到底该加载哪个地址**（F28 / I2 学校数据源收尾）。
 *
 * ## 为什么要单独一个纯函数
 *
 * 登录地址有两个来源，优先级与 Dart 一致：
 * 1. 用户在适配器详情页手填的自定义地址（[WarehouseImportPrefs.customImportUrl]，键名与 Dart 同）；
 * 2. 适配仓 `resources/<学校>/adapters.yaml` 里的 `import_url`（[WarehouseAdapterEntry.importUrl]）。
 *
 * 这条链路以前在壳里是断的：`g2.webLogin` 直接显示「未找到有效的教务登录地址」，
 * 学校/适配器里的真地址根本没机会上来。把判定抽成纯函数后，L0 单测能钉住
 * 「选了学校 → 适配器的 import_url 真的被选中」「自定义覆盖优先」这两件事，
 * 而不是靠真机肉眼确认。
 *
 * ## 诚实边界
 *
 * - 只认 `http` / `https`（复用 [resolveWarehouseImportUrl] 的同一口径）；
 * - `import_url` 为空、且没有合法自定义地址时回 `null`——调用方必须显示诚实空态，
 *   **不许**拿 `example.com` 一类占位地址凑合（F23 已经删过一次这种假地址）。
 */
data class WarehouseWebLoginTarget(
    /** 真正要加载的地址（已 trim）。 */
    val loginUrl: String,
    /** `true` = 用的是用户手填的覆盖地址，不是仓库声明的地址。 */
    val customOverride: Boolean,
)

/**
 * 解析这一趟要加载的登录地址；没有可用地址时回 `null`。
 *
 * @param adapter 当前选中的适配器（`WarehouseShellState.adapter`）
 * @param customImportUrl 用户在该适配器上保存的自定义地址（可空）
 */
fun resolveWarehouseWebLoginTarget(
    adapter: WarehouseAdapterEntry?,
    customImportUrl: String?,
): WarehouseWebLoginTarget? {
    if (adapter == null) return null
    val resolved = resolveWarehouseImportUrl(customImportUrl, adapter.importUrl) ?: return null
    val custom = customImportUrl?.trim().orEmpty()
    // `resolveWarehouseImportUrl` 只有在自定义地址合法时才会返回它；这里用「返回值 == 自定义值」
    // 反推来源，避免把同一套合法性判据再抄一遍（两处判据漂移是最难查的那种不一致）。
    return WarehouseWebLoginTarget(
        loginUrl = resolved,
        customOverride = custom.isNotEmpty() && resolved == custom,
    )
}

/**
 * 新建会话状态：把解析出的地址填进 [WarehouseWebLoginSessionState.currentUrl]。
 *
 * 阶段从 [WarehouseWebLoginStage.IDLE] 起步——WebView 加载后由宿主回调推进到
 * LOADING / LOADED / ERROR，调用方不要自己假装已经加载完成。
 */
fun initialWarehouseWebLoginSession(target: WarehouseWebLoginTarget): WarehouseWebLoginSessionState =
    WarehouseWebLoginSessionState(
        currentUrl = target.loginUrl,
        stage = WarehouseWebLoginStage.IDLE,
    )
