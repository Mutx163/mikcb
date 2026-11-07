package com.mutx163.qingyu.pages.settings

/**
 * 「恢复默认」（`lib/screens/settings/settings_reset.dart`）结构模型。
 *
 * ## 这个 Dart 文件不产一页独立界面
 *
 * 它产一个「恢复默认」白卡（`SettingsResetTile`，:196-296），被**五张设置页**
 * 摆在页尾：课程卡片 / 课表页面 / 外观与配色 / 首页与导航 / 桌面小组件
 * （`grep SettingsResetTile` 可见五处调用）。所以本模型的正确交付物有两半：
 *
 * 1. [resetCard] —— 每张设置页取自己那一段（一个空档 + 一张卡），直接拼进自己的 nodes；
 * 2. [spec] —— 把五个作用域排成一页的**对照视图**，供文案对拍与人工核对
 *    （Flutter 侧没有这页，它是迁移期自用的检查组，见文件末尾说明）。
 *
 * ## 三条设计约束（测试逐条钉住）
 *
 * 1. **作用域字段两两不重叠**（:41-44）——在 A 页恢复默认不许动 B 页的东西；
 * 2. **逐字段显式列出**（:15-17）——不用反射、不整体替换，保证不会顺手把课程数据、
 *    时间模板、账号绑定一起清掉；
 * 3. **可空字段必须走 clear 标记**（:135-144 的事故记录）——`copyWith` 对可空字段
 *    是 `??` 语义，传 null 等于「不改」，直接写 `liquidGlassTuning: d.liquidGlassTuning`
 *    是**无效**的，「恢复默认」会留下用户那套参数。2026-09-21 修过一次，这里防它复发。
 *
 * ## 危险操作的呈现
 *
 * 行标 `destructive = true`，渲染层按 `QingyuFixedTokens.DESTRUCTIVE` 上色
 * （`SettingsPageRenderers.kt` 的 `titleColors`）；确认弹窗 `destructive: true`（:257）。
 */
object SettingsResetPage {

    const val ID = "settings-reset"

    /** 重置完成提示的 ARB 键（:294 `showAppLightTip(... settingsResetDoneMessage)`）。 */
    const val DONE_MESSAGE_KEY = "settingsResetDoneMessage"

    /**
     * 五张设置页各自取用的那一段（Dart `SettingsResetTile.build`，:205-220）。
     *
     * 两个节点：`reset.<scope>.gap`（自带 12dp 空档，:209）+ `reset.<scope>`（白卡）。
     */
    fun resetCard(scope: SettingsResetScope): List<SettingsNode> = listOf(
        SettingsGap("reset.${scope.arg}.gap"),
        SettingsGroup(
            id = "reset.${scope.arg}",
            children = listOf(
                settingsRow(
                    id = "reset.${scope.arg}.row",
                    component = MiuixRowComponent.ARROW,
                    title = SettingsStringsExt4.settingsResetDefaultsTitle,
                    // 只有外观与课表页在标题下加一句作用范围（:226-233）
                    subtitle = scope.scopeNotice,
                    destructive = true,
                    action = SettingsAction.RESET_SCOPE,
                    actionTarget = scope.arg,
                ),
            ),
        ),
    )

