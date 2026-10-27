package com.mutx163.qingyu.pages.showcase

/**
 * Miuix 组件分类枚举（13 类，与 Dart 版 lib/screens/miuix_showcase_screen.dart 保持一致）。
 */
enum class ShowcaseCategoryId(val key: String) {
    BUTTONS("buttons"),
    INPUTS("inputs"),
    MENUS("menus"),
    DISPLAY("display"),
    PREFERENCES("preferences"),
    PICKERS("pickers"),
    FEEDBACK("feedback"),
    OVERLAYS("overlays"),
    NAVIGATION("navigation"),
    UTILITY("utility"),
    THEMING("theming"),
    BLUR("blur"),
    FOUNDATION("foundation")
}

/**
 * 单个组件展示目录条目模型。
 */
data class ShowcaseEntry(
    val id: String,
    val category: ShowcaseCategoryId,
    val title: String,
    val subtitle: String,
    val summary: String,
    val iconName: String,
    val keywords: List<String>
)

/**
 * 展示目录管理器：提供默认分类列表、全文搜索与历史记录管理。
 */
object MiuixShowcaseCatalog {

    const val MAX_HISTORY_ITEMS = 10

    val allEntries: List<ShowcaseEntry> = listOf(
        ShowcaseEntry(
            id = "buttons",
            category = ShowcaseCategoryId.BUTTONS,
            title = ShowcaseStrings.catButtonsTitle.zh,
            subtitle = ShowcaseStrings.catButtonsSubtitle.zh,
            summary = ShowcaseStrings.catButtonsSummary.zh,
            iconName = "create",
            keywords = listOf("按钮", "文字按钮", "图标按钮", "悬浮按钮", "FAB", "button", "text", "icon")
        ),
        ShowcaseEntry(
            id = "inputs",
            category = ShowcaseCategoryId.INPUTS,
            title = ShowcaseStrings.catInputsTitle.zh,
            subtitle = ShowcaseStrings.catInputsSubtitle.zh,
            summary = ShowcaseStrings.catInputsSummary.zh,
            iconName = "edit",
            keywords = listOf(
                "输入", "开关", "复选框", "单选框", "滑块", "文本框", "输入框",
                "switch", "checkbox", "radio", "slider", "textfield"
            )
        ),
        ShowcaseEntry(
            id = "menus",
            category = ShowcaseCategoryId.MENUS,
            title = ShowcaseStrings.catMenusTitle.zh,
            subtitle = ShowcaseStrings.catMenusSubtitle.zh,
            summary = ShowcaseStrings.catMenusSummary.zh,
            iconName = "listView",
            keywords = listOf("菜单", "下拉", "级联", "dropdown", "spinner", "cascading")
        ),
        ShowcaseEntry(
            id = "display",
            category = ShowcaseCategoryId.DISPLAY,
            title = ShowcaseStrings.catDisplayTitle.zh,
            subtitle = ShowcaseStrings.catDisplaySubtitle.zh,
            summary = ShowcaseStrings.catDisplaySummary.zh,
            iconName = "gridView",
            keywords = listOf("显示", "卡片", "徽章", "分割线", "标题", "card", "badge", "divider")
        ),
        ShowcaseEntry(
            id = "preferences",
            category = ShowcaseCategoryId.PREFERENCES,
            title = ShowcaseStrings.catPreferencesTitle.zh,
            subtitle = ShowcaseStrings.catPreferencesSubtitle.zh,
            summary = ShowcaseStrings.catPreferencesSummary.zh,
            iconName = "listView",
            keywords = listOf("列表", "列表项", "设置项", "偏好", "preference", "item", "箭头")
        ),
        ShowcaseEntry(
            id = "pickers",
            category = ShowcaseCategoryId.PICKERS,
            title = ShowcaseStrings.catPickersTitle.zh,
            subtitle = ShowcaseStrings.catPickersSubtitle.zh,
            summary = ShowcaseStrings.catPickersSummary.zh,
            iconName = "edit",
            keywords = listOf(
                "选择器", "数字选择", "颜色选择", "调色板", "日期选择", "日历",
                "number", "color", "palette", "date", "calendar"
            )
        ),
        ShowcaseEntry(
            id = "feedback",
            category = ShowcaseCategoryId.FEEDBACK,
            title = ShowcaseStrings.catFeedbackTitle.zh,
            subtitle = ShowcaseStrings.catFeedbackSubtitle.zh,
            summary = ShowcaseStrings.catFeedbackSummary.zh,
            iconName = "info",
            keywords = listOf("反馈", "提示", "弹窗", "对话框", "进度", "snackbar", "tooltip", "dialog", "progress")
        ),
        ShowcaseEntry(
            id = "overlays",
            category = ShowcaseCategoryId.OVERLAYS,
            title = ShowcaseStrings.catOverlaysTitle.zh,
            subtitle = ShowcaseStrings.catOverlaysSubtitle.zh,
            summary = ShowcaseStrings.catOverlaysSummary.zh,
            iconName = "info",
            keywords = listOf("浮层", "底部弹窗", "工具栏", "bottomsheet", "toolbar")
        ),
        ShowcaseEntry(
            id = "navigation",
            category = ShowcaseCategoryId.NAVIGATION,
            title = ShowcaseStrings.catNavigationTitle.zh,
            subtitle = ShowcaseStrings.catNavigationSubtitle.zh,
            summary = ShowcaseStrings.catNavigationSummary.zh,
            iconName = "sidebar",
            keywords = listOf("导航", "标签", "底部导航", "面包屑", "tab", "breadcrumb")
        ),
        ShowcaseEntry(
            id = "utility",
            category = ShowcaseCategoryId.UTILITY,
            title = ShowcaseStrings.catUtilityTitle.zh,
            subtitle = ShowcaseStrings.catUtilitySubtitle.zh,
            summary = ShowcaseStrings.catUtilitySummary.zh,
            iconName = "search",
            keywords = listOf("实用", "搜索", "滚动", "下拉刷新", "表面", "search", "scroll", "refresh", "surface")
        ),
        ShowcaseEntry(
            id = "theming",
            category = ShowcaseCategoryId.THEMING,
            title = ShowcaseStrings.catThemingTitle.zh,
            subtitle = ShowcaseStrings.catThemingSubtitle.zh,
            summary = ShowcaseStrings.catThemingSummary.zh,
            iconName = "create",
            keywords = listOf("主题", "动态取色", "文本样式", "配色", "图标", "theme", "color", "style")
        ),
        ShowcaseEntry(
            id = "blur",
            category = ShowcaseCategoryId.BLUR,
            title = ShowcaseStrings.catBlurTitle.zh,
            subtitle = ShowcaseStrings.catBlurSubtitle.zh,
            summary = ShowcaseStrings.catBlurSummary.zh,
            iconName = "image",
            keywords = listOf("模糊", "液态玻璃", "高斯模糊", "毛玻璃", "glass", "gaussian", "texture")
        ),
        ShowcaseEntry(
            id = "foundation",
            category = ShowcaseCategoryId.FOUNDATION,
            title = ShowcaseStrings.catFoundationTitle.zh,
            subtitle = ShowcaseStrings.catFoundationSubtitle.zh,
            summary = ShowcaseStrings.catFoundationSummary.zh,
            iconName = "gridView",
            keywords = listOf("基础", "圆角", "触感", "squircle", "haptic", "border")
        )
    )

