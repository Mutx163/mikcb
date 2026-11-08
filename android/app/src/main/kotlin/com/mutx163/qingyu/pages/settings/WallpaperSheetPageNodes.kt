package com.mutx163.qingyu.pages.settings

/*
 * 壁纸面板两页的节点树（纯函数，无 Compose 依赖）。
 *
 * 与渲染层（`composeP1/.../WallpaperSheetBody.kt`）分开的原因只有一个：**这里要能在
 * L0 纯 JVM 单测里断言**「哪一行在哪一页」。渲染层文件带 `@Composable`，进不了
 * `scripts/test-kotlin-module.ps1` 的 classpath，逻辑留在那边就只能靠真机或整包 Gradle。
 *
 * ## 「每天自动更换」为什么在这里换页
 *
 * 用户 2026-11-07 口径：外观编辑页里 Bing 壁纸下面那颗设置（「每天自动更换」）挪到右边
 * 「设置」页。图库入口按钮留在第一页——那是导航，不是设置。
 *
 * 模型（[SettingsBackdropFlowPage]）**不改**：它同时服务「课表页面」设置里的壁纸卡，
 * 那边不分页、也不该跟着动。所以拆分只发生在这一层：第一页把 `backdrop.bing` 组里的
 * 开关行摘掉，第二页把它补进 `backdrop.settings` 组。
 */

/** 壁纸面板页序：0 = 壁纸，1 = 设置（`settings_appearance_editor.dart:2115-2117`）。 */
object WallpaperSheetPages {
    const val PICKER = 0
    const val SETTINGS = 1
    const val COUNT = 2
}

/**
 * 「每天自动更换」那颗开关的取值来源认不认得出来。
 *
 * 认不出来时**不许画成能点的开关**：Dart 那颗开关的真源是 `BingWallpaperStore` 台账，
 * 它不走草稿、也不走宿主 `setState`（`settings_home_backdrop_flow.dart:501-526`，
 * 2026-10-06 实报「点了一下没反应」）。[BackdropFlowState.bingAutoApplyEnabled] 的出厂值
 * 是 false，所以默认 [UNKNOWN]：行照渲染、但禁用并把说明换成 ARB 已有的「不可用」
 * （`SettingsStrings.aboutUnavailable`）。
 *
 * 台账一旦接上，宿主给 [wallpaperPageNodes] 传 `autoApplySnapshot` 即可 —— 那一路会把
 * 开关值改成台账里的真实值、恢复可点（等价于显式传 [LEDGER]）。
 */
enum class WallpaperAutoApplySource {
    /** 真源已接（`BingWallpaperStore` 的台账），开关可点。 */
    LEDGER,

    /** 认不出来 / 还没接：只读禁用，并写明「不可用」。 */
    UNKNOWN,
}

/** 「每天自动更换」那一行的 id（模型 `backdrop.bing.autoApply`，与分派 target 同串）。 */
internal const val BING_AUTO_APPLY_ROW_ID = WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE

/** 第一页「每日壁纸」那一组与图库入口行（`SettingsBackdropFlowPage.selectionPage` 的 `backdrop.bing`）。 */
internal const val BING_GROUP_ID = "backdrop.bing"

/** 第二页「设置」那一组（`SettingsBackdropFlowPage.settingsPage` 的 `backdrop.settings`）。 */
internal const val SETTINGS_GROUP_ID = "backdrop.settings"

/**
 * 一页的节点树。
 *
 * 「每天自动更换」在这里**换页**：第一页把 `backdrop.bing` 组里的那一行摘掉（只剩图库入口
 * 按钮），第二页把它补进 `backdrop.settings` 组、排在「壁纸模糊」后面。模型不动——理由见
 * 文件头。
 *
 * ⚠️ 面板宿主的内缩与「课表页面」那个宿主不同：面板的左右内缩取 0
 * （`SettingsBackdropFlowPage.HOST_SHEET_ROW_INSET`，理由见该文件 :79-103——面板的
 * `insideMargin` 已经给了 Dart 那个 16，再垫一层就是 32）。
 *
 * @param index 0 = 壁纸（[WallpaperSheetPages.PICKER]），1 = 设置（[WallpaperSheetPages.SETTINGS]）。
 * @param autoApplySource 没接台账时的旧口径；传了 [autoApplySnapshot] 就忽略它。
 * @param autoApplySnapshot 台账快照：有它 = 真源已接（开关可点、值取台账）。
 */
