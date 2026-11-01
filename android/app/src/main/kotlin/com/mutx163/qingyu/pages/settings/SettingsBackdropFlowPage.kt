package com.mutx163.qingyu.pages.settings

/**
 * 首页壁纸流程（`lib/screens/settings/settings_home_backdrop_flow.dart:57-1182`）与
 * 「最近使用」缩略图条（`settings_recent_wallpaper.dart:38-397`）的**块模型**。
 *
 * ## 为什么不是「一整页 spec」
 *
 * Dart 侧这里根本没有一个叫「壁纸页」的页面：
 * - `settings_home_backdrop_flow.dart` 是 **mixin**（:57 `HomeBackdropFlow`），
 *   给两个宿主提供同一套 builder —— 「课表页面」设置里的壁纸行，以及「外观编辑」
 *   页底部那颗「调整壁纸」按钮打开的弹窗；
 * - `settings_recent_wallpaper.dart` 是其中的「最近使用」整段。
 *
 * 所以本批把它落成**可组装的块**：宿主（[SettingsBackdropFlowPage.selectionPage] /
 * [selectionRow] / [settingsPage]）自己决定嵌在哪一页。这与 Flutter 侧
 * 「同一套 builder、两个宿主逐字同源」是同一个结构（:41-56 的「为什么要抽成 mixin」：
 * 历史补记、淘汰白名单、失效路径兜底、位置页确认语义，任何一处抄错都会分叉）。
 *
 * ## 两个宿主的差异只有一个数（左右内缩与行底色，:79-103）
 *
 * | 宿主 | 左右内缩 | 行底色 | 为什么 |
 * |---|---|---|---|
 * | 「课表页面」设置 | 16 | 有 | 那几块在 `HyperosListGroup` 卡片里，16 是卡片自己的行内缩 |
 * | 「外观编辑」的壁纸弹窗 | 0 | 无 | 面板的 `insideMargin`(16) 已经给了，再垫一层就是 32 |
 *
 * ## 不写进模型的行为（接线层照做）
 *
 * 1. 删除文件前必须有 2.5s 反悔窗口（:166-170 / :380-417），且撤销要能整份历史放回；
 * 2. 淘汰文件的白名单是**三路并集**（所有课表当前壁纸 + 草稿那张 + 图库台账，
 *    :265-274 / :1105-1132）——漏一路就会删掉别的课表正在用的图；
 * 3. 位置编辑页必须压在**弹层收起之后**再推（:115-149），否则页面会被面板的
 *    全屏透明屏障挡住（2026-09-20 真机口径）。
 */
object SettingsBackdropFlowPage {

    /** 壁纸流程不产生独立页面 —— 它是被两个宿主嵌进去的一堆块。 */
    val PAGE_ID: String? = null

    /**
     * 「壁纸面板第一页（选图）」的**桥接页 id**。
     *
     * Dart 侧它不是独立页（见 [PAGE_ID]），但设置族桥 [SettingsPageBridge.specFor]
     * 需要一个可寻址的键，让宿主/测试用同一个串要这份 spec。**与面板 spec 自身的
     * id 不同**：返回的 spec id 仍是 [SettingsWallpaperSheetPage.ID]（两个页签共用）。
     */
    const val SELECTION_SPEC_ID = "settings-backdrop-flow"

    const val HOST_SETTINGS_ROW_INSET = 16.0
    const val HOST_SHEET_ROW_INSET = 0.0
    const val HOST_SETTINGS_ROWS_HAVE_CARD_BACKGROUND = true
    const val HOST_SHEET_ROWS_HAVE_CARD_BACKGROUND = false

    /** 历史上限 10 条（ARB `homePageWallpaperRecentSubtitle` 里写着这个数）。 */
    const val MAX_HISTORY_ENTRIES = 10

    /**
     * 三根控件各自写到哪：随周次滑动与模糊写**草稿**，自动换写**图库台账**。
     *
     * 自动换那条容易接错：`BingWallpaperStore` 不走草稿，宿主的 `setState` 对它
     * 完全无感 —— 弹层正文不在宿主 widget 树下时，「点了没反应」就是这么来的
     * （:501-514，2026-10-06 实报）。模型把这件事记成常量，接线层一眼可查。
     */
    const val FOLLOWS_WEEK_PAGER_GOES_THROUGH_DRAFT = true
    const val BLUR_GOES_THROUGH_DRAFT = true
    const val AUTO_APPLY_GOES_THROUGH_DRAFT = false

    // -------------------------------------------------------------- 文案常量

