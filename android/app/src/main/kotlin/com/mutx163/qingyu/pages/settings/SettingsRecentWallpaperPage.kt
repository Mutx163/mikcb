package com.mutx163.qingyu.pages.settings

/**
 * 「最近使用」缩略图条（`lib/screens/settings/settings_recent_wallpaper.dart:38-397`）
 * 的结构模型。
 *
 * ## 这一段的形状
 *
 * 标题 + 说明 + 横向缩略图条 + **移除确认条**。最后那一条是这一段存在的关键：
 * 确认按钮刻意**画在条外面**、而不是塞进 78 宽的小卡里（第一版塞进去过，被否掉）——
 *
 * * **塞不进**：78 宽的卡里平分两颗按钮只剩约 37 宽，要放到 24px 高才不至于把
 *   卡片标签顶掉，而 24×37 远小于最小点击区，真机上按不准；
 * * **几何必然出错**：卡片的 `MiuixPressable` 会按自己的 14 圆角裁剪子树，于是按钮
 *   自己的圆角和父级裁出来的圆角对不上，「某个角圆得不一样」；
 * * **画在条外面就没有这些约束**（:23-37）。
 *
 * 确认态**不弹覆盖层**：这个流程有两个宿主，其中「外观编辑」页那颗「调整壁纸」是
 * 底部弹层，而弹层是根覆盖层自插条目，任何再往上的弹层都会被压在它背面
 * （真机实锤）。「确认条就地长在列表下面」在两个宿主里天然一致。
 *
 * ## 不写进模型的行为
 *
 * 确认删除之后的副作用（摘条目 / 落盘 / 排删文件 / 2.5s 反悔窗口）在
 * `settings_home_backdrop_flow.dart:318-354`，接线层照做。
 */
object SettingsRecentWallpaperSection {

    /** 缩略图条的固定高度（:12）。 */
    const val STRIP_HEIGHT = 116.0

    /** 卡内标签位的高度（:18）：常态是标签、确认态是按钮行，定高才不会让缩略图缩一下。 */
    const val LABEL_HEIGHT = 26.0

    /** 单张卡宽（:265）。 */
    const val CARD_WIDTH = 78.0

    /** 角标直径（:377）。 */
    const val BADGE_SIZE = 22.0

    /** 角标里那颗 × 的字号（:385）。 */
    const val BADGE_GLYPH_SIZE = 15.0

    /** 角标底色：纯黑 45% 不透明（:380）。 */
    const val BADGE_ALPHA = 0.45

    /** 已发起移除时压在缩略图上的那层黑（`Color(0x99000000)`，:306）。 */
    const val DIM_OVERLAY_ARGB = "0x99000000"

    /** 标签最多两行（:320）。 */
    const val LABEL_MAX_LINES = 2

    /** 标签字号（:324）。 */
    const val LABEL_FONT_SIZE = 11.0

    /** 标签行高倍数（:325）。 */
    const val LABEL_HEIGHT_MULTIPLIER = 1.2

    /** 历史上限（ARB 文案里写着「最多保留 10 张」）。 */
    const val MAX_ENTRIES = 10

    val BADGE_TOOLTIP = SettingsStringsExt1.wallpaperHistoryRemoveBadgeTooltip
    val CONFIRM_HINT = SettingsStringsExt1.wallpaperHistoryRemoveConfirmHint
    val REMOVE_ACTION = SettingsStringsExt1.deleteAction
    val CANCEL_ACTION = SettingsStringsExt1.cancelAction
    val REMOVE_IN_USE_TOAST = SettingsStringsExt1.wallpaperHistoryRemoveInUseToast

    /** 空列表 = 整段不渲染（宿主侧判据，:816-818）。 */
    fun isEmpty(entries: List<String>): Boolean = entries.isEmpty()

    /**
     * 一段的 spec：标题 + 说明 + 缩略图条（+ 确认态时的说明与两颗按钮）。
     *
     * 缩略图本身是网络 / 本地图片，模型只描述「有哪几张、哪张被选中」——
     * 条目键承载在 [SettingsInline.colors] 里，渲染层按键去加载图。
     */
    fun spec(state: RecentWallpaperState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()
        // armed 的键已经不存在的场景先清掉，免得留下一条永远按不掉的确认条（:80-88）
        val armed = normalizeArmedKey(state.armedKey, state.entries)

        if (!isEmpty(state.entries)) {
            nodes += settingsRow(
                id = "backdrop.recent.header",
                component = MiuixRowComponent.ARROW,
                title = SettingsStringsExt1.homePageWallpaperRecentTitle,
                subtitle = SettingsStringsExt1.homePageWallpaperRecentSubtitle,
            )
            nodes += SettingsInline(
                id = "backdrop.recent.strip",
                kind = InlineKind.CONTROL_CARD,
                note = "横向缩略图条（settings_recent_wallpaper.dart:120-168）：" +
                    "78dp 卡 + 右上角移除角标，官方没有横向缩略图条控件；" +
                    "colors 承载条目键（壁纸绝对路径）",
                texts = listOf(
                    SettingsInlineText(
                        SettingsStringsExt1.homePageWallpaperRecentImageLabel.key,
                        SettingsStringsExt1.homePageWallpaperRecentImageLabel.zh,
                    ),
                ),
                colors = state.entries,
                selectedColor = state.selectedKey,
            )
        }

        if (armed != null) {
            nodes += SettingsDescription(
                id = "backdrop.recent.confirmHint",
                textKey = CONFIRM_HINT.key,
                text = CONFIRM_HINT.zh,
            )
            nodes += SettingsGroup(
                id = "backdrop.recent.confirmActions",
                children = listOf(
                    settingsRow(
                        id = "backdrop.recent.confirmDelete",
                        component = MiuixRowComponent.ARROW,
                        title = REMOVE_ACTION,
                        destructive = true,
                        action = SettingsAction.WRITE_SETTING,
                        actionTarget = "backdrop.recent.confirmDelete:$armed",
                    ),
                    settingsRow(
                        id = "backdrop.recent.cancelDelete",
                        component = MiuixRowComponent.ARROW,
                        title = CANCEL_ACTION,
                        action = SettingsAction.WRITE_SETTING,
                        actionTarget = "backdrop.recent.cancelDelete",
                    ),
                ),
            )
        }

        return SettingsPageSpec(
            id = "settings-recent-wallpaper",
            titleKey = SettingsStringsExt1.homePageWallpaperRecentTitle.key,
            title = SettingsStringsExt1.homePageWallpaperRecentTitle.zh,
            nodes = nodes,
        )
    }

