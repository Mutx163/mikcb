package com.mutx163.qingyu.pages.settings

/**
 * 设置族三页用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 `SettingsArbParityTest` 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成
 * `gen-l10n`，再同步这里——顺序反了会被测试拦下。
 *
 * 未纳入的文案有两类，都在别的文件、不属于本泳道声明的三个 Dart 源：
 * - 弹层/子页内容（`lib/widgets/theme_manage_sheets.dart` 的重命名/复制/删除等）；
 * - 别的页面的行（设置 hub、课表页面、天气…）。
 *
 * 命名与 ARB 键逐字一致（`generalSettingsTitle` 等），便于 `grep` 双向核对。
 */
object SettingsStrings {

    // ------------------------------------------------------------ 通用设置页

    val generalSettingsTitle = ArbText("generalSettingsTitle", "通用")
    val languageModeLabel = ArbText("languageModeLabel", "语言选择")
    val languageSectionSubtitle =
        ArbText("languageSectionSubtitle", "可跟随系统，或手动切换到已适配语言")
    val languageModeSystem = ArbText("languageModeSystem", "跟随系统")
    val pageTransitionSpeedTitle = ArbText("pageTransitionSpeedTitle", "页面转场速度")
    val layoutEnableHapticsTitle = ArbText("layoutEnableHapticsTitle", "启用应用内震动反馈")
    val layoutEnableHapticsSubtitle =
        ArbText("layoutEnableHapticsSubtitle", "关闭后页码切换不再震动")
    val homePullQuickImportTitle = ArbText("homePullQuickImportTitle", "首页下拉快捷导入")
    val homePullQuickImportSubtitle =
        ArbText("homePullQuickImportSubtitle", "在首页下拉时自动执行教务快捷导入")

    // 课表自动更新（`lib/widgets/course_auto_refresh_settings.dart`，渲染在通用页上）
    val courseAutoRefreshSectionTitle = ArbText("courseAutoRefreshSectionTitle", "课表自动更新")
    val courseAutoRefreshTitle = ArbText("courseAutoRefreshTitle", "自动更新课表")
    val courseAutoRefreshSubtitle = ArbText("courseAutoRefreshSubtitle", "到点自动抓一次教务课表")
    val courseAutoRefreshModeLabel = ArbText("courseAutoRefreshModeLabel", "更新时机")
    val courseAutoRefreshModeEveryLaunch =
        ArbText("courseAutoRefreshModeEveryLaunch", "每次打开时")
    val courseAutoRefreshModeInterval = ArbText("courseAutoRefreshModeInterval", "每隔几小时")
    val courseAutoRefreshModeDaily = ArbText("courseAutoRefreshModeDaily", "每天定时")
    val courseAutoRefreshIntervalTitle =
        ArbText("courseAutoRefreshIntervalTitle", "间隔小时数")
    val courseAutoRefreshDailyTimeTitle =
        ArbText("courseAutoRefreshDailyTimeTitle", "每天更新时刻")
    val courseAutoRefreshTryNowTitle = ArbText("courseAutoRefreshTryNowTitle", "立即试一次")
    val courseAutoRefreshTryNowSubtitle =
        ArbText("courseAutoRefreshTryNowSubtitle", "不等时间窗，马上跑一次")
    val courseAutoRefreshSummaryNever =
        ArbText("courseAutoRefreshSummaryNever", "还没成功更新过")
    val courseAutoRefreshSummaryLast = ArbText("courseAutoRefreshSummaryLast", "上次 {time}")
    val courseAutoRefreshSummaryNext = ArbText("courseAutoRefreshSummaryNext", "下次约 {time}")

    /**
     * 「立即试一次」在当前壳里跑不起来时的弹窗正文。
     *
     * 用 ARB 已有的 `aboutUnavailable`（"不可用"）而不是新造一句：新增 ARB 键会在
     * `copy_style_guard_test` 的「死键只减不增」上翻红——那个扫描器只看 `lib/` 与
     * `test/` 的 Dart 引用，Kotlin 侧用的键它看不见。等执行器接进来（见
     * `docs/plans/2026-10-29-compose-general-page-audit.md` §三），这里连弹窗都不需要了。
     */
    val aboutUnavailable = ArbText("aboutUnavailable", "不可用")