    val REMOVE_BADGE_TOOLTIP = SettingsStringsExt1.wallpaperHistoryRemoveBadgeTooltip
    val REMOVE_IN_USE_TOAST = SettingsStringsExt1.wallpaperHistoryRemoveInUseToast
    val REMOVED_TOAST = SettingsStringsExt1.wallpaperHistoryRemovedToast
    val REMOVE_UNDO = SettingsStringsExt1.wallpaperHistoryRemoveUndo
    val FILE_MISSING_TOAST = SettingsStringsExt1.homePageWallpaperFileMissingToast
    val AUTO_APPLYING = SettingsStringsExt1.bingWallpaperAutoApplyApplying
    val AUTO_ALREADY_DONE = SettingsStringsExt1.bingWallpaperAutoApplyAlreadyDone
    val AUTO_STALE = SettingsStringsExt1.bingWallpaperAutoApplyStale
    val WALLPAPER_BLUR_OFF = SettingsStringsExt1.homePageWallpaperBlurOff

    /** 壁纸模糊滑杆的上下限（`widgets/wallpaper_blur_tile.dart:56-58` 引的设置常量）。 */
    const val BLUR_SIGMA_MIN = 0.0
    const val BLUR_SIGMA_MAX = 24.0

    // ------------------------------------------------------------ 第一页「壁纸」

    /**
     * 壁纸面板第一页（`:439-476`）：选图块 + 「最近使用」条 + 每日壁纸入口。
     *
     * 顺序即用户口径：相册选图与历史回放是**用户自己的图**，图库是**外部来源**，
     * 后者在后（:480-481）。
     */
    fun selectionPage(
        backdrop: BackdropFlowState,
        selection: SelectionPageState = SelectionPageState(backdrop),
    ): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        nodes += SettingsGroup(
            id = "backdrop.image",
            children = imageRows(backdrop, selection),
        )

        // 「最近使用」整段（settings_recent_wallpaper.dart:100-205）：
        // 标题 + 说明 + 缩略图条 + 移除确认条。
        val entries = recentEntries(backdrop.history, backdrop.imagePath)
        if (entries.isNotEmpty()) {
            nodes += SettingsInline(
                id = "backdrop.recent",
                kind = InlineKind.CONTROL_CARD,
                note = "「最近使用」缩略图条（settings_recent_wallpaper.dart:100-205）：" +
                    "78dp 缩略图卡横向排列，官方没有横向缩略图条控件；" +
                    "colors 承载条目键（壁纸绝对路径）",
                labelKey = SettingsStringsExt1.homePageWallpaperRecentTitle.key,
                label = SettingsStringsExt1.homePageWallpaperRecentTitle.zh,
                valueKey = SettingsStringsExt1.homePageWallpaperRecentSubtitle.key,
                value = SettingsStringsExt1.homePageWallpaperRecentSubtitle.zh,
                texts = listOf(
                    SettingsInlineText(
                        SettingsStringsExt1.homePageWallpaperRecentImageLabel.key,
                        SettingsStringsExt1.homePageWallpaperRecentImageLabel.zh,
                    ),
                ),
                colors = entries,
                selectedColor = backdrop.imagePath,
            )
        }

        // 移除确认条（settings_recent_wallpaper.dart:169-203）：确认按钮**画在条外面**，
        // 不塞进 78 宽的卡里（塞进去只剩 37 宽、按不准，见 :23-37 的三条理由）。
        val armed = selection.armedKey
        if (armed != null) {
            nodes += SettingsDescription(
                id = "backdrop.recent.confirmHint",
                textKey = SettingsStringsExt1.wallpaperHistoryRemoveConfirmHint.key,
                text = SettingsStringsExt1.wallpaperHistoryRemoveConfirmHint.zh,
            )
            nodes += SettingsGroup(
                id = "backdrop.recent.confirmActions",
                children = listOf(
                    settingsRow(
                        id = "backdrop.recent.confirmDelete",
                        component = MiuixRowComponent.ARROW,
                        title = SettingsStringsExt1.deleteAction,
                        destructive = true,
                        action = SettingsAction.WRITE_SETTING,
                        actionTarget = "backdrop.recent.confirmDelete:$armed",
                    ),
                    settingsRow(
                        id = "backdrop.recent.cancelDelete",
                        component = MiuixRowComponent.ARROW,
                        title = SettingsStringsExt1.cancelAction,
                        action = SettingsAction.WRITE_SETTING,
                        actionTarget = "backdrop.recent.cancelDelete",
                    ),
                ),
            )
        }

