package com.mutx163.qingyu.pages.settings

/**
 * 外观编辑页（`lib/screens/settings/settings_appearance_editor.dart:44-2091`）结构模型。
 *
 * ## 这一页为什么只落「骨架」
 *
 * Flutter 侧它是**沉浸式整页**：整屏暗底 + 中间一张「真首页缩尺卡」（烤图，
 * :56-73 的方案 A）+ 顶部一行 chrome + 底部两个圆钮。其中缩尺卡是**录一帧真实
 * 首页内容树**得到的位图，官方 Miuix 没有任何对应物，通用渲染层也画不出——
 * 它必须由宿主注入预览槽位（与课程卡片页顶部周预览同一种做法）。
 *
 * 所以本模型负责两件可迁移的事：
 * 1. **页面骨架**：[spec] 给出「预览占位 + 底部两个入口」的节点树；
 * 2. **顶部 chrome 与日 / 周分段**：[chromeRows] / [dayWeekOptions] 把这些控件
 *    的文案与取值描述出来（它们是浮层，不是设置列表里的一行，所以不进 [spec]
 *    的节点树——硬塞进去会凭空造出一个设置行）。
 *
 * 面板本身（材质 / 壁纸）在 [SettingsMaterialSheetPage] / [SettingsWallpaperSheetPage]。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | 整页暗底 + 烤图预览卡（:1616-1720） | `appearanceEditor.preview` | 官方无对应物：真首页烤图，宿主注入 |
 * | 顶部「取消」胶囊（:1901-1905） | `appearanceEditor.cancel` | `basic.Button`（胶囊） |
 * | 顶部日 / 周分段（:1958-2008） | [dayWeekOptions] | `basic.TabRow` |
 * | 顶部「完成」胶囊（:1909-1913） | `appearanceEditor.done` | `basic.Button`（胶囊） |
 * | 底部「调整壁纸」圆钮（:2031-2035） | `appearanceEditor.wallpaper` | `MiuixArrowPreference`（列表化后的入口） |
 * | 底部「材质」圆钮（:2039-2043） | `appearanceEditor.material` | `MiuixArrowPreference` |
 * | 整页加载罩（:1868） | [LOADING_LABEL] | `basic.CircularProgress` + 文案 |
 *
 * ## 不写进模型的行为（接线层必须照做）
 *
 * 1. 本页**即时落盘**（:75-76），「取消」= 用进页时那份设置回滚（[cancelTarget]），
 *    「完成」= 保留并返回（[doneTarget]）；
 * 2. 缩放转场分层出场（:259-269）：暗底走 `growT`、chrome 走 `chromeT`；
 * 3. 渲染源烤图与 `PreviewBakeBoundary` 的接线（:212-216）——纯渲染机制。
 */
object SettingsAppearanceEditorPage {

    const val ID = "settings-appearance-editor"

    /** 顶栏被撤掉了（:1895-1898），但 spec 仍需一个标题；取 ARB 里同一页的名字。 */
    val TITLE = SettingsStrings.appearanceEditorTitle

    /** 加载罩那行字（:1868 `commonLoadingLabel`）。 */
    val LOADING_LABEL = SettingsStringsExt1.commonLoadingLabel

    /** 顶部「取消」：回滚到进页时的草稿（:1590-1597 系统返回同义）。 */
    const val CANCEL_TARGET = "appearanceEditor.cancel"

    /** 顶部「完成」：保留草稿并返回。 */
    const val DONE_TARGET = "appearanceEditor.done"

    /** 底部「调整壁纸」入口（打开壁纸面板）。 */
    const val WALLPAPER_TARGET = "appearanceEditor.wallpaper"

    /** 底部「材质」入口（打开材质面板）。 */
    const val MATERIAL_TARGET = "appearanceEditor.material"

    @Suppress("UnusedParameter")
    fun spec(
        state: SettingsPageState,
        material: MaterialPanelState = MaterialPanelState(),
    ): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()

        // 预览卡：真首页按整屏 1:1 渲染后烤成一张图，等比缩进卡片（:56-73）。
        // 官方没有「任意位图预览卡」，label 不给 ARB 文案（Flutter 侧这一块**没有**
        // 任何标题字：卡片就是那一屏本身）。
        nodes += SettingsInline(
            id = "appearanceEditor.preview",
            kind = InlineKind.PREVIEW_CARD,
            note = "真首页缩尺卡（:56-73 方案 A 烤图）：官方无对应物，由宿主按" +
                "PreviewBakeBoundary 烤出的位图注入预览槽位；本节点只占位并说明",
        )