    /** 确认键（ARB `confirmAction`；设置域的弹层按钮共用这一条）。 */
    val confirmAction = ArbText("confirmAction", "确认")

    /**
     * 选色弹窗标题（ARB `textColorSelectColor`；Dart `_showColorPicker` 同一条）。
     * 课卡文字四行与课表页面设置六行共用的那个弹窗。
     */
    val textColorSelectColor = ArbText("textColorSelectColor", "选择颜色")

    // -------------------------------------------------------- 外观与配色页

    val appearanceTitle = ArbText("appearanceTitle", "外观与配色")
    val previewTitle = ArbText("previewTitle", "预览")
    val frostedSheetSectionTitle = ArbText("frostedSheetSectionTitle", "玻璃材质")
    val appearanceEditorTitle = ArbText("appearanceEditorTitle", "外观编辑")
    val appearanceThemeDisplaySectionTitle =
        ArbText("appearanceThemeDisplaySectionTitle", "主题与显示")
    val themeModeLabel = ArbText("themeModeLabel", "主题模式")
    val themeModeSystem = ArbText("themeModeSystem", "跟随系统")
    val themeModeLight = ArbText("themeModeLight", "浅色模式")
    val themeModeDark = ArbText("themeModeDark", "深色模式")
    val fontModeLabel = ArbText("fontModeLabel", "字体选择")
    val fontModeSystem = ArbText("fontModeSystem", "应用默认")
    val fontModeSansSerif = ArbText("fontModeSansSerif", "系统无衬线")
    val fontModeMiSans = ArbText("fontModeMiSans", "MiSans")
    val fontModeHarmonyOS = ArbText("fontModeHarmonyOS", "鸿蒙黑体")
    val fontModeOppoSans = ArbText("fontModeOppoSans", "OPPO Sans")
    val fontModePingFang = ArbText("fontModePingFang", "苹方")
    val fontModeNotoSans = ArbText("fontModeNotoSans", "Noto Sans")
    val fontModeSerif = ArbText("fontModeSerif", "衬线体")
    val fontModeSongti = ArbText("fontModeSongti", "宋体")
    val fontModeMonospace = ArbText("fontModeMonospace", "等宽体")
    val fontWeightLabel = ArbText("fontWeightLabel", "字重")
    val fontSizeLabel = ArbText("fontSizeLabel", "字号")
    val fontSizeDefault = ArbText("fontSizeDefault", "默认")
    val fontPreviewSample = ArbText("fontPreviewSample", "永 Aa Bb 0123 — 课表预览")
    val themeSeedSectionTitle = ArbText("themeSeedSectionTitle", "应用主题色")
    val themeManageTitle = ArbText("themeManageTitle", "主题管理")
    val themeManageSubtitle = ArbText("themeManageSubtitle", "导出、导入和切换主题")
    val themePreset = ArbText("themePreset", "预设主题")
    val themeSeedSectionSubtitle =
        ArbText("themeSeedSectionSubtitle", "影响顶部栏、强调色和全局主色调")
    val foruiThemeMiuix = ArbText("foruiThemeMiuix", "默认")
    val foruiThemeNeutral = ArbText("foruiThemeNeutral", "中性灰")
    val foruiThemeZinc = ArbText("foruiThemeZinc", "锌灰")
    val foruiThemeSlate = ArbText("foruiThemeSlate", "石板灰")
    val foruiThemeBlue = ArbText("foruiThemeBlue", "蓝")
    val foruiThemeGreen = ArbText("foruiThemeGreen", "绿")
    val foruiThemeOrange = ArbText("foruiThemeOrange", "橙")
    val foruiThemeRed = ArbText("foruiThemeRed", "红")
    val foruiThemeRose = ArbText("foruiThemeRose", "玫红")
    val foruiThemeViolet = ArbText("foruiThemeViolet", "紫")
    val foruiThemeYellow = ArbText("foruiThemeYellow", "黄")
    val settingsResetDefaultsTitle = ArbText("settingsResetDefaultsTitle", "恢复默认设置")
    val settingsResetScopeNoticeAppearance =
        ArbText("settingsResetScopeNoticeAppearance", "主题、字体与玻璃质感")

    // ------------------------------------------------------------ 主题管理页