        // 每日壁纸入口 + 自动换开关（:478-530）
        nodes += SettingsGap("backdrop.gap.bing")
        nodes += SettingsGroup(
            id = "backdrop.bing",
            children = listOf(
                settingsRow(
                    id = "backdrop.bing.entry",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt1.bingWallpaperGalleryTitle,
                    action = SettingsAction.NAVIGATE,
                    actionTarget = BING_GALLERY_TARGET,
                ),
                settingsRow(
                    id = "backdrop.bing.autoApply",
                    component = MiuixRowComponent.SWITCH,
                    title = SettingsStringsExt1.bingWallpaperAutoApplyTitle,
                    subtitle = SettingsStringsExt1.bingWallpaperAutoApplySubtitle,
                    switchValue = backdrop.bingAutoApplyEnabled,
                    action = SettingsAction.WRITE_SETTING,
                ),
            ),
        )

        return SettingsPageSpec(
            id = SettingsWallpaperSheetPage.ID,
            titleKey = SettingsWallpaperSheetPage.TAB_LABELS[0].key,
            title = SettingsWallpaperSheetPage.TAB_LABELS[0].zh,
            nodes = nodes,
        )
    }

    /** 每日壁纸图库的导航目标（`bing_wallpaper_gallery_page.dart:33-43`）。 */
    const val BING_GALLERY_TARGET = "bingWallpaperGallery"

    /**
     * 选图块的四行（`:857-940`）：
     * 标题与文件名 → （文件丢了就多一条警示条）→ 选择图片 → 调整位置 / 清除图片。
     */
    private fun imageRows(
        backdrop: BackdropFlowState,
        selection: SelectionPageState,
    ): List<SettingsNode> {
        val hasWallpaper = !backdrop.imagePath.isNullOrEmpty()
        val rows = mutableListOf<SettingsNode>()
        rows += settingsRow(
            id = "backdrop.image",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt1.homePageWallpaperTitle,
            // 没选图 → ARB 里的「未选择」；选了 → 文件名（用户数据，空键让文案对照跳过）
            subtitle = if (hasWallpaper) {
                ArbText(NON_ARB_TEXT, fileNameOf(backdrop.imagePath))
            } else {
                SettingsStringsExt1.homePageImageNotSelected
            },
        )
        // 文件在、但盘上已经没了（换机 / 清理数据 / 云同步只带回设置不带图，:873-895）
        if (hasWallpaper && selection.fileMissing) {
            rows += settingsRow(
                id = "backdrop.image.missing",
                component = MiuixRowComponent.ARROW,
                title = SettingsStringsExt1.homePageWallpaperFileMissingTitle,
                subtitle = SettingsStringsExt1.homePageWallpaperFileMissingSubtitle,
                // 警示条本身就是一个动作：点它回到选图，用户看到警示时手指就在正确的位置上
                action = SettingsAction.NAVIGATE,
                actionTarget = "backdrop.image.missing",
            )
        }
        rows += settingsRow(
            id = "backdrop.image.pick",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt1.homePagePickImageAction,
            action = SettingsAction.NAVIGATE,
            actionTarget = "backdrop.image.pick",
        )
        if (hasWallpaper) {
            rows += settingsRow(
                id = "backdrop.image.adjust",
                component = MiuixRowComponent.ARROW,
                title = SettingsStringsExt1.homePageAdjustPositionAction,
                action = SettingsAction.NAVIGATE,
                actionTarget = "backdrop.image.adjust",
            )
            rows += settingsRow(
                id = "backdrop.image.clear",
                component = MiuixRowComponent.ARROW,
                title = SettingsStringsExt1.homePageClearImageAction,
                action = SettingsAction.WRITE_SETTING,
            )
        }
        return rows
    }

    // ------------------------------------------------------------ 第二页「设置」

    /**
     * 壁纸面板第二页（`:722-737`）：只有两根控件。
     *
     * ⚠️ 两根都**不要再垫行内边距**：两端留白由面板的 pageShell 统一给
     * （:723-724，`test/screens/appearance_editor_test.dart` 钉过）。
     */
    fun settingsPage(backdrop: BackdropFlowState): SettingsPageSpec = SettingsPageSpec(
        id = SettingsWallpaperSheetPage.ID,
        titleKey = SettingsWallpaperSheetPage.TAB_LABELS[1].key,
        title = SettingsWallpaperSheetPage.TAB_LABELS[1].zh,
        nodes = listOf(
            SettingsGroup(
                id = "backdrop.settings",
                children = listOf(
                    settingsRow(
                        id = "backdrop.followsWeekPager",
                        component = MiuixRowComponent.SWITCH,
                        title = SettingsStringsExt1.homePageBackdropFollowsWeekPagerTitle,
                        subtitle = SettingsStringsExt1.homePageBackdropFollowsWeekPagerSubtitle,
                        switchValue = backdrop.followsWeekPager,
                        action = SettingsAction.WRITE_SETTING,
                    ),
                    blurRow(backdrop.blurSigma),
                ),
            ),
        ),
    )

    /**
     * 壁纸模糊滑杆（`widgets/wallpaper_blur_tile.dart:56-84`）。
     *
     * 0 档显示「关闭」而不是「0」：这一档是"完全没有模糊"，不是"模糊量为 0"
     * —— 前者用户能理解，后者会让人以为还有一点点糊。
     */
    private fun blurRow(sigma: Double): SettingsRow {
        // 存量值可能越界（旧存档 / 手改 JSON）：拇指与数字都夹到收口带，
        // 与出图侧同口径 —— 否则就是「拖了数字不动」那一类半失效
        val shown = sigma.coerceIn(BLUR_SIGMA_MIN, BLUR_SIGMA_MAX)
        val off = shown <= BLUR_SIGMA_MIN
        return settingsRow(
            id = "backdrop.blur",
            component = MiuixRowComponent.SLIDER,
            title = SettingsStringsExt1.homePageWallpaperBlurTitle,
            valueKey = if (off) SettingsStringsExt1.homePageWallpaperBlurOff.key else null,
            value = if (off) {
                SettingsStringsExt1.homePageWallpaperBlurOff.zh
            } else {
                shown.toInt().toString()
            },
            slider = SettingsSliderSpec(
                min = BLUR_SIGMA_MIN,
                max = BLUR_SIGMA_MAX,
                // 每格 1：档数跟着上限走，别写死
                divisions = BLUR_SIGMA_MAX.toInt(),
                defaultValue = BLUR_SIGMA_MIN,
            ),
            sliderValue = shown,
            action = SettingsAction.WRITE_SETTING,
        )
    }

    // ---------------------------------------------------------- 纯逻辑搬运

    /**
     * 从路径里取文件名（`:866-871`）。
     *
     * 两种分隔符都切，而不是 `Platform.pathSeparator`：这条路径可能是**别的平台**
     * 存下来的（设置能跨设备同步，本仓也有 linux / macos / windows 目标），
     * 只按当前系统的分隔符切，整条路径会被当成文件名显示出来。
     */
    fun fileNameOf(path: String?): String {
        if (path.isNullOrEmpty()) return ""
        return path.split('/', '\\').last()
    }

    /**
     * 「最近使用」的实际条目（`:800-818`）：全局历史里当前可用者，
     * 历史还是空的老用户把**当前生效的那一张补在最前**。
     *
     * 当前这张已经出现在历史里时**不重复补**（`any { it.key == currentKey }`）。
     */
    fun recentEntries(history: List<String>, currentKey: String?): List<String> {
        if (currentKey.isNullOrEmpty()) return history
        if (history.contains(currentKey)) return history
        return listOf(currentKey) + history
    }

    /**
     * 某一条能不能移除（`settings_recent_wallpaper.dart:128-137` + `:825-828`）。
     *
     * 正在用的那张**不给移除**：它连角标都没有，唯一的入口是长按，
     * 而长按的解释由宿主给（`_warnBackdropHistoryInUse`）。
     */
    fun isRemovable(key: String, selectedKey: String?): Boolean =
        selectedKey != null && key != selectedKey
}

