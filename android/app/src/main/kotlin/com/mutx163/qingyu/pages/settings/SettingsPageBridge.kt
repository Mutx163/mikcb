package com.mutx163.qingyu.pages.settings

// ⚠️ 下面这一行是**跨域的反向依赖**（设置域 → `app/` 的分派器镜像枚举），有意为之：
// 分派器必须待在 `app/`（它被每一次 L0 无条件收录，不能 import `pages.settings`），
// 而映射函数必须待在 `pages/settings/`（它要 import 本包的页面词汇；放 `app/` 会让
// **所有模块**的 L0 报 Unresolved）。两边各只依赖对方的一个枚举，方向单一、无环。
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
// 设置模型（`app/` 下的完整显示模型）。同样是「设置域 → app」方向，理由同上。
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.pages.settings.AppFontMode
import com.mutx163.qingyu.pages.settings.AppThemeMode
import com.mutx163.qingyu.pages.settings.CourseCardHorizontalAlign
import com.mutx163.qingyu.pages.settings.CourseCardSurfaceStyle
import com.mutx163.qingyu.pages.settings.CourseCardVerticalAlign
import com.mutx163.qingyu.pages.settings.ForuiTheme
import com.mutx163.qingyu.pages.settings.SavedThemeRow
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsAppearancePage
import com.mutx163.qingyu.pages.settings.SettingsCourseCardPage
import com.mutx163.qingyu.pages.settings.SettingsGeneralPage
import com.mutx163.qingyu.pages.settings.SettingsPageSpec
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsThemeManagePage

/**
 * 设置族的**桥**：页面词汇（`pages/settings`）↔ 宿主词汇（`app/`）。
 *
 * ## 为什么这个文件在 composeP1 而不在 `main/.../app/`
 *
 * 它必须 import `pages.settings.*`，而 `pages/settings` **不在** L0 脚本的
 * `sharedModelDirs` 名单里：一旦放进 `main/.../app/`，所有泳道的 L0 都会因为
 * 「`app/` 收了这个文件、但 `pages/settings` 没被收」而报 Unresolved。
 * 放这里则两边都安全：L1 照常编译；本泳道跑 L0 时用 `-ExtraSources` 把它显式带上
 * （它是**纯 Kotlin，没有一行 Compose**，所以能被 kotlinc 直接编）。
 *
 * ## 三个映射
 *
 * 1. [toKind]：页面 `SettingsAction` → 宿主的 [SettingsActionKind]（11 个值逐个映射，
 *    有测试钉住不漂）；
 * 2. [toSettingsPageState]：设置模型 → 页面状态（spec 的唯一输入）；
 * 3. [specFor]：页 id → 本刀 4 页的 spec。
 */
object SettingsPageBridge {

    /** 本刀接的 4 个页 id（页面对象自己的常量，不在这里另抄一份）。 */
    val SUPPORTED_PAGE_IDS: List<String> = listOf(
        SettingsGeneralPage.ID,
        SettingsAppearancePage.ID,
        SettingsThemeManagePage.ID,
        SettingsCourseCardPage.ID,
    )

    /** 页面动作 → 宿主动作（一一对应，未知值返回 null）。 */
    fun toKind(action: SettingsAction): SettingsActionKind = when (action) {
        SettingsAction.NAVIGATE -> SettingsActionKind.NAVIGATE
        SettingsAction.SHEET -> SettingsActionKind.SHEET
        SettingsAction.DIALOG -> SettingsActionKind.DIALOG
        SettingsAction.WRITE_SETTING -> SettingsActionKind.WRITE_SETTING
        SettingsAction.RESET_SCOPE -> SettingsActionKind.RESET_SCOPE
        SettingsAction.CLIPBOARD_EXPORT -> SettingsActionKind.CLIPBOARD_EXPORT
        SettingsAction.CLIPBOARD_IMPORT -> SettingsActionKind.CLIPBOARD_IMPORT
        SettingsAction.RUN_NOW -> SettingsActionKind.RUN_NOW
        SettingsAction.COLOR_PICKER -> SettingsActionKind.COLOR_PICKER
        SettingsAction.MATERIAL_PANEL -> SettingsActionKind.MATERIAL_PANEL
        SettingsAction.RECOLOR_SHEET -> SettingsActionKind.RECOLOR_SHEET
    }

    /** 页 id → spec；不在本刀的 4 页里返回 null（壳据此决定要不要渲染）。 */
    fun specFor(pageId: String, state: SettingsPageState): SettingsPageSpec? = when (pageId) {
        SettingsGeneralPage.ID -> SettingsGeneralPage.spec(state)
        SettingsAppearancePage.ID -> SettingsAppearancePage.spec(state)
        SettingsThemeManagePage.ID -> SettingsThemeManagePage.spec(state)
        SettingsCourseCardPage.ID -> SettingsCourseCardPage.spec(state)
        else -> null
    }

    /**
     * 选色行的**当前色**（选色器要初值）。
     *
     * @return null 表示这个 rowId 不是本刀支持的选色行（宿主据此记 Ignored，不弹）。
     */
    fun currentColorHex(model: TimetableSettingsModel, rowId: String): String? = when (rowId) {
        SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_TITLE -> model.courseCardTitleColorLight
        SettingsActionDispatcher.ROW_CARD_TEXT_LIGHT_DETAIL -> model.courseCardDetailColorLight
        SettingsActionDispatcher.ROW_CARD_TEXT_DARK_TITLE -> model.courseCardTitleColorDark
        SettingsActionDispatcher.ROW_CARD_TEXT_DARK_DETAIL -> model.courseCardDetailColorDark
        else -> null
    }