    val themeCurrentTheme = ArbText("themeCurrentTheme", "当前主题")
    val themeBasedOnModified = ArbText("themeBasedOnModified", "基于 {baseName} 已修改")
    val themeResetToPreset = ArbText("themeResetToPreset", "重置")
    val themeSaveCurrent = ArbText("themeSaveCurrent", "保存当前主题")
    val themeExport = ArbText("themeExport", "导出主题")
    val themeImport = ArbText("themeImport", "导入主题")
    val themeSaved = ArbText("themeSaved", "我的主题")
    val themeMoreActions = ArbText("themeMoreActions", "更多操作")

    // 2026-10-29 补口（一轮审核 P0）：主题管理页四处死控件接活后，弹层与提示要用到的文案。
    // 键与值都**已在** `app_zh.arb` 里（`themeExportSuccess` / `themeImportSuccess` /
    // `themeImportFailed` / `themeApply` / `themeDelete` / `themeRename` / `themeDuplicate` /
    // `themeDuplicateCopyName` / `themeDeleteConfirmMessage` / `themeNameHint`），
    // 这里只是把 Kotlin 侧句柄补齐，**不动 ARB**。
    val themeExportSuccess = ArbText("themeExportSuccess", "主题已复制到剪贴板")
    val themeImportSuccess = ArbText("themeImportSuccess", "主题已导入")
    val themeImportFailed = ArbText("themeImportFailed", "剪贴板内容格式错误")
    val themeApply = ArbText("themeApply", "应用")
    val themeDelete = ArbText("themeDelete", "删除")
    // 删除**确认框**的标题（Dart `confirmDeleteTitle`「确认删除」，按钮才是「删除」）。
    // 键早已在六份 ARB 里（Dart 课程删除同款），这里只补 Kotlin 句柄，不动 ARB。
    val confirmDeleteTitle = ArbText("confirmDeleteTitle", "确认删除")
    val themeRename = ArbText("themeRename", "重命名")
    val themeDuplicate = ArbText("themeDuplicate", "复制")
    val themeDuplicateCopyName = ArbText("themeDuplicateCopyName", "{name} 副本")
    val themeDeleteConfirmMessage = ArbText("themeDeleteConfirmMessage", "确定删除主题 {name}？")
    val themeNameHint = ArbText("themeNameHint", "输入主题名称")
    val themeChanged = ArbText("themeChanged", "已切换到 {themeName}")
    val themeUndo = ArbText("themeUndo", "撤销")

    // 周视图缩略预览（`SettingsWeekPreview.kt`）的星期短名与空态。
    // 这三个字一组的短名 `app_zh.arb:1769-1775` 早就有了，只是 Kotlin 侧一直没有句柄
    // —— 渲染层就此自己写死了「一」..「日」（一轮审核 D3 缺陷），这里补齐。
    val weekdayShortMonday = ArbText("weekdayShortMonday", "一")
    val weekdayShortTuesday = ArbText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = ArbText("weekdayShortWednesday", "三")
    val weekdayShortThursday = ArbText("weekdayShortThursday", "四")
    val weekdayShortFriday = ArbText("weekdayShortFriday", "五")
    val weekdayShortSaturday = ArbText("weekdayShortSaturday", "六")
    val weekdayShortSunday = ArbText("weekdayShortSunday", "日")

    /**
     * 周视图缩略预览的空态（本页自绘的那块「本周没有排课」）。
     *
     * 复用 ARB 已有的 `dayViewEmptyTitle`（"暂无课程"）：**不新增 ARB 键**
     * （新键要六份同步 + `gen-l10n`，属 Lead 统一动作）。值逐字等于 ARB。
     */
    val weekPreviewEmpty = ArbText("dayViewEmptyTitle", "暂无课程")

    // ------------------------------------------------------------ 课程卡片页