        // 底部一排圆形玻璃入口（:2011-2049）：两个，居中等距。
        nodes += SettingsGroup(
            id = "appearanceEditor.actions",
            children = listOf(
                settingsRow(
                    id = "appearanceEditor.wallpaper",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt1.appearanceEditorWallpaperAction,
                    action = SettingsAction.SHEET,
                    actionTarget = WALLPAPER_TARGET,
                ),
                settingsRow(
                    id = "appearanceEditor.material",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt1.appearanceEditorMaterialAction,
                    action = SettingsAction.SHEET,
                    actionTarget = MATERIAL_TARGET,
                ),
            ),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = TITLE.key,
            title = TITLE.text,
            nodes = nodes,
            // 预览不在顶栏下、整页也不滚动（:1581-1720 是 Positioned 叠层），
            // 折叠大标题这件事在本页没有意义。
            collapsibleLargeTitle = false,
            previewFlex = 4,
            contentFlex = 6,
        )
    }

    /**
     * 顶部 chrome 的两个胶囊按钮（:1899-1918）。
     *
     * 它们是**浮层**而不是列表行——放在这里而不是塞进 [spec] 的节点树，
     * 免得渲染层把它们当成设置行排进列表。
     */
    fun chromeRows(state: SettingsPageState): List<SettingsRow> = listOf(
        settingsRow(
            id = "appearanceEditor.cancel",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt1.cancelAction,
            action = SettingsAction.NAVIGATE,
            actionTarget = CANCEL_TARGET,
        ),
        settingsRow(
            id = "appearanceEditor.done",
            component = MiuixRowComponent.ARROW,
            title = SettingsStringsExt1.appearanceEditorDoneAction,
            action = SettingsAction.NAVIGATE,
            actionTarget = DONE_TARGET,
        ),
    )

    /**
     * 日 / 周分段的两项（:1998-2005）。
     *
     * 只影响**这份缩尺首页**看日课表还是周课表，不动真实浏览位置（首页在预览模式下
     * 不写回访状态，见 `TimetableHomePreviewScope`）。
     */
    fun dayWeekOptions(): List<SettingsOption> = listOf(
        option(DAY_PREVIEW_ID, SettingsStringsExt1.glassDockTabDay),
        option(WEEK_PREVIEW_ID, SettingsStringsExt1.glassDockTabWeek),
    )

    /**
     * 分段当前选中项。初始值跟首页持久化的视图走（:203-204），
     * 所以用户在日视图里进编辑页，三者从第一帧起一致。
     */
    fun dayWeekSelectedId(material: MaterialPanelState): String =
        if (material.previewDayView) DAY_PREVIEW_ID else WEEK_PREVIEW_ID

    const val DAY_PREVIEW_ID = "day"
    const val WEEK_PREVIEW_ID = "week"
}

/**
 * 材质面板的两个页签（`settings_appearance_editor.dart:2226-2356` 的 `_MaterialSheetBody`）。
 *
 * 翻页标签**自己就是标题**（:2312-2314），两页内容分别由
 * [SettingsMaterialGeneralPage] / [SettingsMaterialCourseCardPage] 提供。
 *
 * ⚠️ 翻页必须是面板内联的一层：面板是根覆盖层自插条目，任何二级弹层 / 路由
 * 都会被压在它背面（:864-867，2026-09-19 真机实锤）。
 */
object SettingsMaterialSheetPage {

    const val ID = "settings-material"

    /** 页序：0 = 通用，1 = 课程卡片（:2253-2255）。 */
    val TAB_LABELS: List<ArbText> = listOf(
        SettingsStrings.generalSettingsTitle,
        SettingsStringsExt1.surfaceCourseCard,
    )

    /** 课程卡片设置页的「卡片外观」跳转牌用的直达页下标（:85-88）。 */
    const val COURSE_CARD_PAGE_INDEX = 1
}

/**
 * 壁纸面板的两个页签（`settings_appearance_editor.dart:2104-2224` 的 `_WallpaperSheetBody`）。
 *
 * 用新加的短标签，**不要**复用 `homePageWallpaperTitle`（背景图片）或
 * `settingsTitle`（课表设置）：前者是这一页里那张卡自己的标题，复用会在同一页
 * 出现两个一模一样的「背景图片」；后者是整页标题，四个字也塞不进胶囊当页签（:2167-2175）。
 */
object SettingsWallpaperSheetPage {

    const val ID = "settings-wallpaper"

    /** 页序：0 = 壁纸，1 = 设置（:2115-2117）。 */
    val TAB_LABELS: List<ArbText> = listOf(
        SettingsStringsExt1.wallpaperSheetTabPicker,
        SettingsStringsExt1.wallpaperSheetTabSettings,
    )
}