    /** 单张卡的状态推导（`_WallpaperThumbnailCard`，:230-397）。 */
    fun cardState(key: String, selectedKey: String?, armedKey: String?): RecentWallpaperCardState {
        val selected = selectedKey != null && key == selectedKey
        val armed = armedKey != null && key == armedKey
        return RecentWallpaperCardState(
            key = key,
            selected = selected,
            armed = armed,
            removable = selectedKey != null && key != selectedKey,
        )
    }

    /** 某一张能不能移除：正在用的那张不给（:128-137）。 */
    fun isRemovable(card: RecentWallpaperCardState): Boolean = card.removable

    /** 标签是否加粗：选中或已发起移除时 `w600`，否则 `w400`（:331-333）。 */
    fun labelBold(selected: Boolean, armed: Boolean): Boolean = selected || armed

    /**
     * 单击语义（:139-147）：已发起移除的那张，单击是**取消**而不是切壁纸 ——
     * 它此刻的语义是"要不要删"，顺手把壁纸也换了就是一次操作两个后果。
     */
    fun tapIntent(armed: Boolean, removable: Boolean): RecentWallpaperTapIntent =
        if (armed) RecentWallpaperTapIntent.DISARM else RecentWallpaperTapIntent.SELECT

    /**
     * 长按语义（:271-273）：
     * `onLongPress: armed ? onRequestRemove : (removable ? onRequestRemove : onBlockedRemove)`。
     */
    fun longPressIntent(armed: Boolean, removable: Boolean): RecentWallpaperLongPressIntent = when {
        armed -> RecentWallpaperLongPressIntent.DISARM
        removable -> RecentWallpaperLongPressIntent.REQUEST_REMOVE
        else -> RecentWallpaperLongPressIntent.BLOCKED_EXPLAIN
    }

    /**
     * 确认态的键归一（:80-88）：删掉之后（或历史被外部改动之后）不能让一个已经不存在的
     * key 继续挂着 —— 那会留下一条永远按不掉、也永远删不掉的确认条。
     */
    fun normalizeArmedKey(armedKey: String?, entries: List<String>): String? =
        armedKey?.takeIf { entries.contains(it) }
}

/** 一张缩略图卡的状态。 */
data class RecentWallpaperCardState(
    val key: String,
    val selected: Boolean,
    val armed: Boolean,
    val removable: Boolean,
) {
    /** 描边（:284-288）：armed → 危险色；selected → 主题色；否则透明。 */
    val edge: RecentWallpaperCardEdge
        get() = when {
            armed -> RecentWallpaperCardEdge.DANGER
            selected -> RecentWallpaperCardEdge.PRIMARY
            else -> RecentWallpaperCardEdge.NONE
        }

    /** 已发起移除时压暗缩略图（:300-308）。 */
    val dimmed: Boolean get() = armed

    /** 角标只在「可移除且未发起移除」时出现（:343 `if (removable && !armed)`）。 */
    val showRemoveBadge: Boolean get() = removable && !armed
}

/** 缩略图卡的描边色语义（渲染层据此取主题色 / 危险色）。 */
enum class RecentWallpaperCardEdge { NONE, PRIMARY, DANGER }

/** 单击意图。 */
enum class RecentWallpaperTapIntent { SELECT, DISARM }

/** 长按意图。 */
enum class RecentWallpaperLongPressIntent { REQUEST_REMOVE, DISARM, BLOCKED_EXPLAIN }

/** 一段的状态（宿主传入）。 */
data class RecentWallpaperState(
    /** 条目键（壁纸绝对路径），最新在前。 */
    val entries: List<String> = emptyList(),
    /** 当前正在用的那张；它不可移除。 */
    val selectedKey: String? = null,
    /** 已发起移除、正等确认的那一条；null = 没有。 */
    val armedKey: String? = null,
)