    val courseCardSettingsTitle = ArbText("courseCardSettingsTitle", "课程卡片")
    val courseCardSectionFields = ArbText("courseCardSectionFields", "显示字段")
    val showCourseNameTitle = ArbText("showCourseNameTitle", "显示课程名")
    val layoutShowTeacherTitle = ArbText("layoutShowTeacherTitle", "显示教师")
    val layoutShowClassroomTitle = ArbText("layoutShowClassroomTitle", "显示教室")
    val layoutShowTimeTitle = ArbText("layoutShowTimeTitle", "显示时间")
    val layoutShowTimeLabelsTitle = ArbText("layoutShowTimeLabelsTitle", "显示上下课字样")
    val layoutShowWeeksTitle = ArbText("layoutShowWeeksTitle", "显示周数")
    val layoutShowDescriptionTitle = ArbText("layoutShowDescriptionTitle", "显示课程简介")
    val courseCardSectionLayout = ArbText("courseCardSectionLayout", "布局")
    val courseCardSurfaceStyleLabel = ArbText("courseCardSurfaceStyleLabel", "卡片外观")
    val courseCardSurfaceStyleSolid = ArbText("courseCardSurfaceStyleSolid", "实体卡片")
    val courseCardSurfaceStyleGaussian = ArbText("courseCardSurfaceStyleGaussian", "高斯模糊")
    val courseCardSurfaceStyleLiquidGlass =
        ArbText("courseCardSurfaceStyleLiquidGlass", "液态玻璃")
    val layoutVerticalAlignLabel = ArbText("layoutVerticalAlignLabel", "垂直排版")
    val courseCardVerticalAlignTop = ArbText("courseCardVerticalAlignTop", "顶部对齐")
    val courseCardVerticalAlignCenter = ArbText("courseCardVerticalAlignCenter", "垂直居中")
    val courseCardVerticalAlignBottom = ArbText("courseCardVerticalAlignBottom", "底部对齐")
    val courseCardVerticalAlignSpaceEvenly =
        ArbText("courseCardVerticalAlignSpaceEvenly", "上下均布")
    val layoutHorizontalAlignLabel = ArbText("layoutHorizontalAlignLabel", "水平排版")
    val courseCardHorizontalAlignLeft = ArbText("courseCardHorizontalAlignLeft", "居左")
    val courseCardHorizontalAlignCenter = ArbText("courseCardHorizontalAlignCenter", "居中")
    val courseCardHorizontalAlignRight = ArbText("courseCardHorizontalAlignRight", "居右")
    val layoutCourseCardFontSizeTitle =
        ArbText("layoutCourseCardFontSizeTitle", "课程卡片字号")
    val layoutCompactFontSizeTitle = ArbText("layoutCompactFontSizeTitle", "紧凑字号")
    val courseCardSectionColor = ArbText("courseCardSectionColor", "颜色")
    val unifiedCourseCardColorTitle =
        ArbText("unifiedCourseCardColorTitle", "统一课程卡片颜色")
    val unifiedCourseCardColorSubtitle =
        ArbText("unifiedCourseCardColorSubtitle", "关闭后继续使用每门课程自己的颜色")
    val courseRecolorTileTitle = ArbText("courseRecolorTileTitle", "课表重新配色")
    val courseRecolorTileSubtitle = ArbText("courseRecolorTileSubtitle", "不用重新导入，可随时换色")
    val courseRecolorSheetTitle = ArbText("courseRecolorSheetTitle", "课表重新配色")
    val courseRecolorSheetDescription = ArbText(
        "courseRecolorSheetDescription",
        "为全部课程生成一套配色。可随时撤销回上一套配色，或恢复初始颜色。",
    )
    val courseRecolorNewBatchButton = ArbText("courseRecolorNewBatchButton", "换一批颜色")
    val courseRecolorPrevious = ArbText("courseRecolorPrevious", "上一套")
    val courseRecolorNext = ArbText("courseRecolorNext", "下一套")
    val courseRecolorSchemePosition = ArbText("courseRecolorSchemePosition", "第 {index}/{total} 套")
    val courseRecolorNoCoursesToast = ArbText(
        "courseRecolorNoCoursesToast",
        "暂无课程，先导入或添加课程再换颜色",
    )
    val layoutShowConflictBadgeTitle =
        ArbText("layoutShowConflictBadgeTitle", "首页显示冲突小胶囊")
    val layoutConflictOpacityTitle = ArbText("layoutConflictOpacityTitle", "冲突课程透明度")

    // 文字颜色（`lib/widgets/timetable_text_color_settings.dart`，scope=courseCard）
    val appearanceTextColorsSectionTitle =
        ArbText("appearanceTextColorsSectionTitle", "文字颜色")
    val textColorIndependentDetail = ArbText("textColorIndependentDetail", "独立设置详情颜色")
    val textColorCourseCardTitle = ArbText("textColorCourseCardTitle", "课程卡片标题颜色")
    val textColorCourseCardDetail = ArbText("textColorCourseCardDetail", "课程卡片详情颜色")
}
