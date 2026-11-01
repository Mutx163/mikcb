package com.mutx163.qingyu.pages.settings

/**
 * 壁纸面板所有**能发出去**的 target 串，以及它们各自代表什么动作。
 *
 * ## 为什么要有这一层（审计 F4 / F7 / J2 的根因）
 *
 * `SettingsBackdropFlowPage.selectionPage` 里的行只写「点完要发生什么」的一部分：
 * 「选择图片 / 调整位置 / 每日壁纸」带 target，而「清除图片 / 自动换开关」两行
 * 在模型里 `actionTarget = null`，渲染层只能把 rowId 发出去。壳 / 分派器按 target
 * 认路，认不出就是**点了没反应的死按钮**（2026-10-29 审计原话）。
 *
 * 这里把 target 收成一份**唯一的串表**，并提供 [parse]：
 * 只要一个 target 能被解析成 [WallpaperSheetIntent]，就说明它有明确接收方；
 * 解析不出来的一律当「不认识」——壳可以选择不响应，但这件事必须可被单测钉住，
 * 而不是散落在各个渲染分支里。
 *
 * ## 两类 target
 *
 * | 类别 | 谁发 | 谁接 |
 * |---|---|---|
 * | 行导航（[ROW_PICK] / [ROW_MISSING] / [ROW_ADJUST] / [OPEN_GALLERY]） | 模型行 | 面板自己（相册）或壳路由（取景页 / 图库页） |
 * | 数据写入（`picked:` / `select:` / `confirmDelete:` / `undoRemove:` / [ROW_CLEAR] / [AUTO_APPLY_TOGGLE]） | 面板 | 分派器 → [WallpaperHistoryLedger] / 图库台账 |
 *
 * 与 composeP1 的 `WallpaperSheetTargets` 是同一批串：那边用
 * `const val ROW_PICK = WallpaperSheetActionTargets.ROW_PICK` 引用本对象，
 * 不再各写一份字面量（两边漂移是这类「死按钮」最常见的来源）。
 */
object WallpaperSheetActionTargets {

    /** 「选择图片」行（模型 `backdrop.image.pick`，Dart `:903-909`）。 */
    const val ROW_PICK = "backdrop.image.pick"

    /** 「图片文件已丢失」警示行：点它同样回到选图（模型 `backdrop.image.missing`，Dart `:892-895`）。 */
    const val ROW_MISSING = "backdrop.image.missing"

    /** 「调整位置」行（模型 `backdrop.image.adjust`，Dart `:919-925`）。 */
    const val ROW_ADJUST = "backdrop.image.adjust"

    /** 「清除图片」行（模型 `backdrop.image.clear`，Dart `:927-933`）。 */
    const val ROW_CLEAR = "backdrop.image.clear"

    /** 「最近使用」整段的 rowId（条上的点击 / 移除都挂它）。 */
    const val ROW_RECENT = "backdrop.recent"

    /** 「移除确认条」的取消那颗（`settings_recent_wallpaper.dart:169-203`）。 */
    const val ROW_CANCEL_DELETE = "backdrop.recent.cancelDelete"

    /**
     * 「每天自动更换」开关（模型行 id `backdrop.bing.autoApply`）。
     *
     * ⚠️ 开关渲染层拿到的是 `onCheckedChange` 的**无参回调**（`SettingsPageRenderers.kt:367-371`
     * 直接丢掉新值），所以数据侧不能从 target 里读「开还是关」，必须按台账现值**取反**。
     * 这与 Dart 的 `onChanged: _setBingAutoApply` 同一语义（`:537-555`）。
     */
    const val AUTO_APPLY_TOGGLE = "backdrop.bing.autoApply"

    /** 每日壁纸图库入口（`SettingsBackdropFlowPage.BING_GALLERY_TARGET`，Dart `:482-499`）。 */
    const val OPEN_GALLERY = SettingsBackdropFlowPage.BING_GALLERY_TARGET

    /** 选完图带回的那张（`content://` URI，数据侧负责收进受管目录）。 */
    const val PICKED_PREFIX = "backdrop.image.picked:"

    /** 切回「最近使用」里的某一条。 */
    const val SELECT_PREFIX = "backdrop.recent.select:"

    /** 确认删除某一条（与模型 `backdrop.recent.confirmDelete:<key>` 逐字一致）。 */
    const val CONFIRM_DELETE_PREFIX = "backdrop.recent.confirmDelete:"

    /** 撤销最近一次删除。 */
    const val UNDO_REMOVE_PREFIX = "backdrop.recent.undoRemove:"

    fun picked(uri: String): String = PICKED_PREFIX + uri

    fun select(key: String): String = SELECT_PREFIX + key

    fun confirmDelete(key: String): String = CONFIRM_DELETE_PREFIX + key

    fun undoRemove(key: String): String = UNDO_REMOVE_PREFIX + key

