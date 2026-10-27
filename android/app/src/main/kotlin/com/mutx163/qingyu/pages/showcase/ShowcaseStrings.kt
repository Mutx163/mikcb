package com.mutx163.qingyu.pages.showcase

/**
 * 文本占位符替换封装。
 */
data class ShowcaseText(val key: String, val zh: String) {
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

/**
 * Miuix 展示册文案定义（对齐 Dart `lib/screens/miuix_showcase_screen.dart` 与 14 份子展示代码）。
 */
object ShowcaseStrings {

    // ── 主入口与搜索 ──
    val showcaseScreenTitle = ShowcaseText("showcaseScreenTitle", "Miuix 组件展示")
    val showcaseSearchHint = ShowcaseText("showcaseSearchHint", "搜索组件（如 Button、Switch）")
    val showcaseSearchHistoryTitle = ShowcaseText("showcaseSearchHistoryTitle", "搜索历史")
    val showcaseClearHistory = ShowcaseText("showcaseClearHistory", "清空历史")
    val showcaseSearchNoResults = ShowcaseText("showcaseSearchNoResults", "未找到相关组件")
    val showcaseCategoryCountLabel = ShowcaseText("showcaseCategoryCountLabel", "共 {count} 类组件演示")

    // ── 分类条目（13 类，严格对齐 Dart 侧 _allEntries） ──
    val catButtonsTitle = ShowcaseText("catButtonsTitle", "按钮 Button")
    val catButtonsSummary = ShowcaseText(
        "catButtonsSummary",
        "MiuixButton / MiuixTextButton / MiuixIconButton / MiuixFloatingActionButton"
    )
    val catButtonsSubtitle = ShowcaseText(
        "catButtonsSubtitle",
        "MiuixButton / TextButton / IconButton / FAB"
    )

    val catInputsTitle = ShowcaseText("catInputsTitle", "输入 Input")
    val catInputsSummary = ShowcaseText(
        "catInputsSummary",
        "MiuixTextField / MiuixSwitch / MiuixCheckbox / MiuixRadioButton / MiuixSlider"
    )
    val catInputsSubtitle = ShowcaseText(
        "catInputsSubtitle",
        "TextField / Switch / Checkbox / RadioButton / Slider"
    )

    val catMenusTitle = ShowcaseText("catMenusTitle", "菜单选择 Menus")
    val catMenusSummary = ShowcaseText(
        "catMenusSummary",
        "MiuixDropdownPreference / SpinnerPreference / CascadingMenu"
    )
    val catMenusSubtitle = ShowcaseText(
        "catMenusSubtitle",
        "Dropdown / Spinner / CascadingMenu"
    )

    val catDisplayTitle = ShowcaseText("catDisplayTitle", "显示 Display")
    val catDisplaySummary = ShowcaseText(
        "catDisplaySummary",
        "MiuixText / MiuixCard / MiuixBadge / MiuixDivider / MiuixSmallTitle / MiuixBasicComponent"
    )
    val catDisplaySubtitle = ShowcaseText(
        "catDisplaySubtitle",
        "Text / Card / Badge / Divider / SmallTitle / BasicComponent"
    )

    val catPreferencesTitle = ShowcaseText("catPreferencesTitle", "列表项 Item")
    val catPreferencesSummary = ShowcaseText(
        "catPreferencesSummary",
        "MiuixBasicComponent / Arrow / Switch / Checkbox / RadioButton / Slider Preference"
    )
    val catPreferencesSubtitle = ShowcaseText(
        "catPreferencesSubtitle",
        "BasicComponent / Arrow / Switch / Checkbox / RadioButton / Slider"
    )

    val catPickersTitle = ShowcaseText("catPickersTitle", "选择器 Pickers")
    val catPickersSummary = ShowcaseText(
        "catPickersSummary",
        "MiuixNumberPicker / MiuixColorPicker / MiuixColorPalette / MiuixDatePicker"
    )
    val catPickersSubtitle = ShowcaseText(
        "catPickersSubtitle",
        "NumberPicker / ColorPicker / ColorPalette"
    )

    val catFeedbackTitle = ShowcaseText("catFeedbackTitle", "反馈 Feedback")
    val catFeedbackSummary = ShowcaseText(
        "catFeedbackSummary",
        "MiuixSnackbar / MiuixTooltip / MiuixOverlayDialog / MiuixProgressIndicator"
    )
    val catFeedbackSubtitle = ShowcaseText(
        "catFeedbackSubtitle",
        "Snackbar / Tooltip / Progress / Dialog / Badge"
    )

    val catOverlaysTitle = ShowcaseText("catOverlaysTitle", "浮层 Overlays")
    val catOverlaysSummary = ShowcaseText(
        "catOverlaysSummary",
        "MiuixOverlayBottomSheet / MiuixFloatingToolbar"
    )
    val catOverlaysSubtitle = ShowcaseText(
        "catOverlaysSubtitle",
        "BottomSheet / DropdownMenu / FloatingToolbar"
    )