    /**
     * 五个作用域的对照视图（迁移期检查用）。
     *
     * 每张卡后跟一条窄档，写明这一作用域会重置哪些字段——那些字段名不是界面文案
     * （屏上不出现，来自 Dart 的 `copyWith` 调用），所以用 [] 的空键登记，
     * 文案对拍跳过它们；但人工核对时一眼能看出「外观到底动了什么」。
     */
    fun spec(state: SettingsPageState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()
        SettingsResetScope.entries.forEach { scope ->
            nodes += resetCard(scope)
        }
        // 确认弹窗的内容也一并登记（五个 scope 各一句正文，:237-247）
        nodes += SettingsGap("reset.gap.confirmDialog")
        nodes += SettingsInline(
            id = "reset.confirmDialog",
            kind = InlineKind.CONTROL_CARD,
            note = "二次确认弹窗（:249-296 showHyperosConfirmDialog，destructive: true）：" +
                "官方 OverlayDialog 由宿主接，标题/正文/按钮文案在这里登记，供对拍",
            labelKey = SettingsStringsExt4.settingsResetDefaultsConfirmTitle.key,
            label = SettingsStringsExt4.settingsResetDefaultsConfirmTitle.text,
            // 确认按钮复用「恢复默认设置」这句（:256 confirmLabel）
            valueKey = SettingsStringsExt4.settingsResetDefaultsTitle.key,
            value = SettingsStringsExt4.settingsResetDefaultsTitle.text,
            texts = listOf(
                // 取消（:255 cancelLabel）
                SettingsInlineText(
                    SettingsStringsExt4.cancelAction.key,
                    SettingsStringsExt4.cancelAction.text,
                ),
                // 确认（:256 confirmLabel）
                SettingsInlineText(
                    SettingsStringsExt4.settingsResetDefaultsTitle.key,
                    SettingsStringsExt4.settingsResetDefaultsTitle.text,
                ),
            ),
        )
        return SettingsPageSpec(
            id = ID,
            titleKey = SettingsStringsExt4.settingsResetDefaultsTitle.key,
            title = SettingsStringsExt4.settingsResetDefaultsTitle.text,
            nodes = nodes,
        )
    }
}

/**
 * 「恢复默认」的作用域（`settings_reset.dart:18-33` 的 `SettingsResetScope`）。
 *
 * [fields] 是 `copyWith` 里显式列出的字段名（逐字抄 Dart），[clearFlags] 是
 * 「可空字段清空」标记（Dart 的 `clearXxx: true`）。
 *
 * 这两个清单是**给人核对用的**，不是运行时数据：迁移验收靠它们证明「范围没漏、
 * 没串页」。顺序与 Dart 源里的书写顺序一致。
 */