internal fun wallpaperPageNodes(
    state: AppearanceEditorState,
    selection: SelectionPageState,
    index: Int,
    autoApplySource: WallpaperAutoApplySource = WallpaperAutoApplySource.UNKNOWN,
    autoApplySnapshot: WallpaperAutoApplySnapshot? = null,
): List<SettingsNode> {
    val backdrop = backdropFlowState(state)
    // 台账快照优先：有它就用真实开关值，否则走旧的「认不出来就禁用」口径。
    val source = if (autoApplySnapshot != null) {
        WallpaperAutoApplySource.LEDGER
    } else {
        autoApplySource
    }
    return when (index) {
        WallpaperSheetPages.SETTINGS -> {
            val autoApply = resolveAutoApplyRow(backdrop, source, autoApplySnapshot)
            SettingsBackdropFlowPage.settingsPage(backdrop).nodes.map { node ->
                if (node is SettingsGroup && node.id == SETTINGS_GROUP_ID && autoApply != null) {
                    // 接在「壁纸模糊」后面：不插进已有的两根控件中间，用户已经记住的顺序不动。
                    node.copy(children = node.children + autoApply)
                } else {
                    node
                }
            }
        }
        else -> SettingsBackdropFlowPage.selectionPage(backdrop, selection).nodes.map { node ->
            // 认 id 摘行，不认下标：模型哪天调整组内顺序也不会摘错。
            if (node is SettingsGroup && node.id == BING_GROUP_ID) {
                node.copy(
                    children = node.children.filterNot { it.id == BING_AUTO_APPLY_ROW_ID },
                )
            } else {
                node
            }
        }
    }
}

/**
 * 「每天自动更换」那一行在**本面板**里的最终形态（行本身仍从模型取）。
 *
 * 真源是 [WallpaperAutoApplySnapshot]（宿主从 `BingWallpaperStore` 台账读出，并在台账
 * 通知时传新快照）：有快照 ⇒ 真实开关值且可点。
 *
 * 没快照、且 [WallpaperAutoApplySource] 认不出来时只禁用，并把说明换成 ARB 已有的
 * 「不可用」——不新造一句（`SettingsStrings.kt:57-62` 就是这么定下来的规矩）。
 *
 * 文案、动作、rowId 全部来自 [SettingsBackdropFlowPage.selectionPage]，本函数只改取值口径。
 */
private fun resolveAutoApplyRow(
    backdrop: BackdropFlowState,
    source: WallpaperAutoApplySource,
    snapshot: WallpaperAutoApplySnapshot?,
): SettingsRow? {
    val row = SettingsBackdropFlowPage.selectionPage(backdrop).nodes
        .filterIsInstance<SettingsGroup>()
        .firstOrNull { it.id == BING_GROUP_ID }
        ?.children
        ?.filterIsInstance<SettingsRow>()
        ?.firstOrNull { it.id == BING_AUTO_APPLY_ROW_ID }
        ?: return null
    return when {
        snapshot != null -> row.copy(switchValue = snapshot.enabled, enabled = true)
        source == WallpaperAutoApplySource.UNKNOWN -> row.copy(
            enabled = false,
            subtitleKey = SettingsStrings.aboutUnavailable.key,
            subtitle = SettingsStrings.aboutUnavailable.text,
        )
        else -> row
    }
}

/**
 * 壁纸面板状态 → 壁纸流程输入（同一份真源，只换一次形状）。
 *
 * 纯映射，与渲染无关；放在这里是为了让节点层与渲染层都能用同一份，不各写一遍
 * （两处各写一份是「面板显示的值与设置页显示的值不一样」的常见来源）。
 */
internal fun backdropFlowState(state: AppearanceEditorState): BackdropFlowState =
    BackdropFlowState(
        imagePath = state.wallpaper.path,
        history = state.wallpaper.history.map { it.key },
        followsWeekPager = state.wallpaper.followsWeekPager,
        blurSigma = state.wallpaper.blurSigma,
    )