    val catNavigationTitle = ShowcaseText("catNavigationTitle", "导航 Navigation")
    val catNavigationSummary = ShowcaseText(
        "catNavigationSummary",
        "MiuixTabRow / MiuixTabRowWithContour / MiuixNavigationBar / MiuixBreadcrumbBar"
    )
    val catNavigationSubtitle = ShowcaseText(
        "catNavigationSubtitle",
        "TabRow / NavigationBar / NavigationRail / FloatingNavigationBar / BreadcrumbBar"
    )

    val catUtilityTitle = ShowcaseText("catUtilityTitle", "实用 Utility")
    val catUtilitySummary = ShowcaseText(
        "catUtilitySummary",
        "MiuixSearchBar / ScrollBar / PullToRefresh / Surface"
    )
    val catUtilitySubtitle = ShowcaseText(
        "catUtilitySubtitle",
        "SearchBar / ScrollBar / PullToRefresh / Surface"
    )

    val catThemingTitle = ShowcaseText("catThemingTitle", "主题 Theming")
    val catThemingSummary = ShowcaseText(
        "catThemingSummary",
        "动态取色 / 文本样式 / 配色角色 / 图标浏览"
    )
    val catThemingSubtitle = ShowcaseText(
        "catThemingSubtitle",
        "DynamicColor / TextStyles / Colors / Icons"
    )

    val catBlurTitle = ShowcaseText("catBlurTitle", "模糊 Blur")
    val catBlurSummary = ShowcaseText(
        "catBlurSummary",
        "MiuixTextureBlur / 液态玻璃（背景捕获 + 高斯模糊 + 颜色控制）"
    )
    val catBlurSubtitle = ShowcaseText(
        "catBlurSubtitle",
        "MiuixTextureBlur / 液态玻璃"
    )

    val catFoundationTitle = ShowcaseText("catFoundationTitle", "基础 Foundation")
    val catFoundationSummary = ShowcaseText(
        "catFoundationSummary",
        "MiuixSquircleBorder / MiuixScrollEndHaptic"
    )
    val catFoundationSubtitle = ShowcaseText(
        "catFoundationSubtitle",
        "Squircle / ScrollEndHaptic"
    )

    // ── 各组件展示细节文案 ──
    val btnPrimary = ShowcaseText("btnPrimary", "Primary")
    val btnSecondary = ShowcaseText("btnSecondary", "Secondary")
    val btnError = ShowcaseText("btnError", "Error")
    val btnDisabled = ShowcaseText("btnDisabled", "Disabled")
    val btnConfirm = ShowcaseText("btnConfirm", "确定")
    val btnCancel = ShowcaseText("btnCancel", "取消")
    val btnDisabledZh = ShowcaseText("btnDisabledZh", "禁用")

    val inputUsername = ShowcaseText("inputUsername", "用户名")
    val inputPassword = ShowcaseText("inputPassword", "密码")
    val inputWifi = ShowcaseText("inputWifi", "WLAN")
    val inputBluetooth = ShowcaseText("inputBluetooth", "蓝牙")
    val inputAirplane = ShowcaseText("inputAirplane", "飞行模式")
    val inputRememberPassword = ShowcaseText("inputRememberPassword", "记住密码")
    val inputAutoLogin = ShowcaseText("inputAutoLogin", "自动登录")
    val inputTriState = ShowcaseText("inputTriState", "全选")
    val inputOptionA = ShowcaseText("inputOptionA", "选项 A")
    val inputOptionB = ShowcaseText("inputOptionB", "选项 B")
    val inputOptionC = ShowcaseText("inputOptionC", "选项 C")
    val inputContinuousSlider = ShowcaseText("inputContinuousSlider", "连续滑块")
    val inputSteppedSlider = ShowcaseText("inputSteppedSlider", "步进滑块")

    val prefSecurity = ShowcaseText("prefSecurity", "账号与安全")
    val prefSecuritySummary = ShowcaseText("prefSecuritySummary", "密码、双重验证")
    val prefGeneral = ShowcaseText("prefGeneral", "通用设置")
    val prefStorage = ShowcaseText("prefStorage", "存储空间")
    val prefLocation = ShowcaseText("prefLocation", "位置信息")
    val prefThemeFollowSystem = ShowcaseText("prefThemeFollowSystem", "跟随系统")
    val prefThemeLight = ShowcaseText("prefThemeLight", "浅色")
    val prefThemeDark = ShowcaseText("prefThemeDark", "深色")
    val prefBrightness = ShowcaseText("prefBrightness", "屏幕亮度")
    val prefFontSize = ShowcaseText("prefFontSize", "字体大小")

    val pickerCurrentTime = ShowcaseText("pickerCurrentTime", "当前时间：{time}")
    val pickerCurrentDate = ShowcaseText("pickerCurrentDate", "当前日期：{date}")
    val pickerColorSpace = ShowcaseText("pickerColorSpace", "色彩空间：{space}")

    val feedbackDialogTitle = ShowcaseText("feedbackDialogTitle", "提示")
    val feedbackDialogMessage = ShowcaseText("feedbackDialogMessage", "这是一个基础对话框，展示简单的信息内容。")
    val feedbackConfirmTitle = ShowcaseText("feedbackConfirmTitle", "确认操作")
    val feedbackConfirmMessage = ShowcaseText("feedbackConfirmMessage", "确定要执行此项操作吗？")
    val feedbackKnown = ShowcaseText("feedbackKnown", "知道了")
    val feedbackSampleSnackbar = ShowcaseText("feedbackSampleSnackbar", "这是一条 Snackbar 提示消息")