    /**
     * 设置模型 → 页面状态。
     *
     * ## 三个**填不满**的字段（诚实清单）
     *
     * - `autoRefresh`：课程自动更新的档位/时刻/上次成功时间**不在** `timetable_settings`
     *   里（Dart 侧是独立的调度存储），本模型也没有。这里恒为 `null` ⇒ 通用页的
     *   「课表自动更新」整块不渲染（模型层 KDoc 写明 null = 尚未加载完，整块不渲染）。
     * - `themeHasModifications`：要拿当前设置与 `themeCheckpointConfig` 逐字段比对才算得出来，
     *   本刀不做 ⇒ 恒 `false`（主题管理页的「基于 X 已修改」徽标与两个按钮不出现；
     *   那两个按钮在渲染层本来也是空 onClick）。
     * - `savedThemes` 的 `selected`：Dart 判据是
     *   `themeCheckpointName == theme.name && !hasThemeModifications`
     *   （`theme_manage_sheets.dart:315-318`）；`hasThemeModifications` 恒 false，
     *   所以这里退化成「名字等于当前主题名」。
     */
    fun toSettingsPageState(model: TimetableSettingsModel): SettingsPageState {
        val defaults = SettingsPageState()
        return SettingsPageState(
            // ---- 通用 ----
            appLocaleTag = model.appLocaleTag,
            pageTransitionSpeed = model.pageTransitionSpeed,
            enableHaptics = model.enableHaptics,
            homePullQuickImportEnabled = model.homePullQuickImportEnabled,
            autoRefresh = null,
            // ---- 外观与主题 ----
            appThemeMode = pick(
                AppThemeMode.entries,
                { it.value },
                model.appThemeMode.value,
                defaults.appThemeMode,
            ),
            appFontMode = pick(
                AppFontMode.entries,
                { it.value },
                model.appFontMode.value,
                defaults.appFontMode,
            ),
            appFontWeight = model.appFontWeight,
            appTextScale = model.appTextScale,
            foruiTheme = pick(
                ForuiTheme.entries,
                { it.value },
                model.foruiTheme.value,
                defaults.foruiTheme,
            ),
            themeSeedColor = model.themeSeedColor,
            themeCheckpointName = model.themeCheckpointName,
            themeHasModifications = false,
            savedThemes = mapSavedThemes(model),
            // ---- 课程卡片 ----
            courseCardShowName = model.courseCardShowName,
            courseCardShowTeacher = model.courseCardShowTeacher,
            courseCardShowLocation = model.courseCardShowLocation,
            courseCardShowTime = model.courseCardShowTime,
            courseCardShowTimeLabels = model.courseCardShowTimeLabels,
            courseCardShowWeeks = model.courseCardShowWeeks,
            courseCardShowDescription = model.courseCardShowDescription,
            courseCardSurfaceStyle = pick(
                CourseCardSurfaceStyle.entries,
                { it.value },
                model.courseCardSurfaceStyle.value,
                defaults.courseCardSurfaceStyle,
            ),
            courseCardVerticalAlign = pick(
                CourseCardVerticalAlign.entries,
                { it.value },
                model.courseCardVerticalAlign.value,
                defaults.courseCardVerticalAlign,
            ),
            courseCardHorizontalAlign = pick(
                CourseCardHorizontalAlign.entries,
                { it.value },
                model.courseCardHorizontalAlign.value,
                defaults.courseCardHorizontalAlign,
            ),
            courseCardFontSize = model.courseCardFontSize,
            compactFontSize = model.compactFontSize,
            timetableUseUnifiedCardColor = model.timetableUseUnifiedCardColor,
            timetableUnifiedCardColor = model.timetableUnifiedCardColor,
            showConflictBadgeOnTimetable = model.showConflictBadgeOnTimetable,
            timetableConflictCourseOpacity = model.timetableConflictCourseOpacity,
            linkCourseCardColors = model.linkCourseCardColors,
            courseCardTitleColor = model.courseCardTitleColorLight,
            courseCardDetailColor = model.courseCardDetailColorLight,
            courseCardTitleColorDark = model.courseCardTitleColorDark,
            courseCardDetailColorDark = model.courseCardDetailColorDark,
        )
    }

    // ------------------------------------------------------------------ 内部

    private fun <T> pick(
        candidates: List<T>,
        value: (T) -> String,
        appValue: String,
        fallback: T,
    ): T = candidates.firstOrNull { value(it) == appValue } ?: fallback

    /**
     * 已存主题 → 页面行。
     *
     * 逐条宽容（Dart `SavedTheme.fromJson`：id/name 缺失的条目丢弃，不让一条坏数据炸整块），
     * 预览色取 `themeData` 的前 4 个（Dart `TimetableSettings.previewColors`，
     * `timetable_settings.dart:264-278`）。
     */
    private fun mapSavedThemes(model: TimetableSettingsModel): List<SavedThemeRow> =
        model.savedThemes.mapNotNull { raw ->
            val id = raw["id"] as? String ?: return@mapNotNull null
            val name = raw["name"] as? String ?: return@mapNotNull null
            SavedThemeRow(
                id = id,
                name = name,
                selected = model.themeCheckpointName == name,
                previewColors = previewColorsOf(raw),
            )
        }

    private fun previewColorsOf(raw: Map<String, Any?>): List<String> {
        val themeData = raw["themeData"] as? Map<*, *> ?: return emptyList()
        fun color(key: String): String? =
            (themeData[key] as? String)?.takeIf { it.isNotBlank() }
        return listOfNotNull(
            color("seedColor"),
            color("courseCardTitleColorLight"),
            color("courseCardDetailColorLight"),
            color("weekdayBarFontColorLight"),
            color("weekdayBarAccentColorLight"),
        ).take(4)
    }
}