    /**
     * 行 → 真正发出去的 target。
     *
     * 模型给了 target 就用模型的（`pick` / `missing` / `adjust` / 图库 / 确认删除）；
     * 没给的只有两行，按 rowId 补一个**稳定**的串：清除图片与自动换开关。
     * 其余行（例如同样没 target 的「随周次滑动」「模糊滑杆」）保持 null ——
     * 它们由分派器按 rowId 处理，本表不替它们猜。
     */
    fun resolveTarget(rowId: String, explicitTarget: String?): String? = when {
        explicitTarget != null -> explicitTarget
        rowId == ROW_CLEAR -> ROW_CLEAR
        rowId == AUTO_APPLY_TOGGLE -> AUTO_APPLY_TOGGLE
        else -> null
    }
}

/** 壁纸面板 target 解析后的动作。 */
sealed interface WallpaperSheetIntent {

    /** 选完图返回：数据侧负责把 URI 收进受管目录并写壁纸（Dart `:1007-1019`）。 */
    data class Picked(val uri: String) : WallpaperSheetIntent

    /** 切回某条历史：连取景一起还原（Dart `:294-316`）。 */
    data class SelectHistory(val key: String) : WallpaperSheetIntent

    /** 确认删除某条历史：摘条目 + 排期删文件（Dart `:325-354`）。 */
    data class ConfirmRemove(val key: String) : WallpaperSheetIntent

    /** 撤销删除：整份旧历史放回（Dart `:356-378`）。 */
    data class UndoRemove(val key: String) : WallpaperSheetIntent

    /** 点「选择图片」行：打开系统相册。 */
    data object ChooseImage : WallpaperSheetIntent

    /** 点「文件已丢失」警示条：同样打开系统相册（Dart `:894` `onTap: onPick`）。 */
    data object MissingImage : WallpaperSheetIntent

    /** 「调整位置」：壳推取景页（Dart `:919-925`）。 */
    data object AdjustPosition : WallpaperSheetIntent

    /** 「清除图片」：只清设置、**不删文件**（图可能还在历史里，Dart `:458-470`）。 */
    data object ClearImage : WallpaperSheetIntent

    /** 取消移除：面板本地收回确认态，不动数据。 */
    data object CancelRemove : WallpaperSheetIntent

    /** 切换自动换：数据侧按台账现值取反并落盘（见 [WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE]）。 */
    data object ToggleAutoApply : WallpaperSheetIntent

    /** 打开每日壁纸图库页（壳路由）。 */
    data object OpenGallery : WallpaperSheetIntent
}

/**
 * target 串 → [WallpaperSheetIntent]。
 *
 * 认不出返回 null（不抛错）：target 可能来自旧存档 / 新版本，错误串不该让设置页崩。
 * 前缀类 target 允许 key 里继续含冒号（Windows 盘符、`content://` URI），所以一律
 * `removePrefix` 而不是 `split(':')`。
 */
fun parseWallpaperSheetTarget(target: String?): WallpaperSheetIntent? {
    if (target == null || target.isEmpty()) return null
    return when (target) {
        WallpaperSheetActionTargets.ROW_PICK -> WallpaperSheetIntent.ChooseImage
        WallpaperSheetActionTargets.ROW_MISSING -> WallpaperSheetIntent.MissingImage
        WallpaperSheetActionTargets.ROW_ADJUST -> WallpaperSheetIntent.AdjustPosition
        WallpaperSheetActionTargets.ROW_CLEAR -> WallpaperSheetIntent.ClearImage
        WallpaperSheetActionTargets.ROW_CANCEL_DELETE -> WallpaperSheetIntent.CancelRemove
        WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE -> WallpaperSheetIntent.ToggleAutoApply
        WallpaperSheetActionTargets.OPEN_GALLERY -> WallpaperSheetIntent.OpenGallery
        else -> when {
            target.startsWith(WallpaperSheetActionTargets.PICKED_PREFIX) ->
                target.removePrefix(WallpaperSheetActionTargets.PICKED_PREFIX)
                    .takeIf { it.isNotEmpty() }
                    ?.let { WallpaperSheetIntent.Picked(it) }

            target.startsWith(WallpaperSheetActionTargets.SELECT_PREFIX) ->
                target.removePrefix(WallpaperSheetActionTargets.SELECT_PREFIX)
                    .takeIf { it.isNotEmpty() }
                    ?.let { WallpaperSheetIntent.SelectHistory(it) }

            target.startsWith(WallpaperSheetActionTargets.CONFIRM_DELETE_PREFIX) ->
                target.removePrefix(WallpaperSheetActionTargets.CONFIRM_DELETE_PREFIX)
                    .takeIf { it.isNotEmpty() }
                    ?.let { WallpaperSheetIntent.ConfirmRemove(it) }

            target.startsWith(WallpaperSheetActionTargets.UNDO_REMOVE_PREFIX) ->
                target.removePrefix(WallpaperSheetActionTargets.UNDO_REMOVE_PREFIX)
                    .takeIf { it.isNotEmpty() }
                    ?.let { WallpaperSheetIntent.UndoRemove(it) }

            else -> null
        }
    }
}