    val overlaySheetTitle = ShowcaseText("overlaySheetTitle", "底部弹窗")
    val overlaySheetContent = ShowcaseText(
        "overlaySheetContent",
        "底部弹窗从屏幕底部滑入，顶部带拖拽手柄，可下拉关闭。内容区域可放置任意组件。"
    )
    val overlayActionSheetTitle = ShowcaseText("overlayActionSheetTitle", "选择操作")
    val overlayActionShare = ShowcaseText("overlayActionShare", "分享")
    val overlayActionEdit = ShowcaseText("overlayActionEdit", "编辑")
    val overlayActionDelete = ShowcaseText("overlayActionDelete", "删除")
    val overlayCounterLabel = ShowcaseText("overlayCounterLabel", "计数器：{count}")

    val navCurrentSelected = ShowcaseText("navCurrentSelected", "当前选中：{tab}")
    val navTabRecommend = ShowcaseText("navTabRecommend", "推荐")
    val navTabFollow = ShowcaseText("navTabFollow", "关注")
    val navTabHot = ShowcaseText("navTabHot", "热门")
    val navTabNearby = ShowcaseText("navTabNearby", "附近")

    val themeSeedColor = ShowcaseText("themeSeedColor", "种子色")
    val themeModeLabel = ShowcaseText("themeModeLabel", "深色模式")
    val themeStyleLabel = ShowcaseText("themeStyleLabel", "调色板风格：{style}")

    val blurRadiusLabel = ShowcaseText("blurRadiusLabel", "模糊半径：{radius}")
    val blurSaturationLabel = ShowcaseText("blurSaturationLabel", "饱和度：{saturation}")
    val foundationRadiusLabel = ShowcaseText("foundationRadiusLabel", "圆角：{radius}")
    val foundationHapticLabel = ShowcaseText("foundationHapticLabel", "触觉类型：{type}")

    val allTexts: List<ShowcaseText> by lazy {
        listOf(
            showcaseScreenTitle,
            showcaseSearchHint,
            showcaseSearchHistoryTitle,
            showcaseClearHistory,
            showcaseSearchNoResults,
            showcaseCategoryCountLabel,
            catButtonsTitle,
            catButtonsSummary,
            catButtonsSubtitle,
            catInputsTitle,
            catInputsSummary,
            catInputsSubtitle,
            catMenusTitle,
            catMenusSummary,
            catMenusSubtitle,
            catDisplayTitle,
            catDisplaySummary,
            catDisplaySubtitle,
            catPreferencesTitle,
            catPreferencesSummary,
            catPreferencesSubtitle,
            catPickersTitle,
            catPickersSummary,
            catPickersSubtitle,
            catFeedbackTitle,
            catFeedbackSummary,
            catFeedbackSubtitle,
            catOverlaysTitle,
            catOverlaysSummary,
            catOverlaysSubtitle,
            catNavigationTitle,
            catNavigationSummary,
            catNavigationSubtitle,
            catUtilityTitle,
            catUtilitySummary,
            catUtilitySubtitle,
            catThemingTitle,
            catThemingSummary,
            catThemingSubtitle,
            catBlurTitle,
            catBlurSummary,
            catBlurSubtitle,
            catFoundationTitle,
            catFoundationSummary,
            catFoundationSubtitle,
            btnPrimary,
            btnSecondary,
            btnError,
            btnDisabled,
            btnConfirm,
            btnCancel,
            btnDisabledZh,
            inputUsername,
            inputPassword,
            inputWifi,
            inputBluetooth,
            inputAirplane,
            inputRememberPassword,
            inputAutoLogin,
            inputTriState,
            inputOptionA,
            inputOptionB,
            inputOptionC,
            inputContinuousSlider,
            inputSteppedSlider,
            prefSecurity,
            prefSecuritySummary,
            prefGeneral,
            prefStorage,
            prefLocation,
            prefThemeFollowSystem,
            prefThemeLight,
            prefThemeDark,
            prefBrightness,
            prefFontSize,
            pickerCurrentTime,
            pickerCurrentDate,
            pickerColorSpace,
            feedbackDialogTitle,
            feedbackDialogMessage,
            feedbackConfirmTitle,
            feedbackConfirmMessage,
            feedbackKnown,
            feedbackSampleSnackbar,
            overlaySheetTitle,
            overlaySheetContent,
            overlayActionSheetTitle,
            overlayActionShare,
            overlayActionEdit,
            overlayActionDelete,
            overlayCounterLabel,
            navCurrentSelected,
            navTabRecommend,
            navTabFollow,
            navTabHot,
            navTabNearby,
            themeSeedColor,
            themeModeLabel,
            themeStyleLabel,
            blurRadiusLabel,
            blurSaturationLabel,
            foundationRadiusLabel,
            foundationHapticLabel
        )
    }
}