    /**
     * 根据关键字检索条目。
     */
    fun filterEntries(query: String): List<ShowcaseEntry> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return allEntries
        return allEntries.filter { entry ->
            entry.title.lowercase().contains(q) ||
                entry.summary.lowercase().contains(q) ||
                entry.subtitle.lowercase().contains(q) ||
                entry.keywords.any { it.lowercase().contains(q) }
        }
    }

    fun findEntryById(id: String): ShowcaseEntry? {
        return allEntries.firstOrNull { it.id.equals(id, ignoreCase = true) }
    }

    fun findEntryByCategory(category: ShowcaseCategoryId): ShowcaseEntry {
        return allEntries.first { it.category == category }
    }

    /**
     * 搜索历史管理：去重、最近在前、上限 MAX_HISTORY_ITEMS。
     */
    fun addSearchHistory(history: List<String>, rawQuery: String): List<String> {
        val q = rawQuery.trim()
        if (q.isEmpty()) return history
        val mutable = history.toMutableList()
        mutable.remove(q)
        mutable.add(0, q)
        return if (mutable.size > MAX_HISTORY_ITEMS) {
            mutable.subList(0, MAX_HISTORY_ITEMS)
        } else {
            mutable
        }
    }

    fun removeSearchHistoryItem(history: List<String>, item: String): List<String> {
        return history.filterNot { it == item }
    }
}