enum class SettingsResetScope(
    val arg: String,
    val confirmBody: ArbText,
    val scopeNotice: ArbText?,
    val fields: List<String>,
    val clearFlags: List<String>,
) {
    /** 课程卡片页（:50-73）。 */
    COURSE_CARD(
        arg = "courseCard",
        confirmBody = SettingsStringsExt4.settingsResetConfirmBodyCourseCard,
        scopeNotice = null,
        fields = listOf(
            "courseCardShowName",
            "courseCardShowTeacher",
            "courseCardShowLocation",
            "courseCardShowTime",
            "courseCardShowTimeLabels",
            "courseCardShowWeeks",
            "courseCardShowDescription",
            "courseCardVerticalAlign",
            "courseCardHorizontalAlign",
            "courseCardFontSize",
            "compactFontSize",
            "timetableUseUnifiedCardColor",
            "timetableUnifiedCardColor",
            "showConflictBadgeOnTimetable",
            "timetableConflictCourseOpacity",
            "linkCourseCardColors",
            "courseCardTitleColorLight",
            "courseCardTitleColorDark",
            "courseCardDetailColorLight",
            "courseCardDetailColorDark",
        ),
        clearFlags = emptyList(),
    ),

    /**
     * 课表页面页（含壁纸与背景区域，:74-122）。
     *
     * 材质轴 2026-09-22 起**不在本页**（划给外观），两个僵尸开关也摘掉了
     * （:99-107 的注释）。壁纸指针必须真的清（:116-117 的 clear 标记），
     * 否则「恢复默认」后背景还在。
     */
    TIMETABLE_PAGE(
        arg = "timetablePage",
        confirmBody = SettingsStringsExt4.settingsResetConfirmBodyTimetablePage,
        scopeNotice = SettingsStringsExt4.settingsResetScopeNoticeTimetablePage,
        fields = listOf(
            "timetableAutoFitSectionHeight",
            "timetableHideWeekends",
            "timetableShowNonCurrentWeekCourses",
            "longPressEmptySlotToAddCourseEnabled",
            "weekGridShowExams",
            "weekGridShowSchedules",
            "screenshotSharePromptEnabled",
            "timetableSectionTimeDisplayMode",
            "timetableTimeColumnWidthMode",
            "sectionHeight",
            "timetableCourseCardGap",
            "timetableBackToCurrentWeekButtonStyle",
            "timetableFloatingBackToCurrentWeekButtonOpacity",
            "timetablePageBackgroundColor",
            "homePageBackdropFollowsWeekPager",
            "homePageWallpaperBlurSigma",
            "homePageBackgroundScope",
            "weekdayBarFontColorLight",
            "weekdayBarFontColorDark",
            "weekdayBarAccentColorLight",
            "weekdayBarAccentColorDark",
            "timeAxisFontColorLight",
            "timeAxisFontColorDark",
        ),
        clearFlags = listOf(
            "clearHomePageWallpaperPath",
            "clearHomePageBackgroundImagePath",
        ),
    ),

    /**
     * 外观与主题页（:128-157）。
     *
     * 材质 2026-09-22 从「课表页面」划过来：它已是设备级设置（所有课表共用一份），
     * 而控件一直在「外观编辑」页。三个 tuning 字段必须走 clear 标记（:135-144）。
     */
    APPEARANCE(
        arg = "appearance",
        confirmBody = SettingsStringsExt4.settingsResetConfirmBodyAppearance,
        scopeNotice = SettingsStringsExt4.settingsResetScopeNoticeAppearance,
        fields = listOf(
            "appThemeMode",
            "appFontMode",
            "appFontWeight",
            "appTextScale",
            "foruiTheme",
            "themeSeedColor",
            "courseCardGlassPreset",
            "frostedBlurEnabled",
            "liquidGlassPreset",
            "linkLiquidGlassTuning",
            "darkGlassBoostEnabled",
            "liquidGlassDockEnabled",
            "courseCardSurfaceStyle",
            "homeBandGlassMaterial",
            "homePageTimeColumnBlurEnabled",
        ),
        clearFlags = listOf(
            "clearLiquidGlassTuning",
            "clearLiquidGlassTuningDark",
            "clearCourseCardGlassTuning",
        ),
    ),

    /**
     * 首页与导航页（:162-174）。
     *
     * 菜单形态与菜单内容**刻意不纳入**（:169-174 的注释）：`copyWith` 会把空表过一遍
     * `HomeGridMenu.normalize`，把 `[]` 变成 `['settings']`，直接纳入会得到一张只有
     * 「课表设置」一格的菜单，而不是出厂那套八格。
     */
    HOME_NAVIGATION(
        arg = "homeNavigation",
        confirmBody = SettingsStringsExt4.settingsResetConfirmBodyHomeNavigation,
        scopeNotice = null,
        fields = listOf(
            "homeNavigationForm",
            "glassDockActions",
            "glassDockShowAddButton",
            "glassDockButtonEntryId",
            "homeTitleStyle",
        ),
        clearFlags = listOf(
            "clearGlassDockButtonIconName",
        ),
    ),

    /**
     * 桌面小组件页（:175-189）。
     *
     * 后四项（倒计时提前量/样式、高度、圆角）原先漏在范围外，:182-184 记录了那次修复：
     * 确认弹窗写着「显示项与外观恢复为默认值」，用户在同一个「恢复默认」里拨过的
     * 这四项却原地不动，等于按声明的范围少清了 4 个。
     */
    HOME_WIDGET(
        arg = "homeWidget",
        confirmBody = SettingsStringsExt4.settingsResetConfirmBodyHomeWidget,
        scopeNotice = null,
        fields = listOf(
            "widgetBackgroundStyle",
            "widgetCourseAccentMode",
            "widgetShowLocation",
            "widgetShowCountdown",
            "widgetHideCompletedCourses",
            "widgetShowTomorrowCourses",
            "widgetCountdownLeadMinutes",
            "widgetCountdownTextStyle",
            "widgetHeightAdjustment",
            "widgetCornerRadius",
        ),
        clearFlags = emptyList(),
    ),
    ;

    companion object {
        /**
         * 页面行的 `actionTarget`（`"courseCard"` / `"timetablePage"` / …）→ 作用域。
         *
         * 宿主的「弹确认框 → 确认后落盘」两段式都从这里反查，**不要在宿主里另写一套
         * `when`**：2026-11-01 修的缺陷就是那种写法只覆盖 3 个作用域，其余落到外观口径，
         * 导致课表页 / 桌面小组件的确认正文错配。
         *
         * @return 未知作用域返回 null（宿主据此留痕、不弹一个内容不对的确认框）。
         */
        fun fromArg(arg: String): SettingsResetScope? =
            entries.firstOrNull { it.arg == arg }
    }
}
