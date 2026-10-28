package com.mutx163.qingyu.pages.live

/**
 * 「后台保活」子屏 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [LiveKeepAliveStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。命名与 ARB 键逐字一致，便于 grep 双向核对。
 *
 * 复用 [LiveStrings] 文件里已有的顶层 `data class ArbText`（同包 public），
 * 因此**不需要**改动 `LiveStrings.kt`。
 */
object LiveKeepAliveStrings {

    // ── 页面标题与开关行 ──
    val liveKeepAliveTitle = ArbText("liveKeepAliveTitle", "后台保活")
    val hideFromRecentsTitle = ArbText("hideFromRecentsTitle", "从最近任务中隐藏应用")

    // ── 无障碍保活服务行 ──
    val keepAliveServiceTitle = ArbText("keepAliveServiceTitle", "轻屿课表后台保活服务")
    val goEnableAction = ArbText("goEnableAction", "去开启")

    // ── 开启前确认弹窗 ──
    val keepAliveConfirmTitle = ArbText("keepAliveConfirmTitle", "开启后台保活服务")
    val keepAliveConfirmBody = ArbText(
        "keepAliveConfirmBody",
        "用于后台更新桌面小组件和课程提醒，不会读取屏幕内容或代为点击。需要系统无障碍权限，可随时关闭。",
    )
    val keepAliveConfirmGoAction = ArbText("keepAliveConfirmGoAction", "去开启")
    val cancelAction = ArbText("cancelAction", "取消")

    // ── 保存失败提示 ──
    val saveFailed = ArbText("saveFailed", "保存失败")

    // ── 状态词（勿扰权限行与未知态） ──
    val guideStatusEnabled = ArbText("guideStatusEnabled", "已开启")
    val guideStatusDisabled = ArbText("guideStatusDisabled", "未开启")
    val guideStatusSuggestedCheck = ArbText("guideStatusSuggestedCheck", "建议检查")
    val guideStatusDoNotDisturbAccess = ArbText("guideStatusDoNotDisturbAccess", "勿扰模式访问权限")
    val guideStatusDoNotDisturbAccessHint = ArbText(
        "guideStatusDoNotDisturbAccessHint",
        "未授权时课前静音点了没反应",
    )

    /** 所有对接 ARB 的文案集合（用于 Parity 测试机械对拍）。 */
    val allTexts: List<ArbText> = listOf(
        liveKeepAliveTitle,
        hideFromRecentsTitle,
        keepAliveServiceTitle,
        goEnableAction,
        keepAliveConfirmTitle,
        keepAliveConfirmBody,
        keepAliveConfirmGoAction,
        cancelAction,
        saveFailed,
        guideStatusEnabled,
        guideStatusDisabled,
        guideStatusSuggestedCheck,
        guideStatusDoNotDisturbAccess,
        guideStatusDoNotDisturbAccessHint,
    )

    /** 权限三态 -> 屏上状态词（未知态用「建议检查」，不猜）。 */
    fun statusLabel(status: LivePermissionStatus): String = when (status) {
        LivePermissionStatus.UNKNOWN -> guideStatusSuggestedCheck.zh
        LivePermissionStatus.GRANTED -> guideStatusEnabled.zh
        LivePermissionStatus.DENIED -> guideStatusDisabled.zh
    }
}