/**
 * 展示册各交互控件纯逻辑状态机。
 */
data class ShowcaseInteractionState(
    // 按钮态
    val buttonClickCount: Int = 0,
    val lastClickedButton: String = "",

    // 输入态
    val wifiEnabled: Boolean = true,
    val bluetoothEnabled: Boolean = false,
    val airplaneMode: Boolean = false,
    val rememberPassword: Boolean = true,
    val autoLogin: Boolean = false,
    val triState: Boolean? = false,
    val selectedRadioOption: Int = 0,
    val continuousSliderValue: Float = 0.4f,
    val steppedSliderValue: Int = 2,
    val rangeStart: Float = 0.2f,
    val rangeEnd: Float = 0.7f,
    val verticalSliderValue: Float = 0.6f,
    val usernameInput: String = "miuix",

    // Preference 列表项态
    val locationEnabled: Boolean = true,
    val themeModeIndex: Int = 0,
    val brightness: Float = 0.7f,
    val fontSize: Float = 0.5f,

    // 菜单态
    val dropdownSelectedIndex: Int = 0,
    val spinnerSelectedIndex: Int = 0,

    // 选择器态
    val pickerHour: Int = 8,
    val pickerMinute: Int = 30,
    val pickerColorSpaceIndex: Int = 0,
    val pickerYear: Int = 2026,
    val pickerMonth: Int = 7,
    val pickerDay: Int = 26,

    // 反馈态
    val isBasicDialogOpen: Boolean = false,
    val isConfirmDialogOpen: Boolean = false,
    val snackbarMessage: String? = null,
    val progress: Float = 0f,
    val isProgressPlaying: Boolean = false,

    // 浮层态
    val isBottomSheetOpen: Boolean = false,
    val isActionSheetOpen: Boolean = false,
    val counter: Int = 0,

    // 导航态
    val selectedTabRowIndex: Int = 0,
    val selectedContourTabIndex: Int = 0,
    val selectedNavDestinationIndex: Int = 0,

    // 主题游乐场态
    val selectedSeedColorHex: Long = 0xFF3482FF,
    val themePaletteStyleIndex: Int = 0,
    val isDarkTheme: Boolean = false,

    // 模糊与圆角触感态
    val blurRadius: Float = 20f,
    val blurSaturation: Float = 1.5f,
    val squircleRadius: Float = 24f,
    val hapticTypeIndex: Int = 0
) {

    // ── 纯函数状态转移 ──

    fun onButtonClick(name: String): ShowcaseInteractionState =
        copy(buttonClickCount = buttonClickCount + 1, lastClickedButton = name)

    fun toggleWifi(): ShowcaseInteractionState =
        copy(wifiEnabled = !wifiEnabled)

    fun toggleBluetooth(): ShowcaseInteractionState =
        copy(bluetoothEnabled = !bluetoothEnabled)

    fun toggleAirplaneMode(): ShowcaseInteractionState =
        copy(airplaneMode = !airplaneMode)

    fun toggleRememberPassword(): ShowcaseInteractionState =
        copy(rememberPassword = !rememberPassword)

    fun cycleTriState(): ShowcaseInteractionState {
        val next = when (triState) {
            false -> true
            true -> null
            null -> false
        }
        return copy(triState = next)
    }

    fun setRadioOption(option: Int): ShowcaseInteractionState =
        copy(selectedRadioOption = option.coerceIn(0, 2))

    fun setContinuousSlider(value: Float): ShowcaseInteractionState =
        copy(continuousSliderValue = value.coerceIn(0f, 1f))

    fun setSteppedSlider(value: Int): ShowcaseInteractionState =
        copy(steppedSliderValue = value.coerceIn(0, 10))

    fun setRange(start: Float, end: Float): ShowcaseInteractionState {
        val coercedStart = start.coerceIn(0f, 1f)
        val coercedEnd = end.coerceIn(coercedStart, 1f)
        return copy(rangeStart = coercedStart, rangeEnd = coercedEnd)
    }

    fun setUsername(text: String): ShowcaseInteractionState =
        copy(usernameInput = text)

    fun toggleLocation(): ShowcaseInteractionState =
        copy(locationEnabled = !locationEnabled)

    fun setThemeModeIndex(index: Int): ShowcaseInteractionState =
        copy(themeModeIndex = index.coerceIn(0, 2))

    fun setBrightness(value: Float): ShowcaseInteractionState =
        copy(brightness = value.coerceIn(0f, 1f))

    fun setFontSize(value: Float): ShowcaseInteractionState =
        copy(fontSize = value.coerceIn(0f, 1f))

    fun setDropdownIndex(index: Int): ShowcaseInteractionState =
        copy(dropdownSelectedIndex = index)

    fun setSpinnerIndex(index: Int): ShowcaseInteractionState =
        copy(spinnerSelectedIndex = index)

    fun setTime(hour: Int, minute: Int): ShowcaseInteractionState =
        copy(
            pickerHour = hour.coerceIn(0, 23),
            pickerMinute = minute.coerceIn(0, 59)
        )

    fun adjustHour(delta: Int): ShowcaseInteractionState {
        val raw = (pickerHour + delta) % 24
        val wrapped = if (raw < 0) raw + 24 else raw
        return copy(pickerHour = wrapped)
    }

    fun adjustMinute(delta: Int): ShowcaseInteractionState {
        val raw = (pickerMinute + delta) % 60
        val wrapped = if (raw < 0) raw + 60 else raw
        return copy(pickerMinute = wrapped)
    }

    fun setColorSpaceIndex(index: Int): ShowcaseInteractionState =
        copy(pickerColorSpaceIndex = index.coerceIn(0, 3))

    fun setDate(year: Int, month: Int, day: Int): ShowcaseInteractionState =
        copy(
            pickerYear = year.coerceIn(1970, 2100),
            pickerMonth = month.coerceIn(1, 12),
            pickerDay = day.coerceIn(1, 31)
        )

    fun showBasicDialog(show: Boolean): ShowcaseInteractionState =
        copy(isBasicDialogOpen = show)

    fun showConfirmDialog(show: Boolean): ShowcaseInteractionState =
        copy(isConfirmDialogOpen = show)

    fun showSnackbar(message: String?): ShowcaseInteractionState =
        copy(snackbarMessage = message)

    fun stepProgress(delta: Float): ShowcaseInteractionState {
        val next = (progress + delta).coerceIn(0f, 1f)
        return copy(progress = next, isProgressPlaying = next < 1f)
    }

    fun resetProgress(): ShowcaseInteractionState =
        copy(progress = 0f, isProgressPlaying = false)

    fun showBottomSheet(show: Boolean): ShowcaseInteractionState =
        copy(isBottomSheetOpen = show)

    fun showActionSheet(show: Boolean): ShowcaseInteractionState =
        copy(isActionSheetOpen = show)

    fun incrementCounter(): ShowcaseInteractionState =
        copy(counter = counter + 1)

    fun decrementCounter(): ShowcaseInteractionState =
        copy(counter = counter - 1)

    fun setTabRowIndex(index: Int): ShowcaseInteractionState =
        copy(selectedTabRowIndex = index.coerceAtLeast(0))

    fun setContourTabIndex(index: Int): ShowcaseInteractionState =
        copy(selectedContourTabIndex = index.coerceAtLeast(0))

    fun setNavDestinationIndex(index: Int): ShowcaseInteractionState =
        copy(selectedNavDestinationIndex = index.coerceAtLeast(0))

    fun setSeedColor(colorHex: Long): ShowcaseInteractionState =
        copy(selectedSeedColorHex = colorHex)

    fun setPaletteStyle(index: Int): ShowcaseInteractionState =
        copy(themePaletteStyleIndex = index.coerceIn(0, 3))

    fun toggleDarkTheme(): ShowcaseInteractionState =
        copy(isDarkTheme = !isDarkTheme)

    fun setBlurRadius(radius: Float): ShowcaseInteractionState =
        copy(blurRadius = radius.coerceIn(0f, 100f))

    fun setBlurSaturation(saturation: Float): ShowcaseInteractionState =
        copy(blurSaturation = saturation.coerceIn(0f, 5f))

    fun setSquircleRadius(radius: Float): ShowcaseInteractionState =
        copy(squircleRadius = radius.coerceIn(0f, 64f))

    fun setHapticTypeIndex(index: Int): ShowcaseInteractionState =
        copy(hapticTypeIndex = index.coerceIn(0, 3))
}
