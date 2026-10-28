package com.mutx163.qingyu.pages.settings

/**
 * 「课表页面设置」页用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * ## 这一份为什么存在（2026-10-28 补口）
 *
 * 台账原记 P3-B「20 页全迁」，实际漏了 `lib/screens/settings/settings_timetable_page.dart`
 * ——入口行 `timetable.pageSettings`（`SettingsTimetablePage.kt:148`）一直指着一个
 * **没有落点**的路由 `/settings/timetable-page`。由 `l4-recon` 逐页核对发现、Lead 复验属实。
 * 本文件是该页文案的唯一落点。
 *
 * ## 逐字抄录，不许改写
 *
 * 每一条都在 [SettingsStringsExt5ParityTest] 里与 ARB 机械比对。要改界面文字，
 * 先改 ARB（六份同步）+ 重新生成 `gen-l10n`，再同步这里——顺序反了会被测试拦下。
 *
 * ## 与共享件的重复键
 *
 * `timetablePageSettingsTitle`（[SettingsStringsExt2]）、
 * `homePageWallpaperTitle` / `homePageWallpaperRecentTitle` /
 * `homePageBackdropFollowsWeekPagerTitle` / `homePageBackdropFollowsWeekPagerSubtitle` /
 * `homePageWallpaperBlurTitle`（[SettingsStringsExt1]）、
 * `frostedSheetSectionTitle` / `appearanceEditorTitle` / `settingsResetDefaultsTitle`
 * （[SettingsStrings]）都已在别处定义，本文件**不再重复**，直接引用那边
 * （同一个 ARB 键只能有一处真源）。
 *
 * 命名与 ARB 键逐字一致，便于 `grep` 双向核对。
 */
object SettingsStringsExt5 {

    // ------------------------------------------------------------ 密度区（`settings_timetable_page.dart:167-291`）

    /** `HyperosSectionLabel(密度)`（:167）。 */
    val timetablePageSectionDensity = ArbText("timetablePageSectionDensity", "密度")

    val layoutAutoFitHeightTitle = ArbText("layoutAutoFitHeightTitle", "自动充满屏幕高度")
    val layoutHideWeekendsTitle = ArbText("layoutHideWeekendsTitle", "隐藏周六周日")

    val layoutShowOtherWeeksTitle = ArbText("layoutShowOtherWeeksTitle", "显示非本周课程")
    val layoutShowOtherWeeksSubtitle =
        ArbText("layoutShowOtherWeeksSubtitle", "非本周课程以半透明灰色显示")

    val longPressEmptySlotToAddTitle =
        ArbText("longPressEmptySlotToAddTitle", "长按空白格添加课程")
    val longPressEmptySlotToAddSubtitle =
        ArbText("longPressEmptySlotToAddSubtitle", "长按后点虚线加号即可添加")

    val weekGridShowExamsTitle = ArbText("weekGridShowExamsTitle", "周视图显示考试")
    val weekGridShowExamsSubtitle =
        ArbText("weekGridShowExamsSubtitle", "长按加课会跳过考试时段")

    val weekGridShowSchedulesTitle = ArbText("weekGridShowSchedulesTitle", "周视图显示日程")
    val weekGridShowSchedulesSubtitle =
        ArbText("weekGridShowSchedulesSubtitle", "按时间落位，跨天占整列")

    val settingsScreenshotShareTitle =
        ArbText("settingsScreenshotShareTitle", "截屏后提示分享课表")
    val settingsScreenshotShareSubtitle =
        ArbText("settingsScreenshotShareSubtitle", "只弹提示，点了才生成图片")

    val layoutTimeColumnDisplayLabel = ArbText("layoutTimeColumnDisplayLabel", "首页时间列显示")
    val sectionTimeDisplayHidden = ArbText("sectionTimeDisplayHidden", "不显示")
    val sectionTimeDisplayStartOnly = ArbText("sectionTimeDisplayStartOnly", "仅显示上课时间")
    val sectionTimeDisplayStartAndEnd =
        ArbText("sectionTimeDisplayStartAndEnd", "显示上下课时间")

    val layoutTimeColumnWidthLabel = ArbText("layoutTimeColumnWidthLabel", "时间栏宽度")
    val timetableTimeColumnWidthNarrow = ArbText("timetableTimeColumnWidthNarrow", "窄")
    val timetableTimeColumnWidthWide = ArbText("timetableTimeColumnWidthWide", "宽")

    val layoutSectionHeightTitle = ArbText("layoutSectionHeightTitle", "课表行高")
    val layoutCourseCardGapTitle = ArbText("layoutCourseCardGapTitle", "课程卡片间距")

    // ------------------------------------------------------------ 回到当前周（:294-320）

    val timetablePageSectionBackToWeek =
        ArbText("timetablePageSectionBackToWeek", "回到当前周")
    val layoutBackToCurrentWeekButtonOpacityTitle =
        ArbText("layoutBackToCurrentWeekButtonOpacityTitle", "悬浮按钮不透明度")

    // ------------------------------------------------------------ 背景区（:323-388）

    val timetablePageSectionBackground = ArbText("timetablePageSectionBackground", "背景")
    val timetableBackgroundColorSectionTitle =
        ArbText("timetableBackgroundColorSectionTitle", "课表背景色")

    // ------------------------------------------------------------ 玻璃材质入口（:414-445）

    val appearanceEditorEntrySubtitle =
        ArbText("appearanceEditorEntrySubtitle", "整页微缩预览，改壁纸与材质")

    // ------------------------------------------------------------ 文字颜色（`widgets/timetable_text_color_settings.dart:243-265`，scope=page）

    val textColorWeekdayBar = ArbText("textColorWeekdayBar", "星期栏字体颜色")
    val textColorWeekdayBarAccent = ArbText("textColorWeekdayBarAccent", "星期栏强调色")
    val textColorTimeAxis = ArbText("textColorTimeAxis", "时间轴字体颜色")

    /**
     * 本文件定义的**全部**文案（含被别处复用后搬来的？不含——只列本文件自己声明的）。
     *
     * 对拍测试遍历它，所以「声明了却忘了加进列表」= 漏网。加一条文案必须同时加进这里。
     */
    val allTexts: List<ArbText> = listOf(
        timetablePageSectionDensity,
        layoutAutoFitHeightTitle,
        layoutHideWeekendsTitle,
        layoutShowOtherWeeksTitle,
        layoutShowOtherWeeksSubtitle,
        longPressEmptySlotToAddTitle,
        longPressEmptySlotToAddSubtitle,
        weekGridShowExamsTitle,
        weekGridShowExamsSubtitle,
        weekGridShowSchedulesTitle,
        weekGridShowSchedulesSubtitle,
        settingsScreenshotShareTitle,
        settingsScreenshotShareSubtitle,
        layoutTimeColumnDisplayLabel,
        sectionTimeDisplayHidden,
        sectionTimeDisplayStartOnly,
        sectionTimeDisplayStartAndEnd,
        layoutTimeColumnWidthLabel,
        timetableTimeColumnWidthNarrow,
        timetableTimeColumnWidthWide,
        layoutSectionHeightTitle,
        layoutCourseCardGapTitle,
        timetablePageSectionBackToWeek,
        layoutBackToCurrentWeekButtonOpacityTitle,
        timetablePageSectionBackground,
        timetableBackgroundColorSectionTitle,
        appearanceEditorEntrySubtitle,
        textColorWeekdayBar,
        textColorWeekdayBarAccent,
        textColorTimeAxis,
    )
}