/** 壁纸流程读到的设置（页面私有输入，默认值照抄 `timetable_settings.dart`）。 */
data class BackdropFlowState(
    /** 当前背景图的绝对路径（null / 空 = 没选）。 */
    val imagePath: String? = null,
    /** 「最近使用」的条目键（壁纸绝对路径，最新在前）。 */
    val history: List<String> = emptyList(),
    /** `:939 homePageBackdropFollowsWeekPager = false`。 */
    val followsWeekPager: Boolean = false,
    /** `:898 homePageWallpaperBlurSigma = minHomePageWallpaperBlurSigma`（= 0）。 */
    val blurSigma: Double = 0.0,
    /** 图库台账里的自动换开关（`BingWallpaperStore.autoApplyEnabled`）。 */
    val bingAutoApplyEnabled: Boolean = false,
)

/**
 * 第一页的额外状态（`fileMissing` 与 `armedKey` 都不是设置字段）。
 *
 * [fileMissing] 判据在 Dart 侧走 `homePageImageProvider`（渲染侧判"有没有壁纸"用的
 * 同一条，背后是按路径记忆的 memo，不摸盘，`:873-881`）——由接线层填进来。
 * [armedKey] 是「已发起移除、正等确认」那一条，纯 widget 状态
 * （`RecentWallpaperSectionState._armedKey`）。
 */
data class SelectionPageState(
    val backdrop: BackdropFlowState,
    val fileMissing: Boolean = false,
    val armedKey: String? = null,
)
