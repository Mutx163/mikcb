package com.mutx163.qingyu.pages.live

/**
 * 「超级岛 · 显示设置页」状态模型（纯 Kotlin，零 Android / Compose 依赖）。
 *
 * 对照 Flutter 原版：
 * - `lib/models/settings/timetable_settings_live.dart` 的 `LiveDisplaySettings`
 *   （22 字段，`copyWith` / `parseLiveExpandedDetailFields` 语义）；
 * - `lib/models/timetable_settings.dart` 里本页也要编辑的关联 live* 顶层字段；
 * - `lib/screens/live_settings_subpages.dart` 的 `LiveDisplaySettingsScreen`；
 * - `lib/widgets/live_island_preview.dart` 的摘要胶囊 / 展开卡片；
 * - `lib/utils/live_expanded_detail_fields.dart` 的阶段可见字段与工作顺序。
 *
 * 本文件只放数据与纯逻辑：默认值、展开字段顺序、倒计时 12 分支格式化、
 * 预览文案拼装。渲染层（`composeP1/.../LiveIslandPreview.kt`）只负责把这里的
 * 输出画出来，所有期望值都能在 JVM 单测里手推验证。
 */

// ───────────────────────────── 枚举 ─────────────────────────────

/**
 * 倒计时文字样式（Dart `LiveCountdownTextStyle`，12 个分支）。
 *
 * 顺序与 Dart 枚举逐项一致，`DisplaySettingsStrings.countdownTextStyleLabel`
 * 依赖它做下拉映射；**不要重排**，否则下拉顺序会与 Flutter 原版错位。
 */
enum class LiveCountdownTextStyle {
    /** 智能 中文：超过阈值显示秒，≤阈值显示秒，>120 分显示分钟，60~120 向上取整分钟。 */
    SMART,

    /** 智能 英文：同上，但分钟/秒后缀用 `min` / `s`。 */
    SMART_MIN_S,

    /** 分秒 5分19秒。 */
    MINUTE_SECOND_CN,

    /** 分秒 05:19。 */
    MINUTE_SECOND_COLON,

    /** 英文 5min19s。 */
    MINUTE_SECOND_MIN_S,

    /** 英文 5min/19s。 */
    MINUTE_SECOND_MIN_SLASH_S,

    /** 纯分钟 5分钟。 */
    MINUTE_ONLY_CN,

    /** 纯分钟 5min。 */
    MINUTE_ONLY_MIN,

    /** 纯分钟 5/min。 */
    MINUTE_ONLY_SLASH,

    /** 纯秒 5秒。 */
    SECOND_ONLY_CN,

    /** 纯秒 5s。 */
    SECOND_ONLY_SHORT,

    /** 纯秒 5/s。 */
    SECOND_ONLY_SLASH,
}

/** 小米岛左侧图标样式（Dart `MiuiIslandLabelStyle`）。 */
enum class MiuiIslandLabelStyle { TEXT_ONLY, ICON_AND_TEXT }

/** 小米岛左侧文字内容（Dart `MiuiIslandLabelContent`）。 */
enum class MiuiIslandLabelContent { COURSE_NAME, LOCATION, COURSE_NAME_AND_LOCATION }

/** 小米岛左侧文字字重（Dart `MiuiIslandLabelFontWeight`）。 */
enum class MiuiIslandLabelFontWeight { REGULAR, MEDIUM, BOLD }

/** 小米岛左侧文字渲染清晰度（Dart `MiuiIslandLabelRenderQuality`）。 */
enum class MiuiIslandLabelRenderQuality { STANDARD, HIGH, ULTRA }

/** 展开态大图标模式（Dart `MiuiIslandExpandedIconMode`）。 */
enum class MiuiIslandExpandedIconMode { APP_ICON, CUSTOM_IMAGE, HIDDEN }

/** 课中时间显示模式（Dart `LiveDuringClassTimeDisplayMode`；`nearest`/`total` 与磁盘字符串一致）。 */
enum class LiveDuringClassTimeDisplayMode(val value: String) {
    NEAREST("nearest"),
    TOTAL("total");

    companion object {
        /** 未知值回落 `NEAREST`（与 Dart 默认值一致，不猜成 total）。 */
        fun fromValue(raw: String?): LiveDuringClassTimeDisplayMode =
            entries.firstOrNull { it.value == raw } ?: NEAREST
    }
}

/**
 * 上课前通知里能一键执行的系统静音动作（Dart `LiveBeforeClassQuickAction`）。
 *
 * `PRIORITY_ONLY` 是「仅允许优先通知」档，比完全勿扰温和；`requiresDoNotDisturbAccess`
 * 见 [LiveDisplayLogic.requiresDoNotDisturbAccess]。
 */
enum class LiveBeforeClassQuickAction { NONE, SILENT, DO_NOT_DISTURB, PRIORITY_ONLY, BOTH }

/**
 * 展开态详情里可逐字段控制显示与顺序的字段（Dart `LiveExpandedDetailField`）。
 *
 * [wireValue] 与原生 `LiveUpdateService` 构造展开文本用到的 key 一一对应，
 * 也是存储 JSON 里的字符串值，**不可改动**。
 */
enum class LiveExpandedDetailField(val wireValue: String) {
    STAGE("stage"),
    SHORT_NAME("shortName"),
    PROGRESS("progress"),
    STATUS("status"),
    TIME("time"),
    LOCATION("location"),
    TEACHER("teacher"),
    NEXT_COURSE("next"),
    NOTE("note"),
}

/** 预览卡片的阶段（Dart 私有 `_PreviewStage`，此处公开给渲染层复用）。 */
enum class LivePreviewStage { BEFORE_CLASS, DURING_CLASS, BEFORE_END }

/**
 * 预览时真实课堂所处的时刻（由 [LiveCurrentCourseSource] 解析）。
 *
 * 渲染层据此决定展示哪些阶段：上课中 → 上课中 + 下课提醒；课间 → 即将上课；
 * 无课 → 不画岛卡，交给页面画诚实空态。
 */
enum class LivePreviewMoment { IN_CLASS, BETWEEN_CLASSES, NO_COURSE }

// ───────────────────────────── 状态 ─────────────────────────────

/**
 * 显示设置页的可编辑状态。
 *
 * 前 22 个字段与 Flutter `LiveDisplaySettings` **逐字段一一对应**（默认值取自
 * `TimetableSettings` 构造函数，见 Dart `:825-888`）。末尾 5 个是页面级关联字段，
 * 来自 `TimetableSettings` 的顶层 live* 属性——本页也要编辑它们（上课前快捷操作、
 * 课中/下课页「跟随课前设置」、秒级阈值、提升通知），为让壳层用**单一状态**
 * 驱动整个页面，这里把它们并进同一 data class。
 *
 * 字段语义全部照 Dart 注释，不自行改判据。
 */
data class LiveDisplayState(
    // ── 1. LiveDisplaySettings 的 22 字段 ──
    /** 显示课程名（右侧文本门控）。Dart `liveShowCourseName`，默认 true。 */
    val showCourseName: Boolean = true,
    /** 显示地点。默认 true。 */
    val showLocation: Boolean = true,
    /** 显示倒计时。默认 true。 */
    val showCountdown: Boolean = true,
    /** 倒计时格式。默认 SMART。 */
    val countdownTextStyle: LiveCountdownTextStyle = LiveCountdownTextStyle.SMART,
    /** 显示阶段状态文案。默认 true。 */
    val showStageText: Boolean = true,
    /** 优先显示课程简称。默认 true。 */
    val useShortName: Boolean = true,
    /** 隐藏「距上课 / 距下课」前缀。默认 true。 */
    val hidePrefixText: Boolean = true,
    /** 课中时间显示模式。默认 NEAREST。 */
    val duringClassTimeDisplayMode: LiveDuringClassTimeDisplayMode = LiveDuringClassTimeDisplayMode.NEAREST,
    /** 开启小米岛左侧文字图标（实验性）。默认 false。 */
    val enableMiuiIslandLabelImage: Boolean = false,
    /** 左侧图标样式。默认 TEXT_ONLY。 */
    val miuiIslandLabelStyle: MiuiIslandLabelStyle = MiuiIslandLabelStyle.TEXT_ONLY,
    /** 左侧文字内容。默认 COURSE_NAME。 */
    val miuiIslandLabelContent: MiuiIslandLabelContent = MiuiIslandLabelContent.COURSE_NAME,
    /** 左侧文字颜色（`#RRGGBB`）。默认 `#FFFFFF`。 */
    val miuiIslandLabelFontColor: String = "#FFFFFF",
    /** 左侧文字字重。默认 BOLD。 */
    val miuiIslandLabelFontWeight: MiuiIslandLabelFontWeight = MiuiIslandLabelFontWeight.BOLD,
    /** 左侧文字清晰度。默认 STANDARD。 */
    val miuiIslandLabelRenderQuality: MiuiIslandLabelRenderQuality = MiuiIslandLabelRenderQuality.STANDARD,
    /** 左侧文字字号（sp）。默认 14。 */
    val miuiIslandLabelFontSize: Double = 14.0,
    /** 左侧文字水平偏移（-2..2）。默认 0。 */
    val miuiIslandLabelOffsetX: Double = 0.0,
    /** 左侧文字垂直偏移（-2..2）。默认 0。 */
    val miuiIslandLabelOffsetY: Double = 0.0,
    /** 左侧图标 Logo 图片路径（null = 用应用图标）。默认 null。 */
    val miuiIslandLabelLogoPath: String? = null,
    /** 左侧图标圆角（0..12）。默认 8。 */
    val miuiIslandLabelLogoCornerRadius: Double = 8.0,
    /** 展开态大图标模式。默认 APP_ICON。 */
    val miuiIslandExpandedIconMode: MiuiIslandExpandedIconMode = MiuiIslandExpandedIconMode.APP_ICON,
    /** 展开态自定义大图标路径。默认 null。 */
    val miuiIslandExpandedIconPath: String? = null,
    /** 展开态详情字段（可见 + 顺序）；null = 全部显示（默认 / 老数据）。 */
    val expandedDetailFields: List<LiveExpandedDetailField>? = null,

    // ── 2. 页面级关联字段（来自 TimetableSettings 顶层 live* 属性）──
    /** 上课前快捷操作。Dart `liveBeforeClassQuickAction`，默认 NONE。 */
    val beforeClassQuickAction: LiveBeforeClassQuickAction = LiveBeforeClassQuickAction.NONE,
    /** 自动执行的提前分钟数；0 = 不自动执行。Dart `liveBeforeClassQuickActionAutoMinutes`，默认 0。 */
    val beforeClassQuickActionAutoMinutes: Int = 0,
    /** 课中/下课页是否跟随上课前提醒设置。Dart `liveDuringEndFollowBeforeClass`，默认 true。 */
    val duringEndFollowBeforeClass: Boolean = true,
    /** 下课秒级倒计时阈值（秒）。Dart `liveEndSecondsCountdownThreshold`，默认 60。 */
    val endSecondsCountdownThreshold: Int = 60,
    /** 课中是否提升通知（影响展开态是否出 stage / status 行）。Dart `livePromoteDuringClass`，默认 true。 */
    val promoteDuringClass: Boolean = true,
)

// ───────────────────────────── 预览数据 ─────────────────────────────

/**
 * 预览卡片要展示的课程信息 + 展示参数（不依赖 Flutter `Course`）。
 *
 * 时间与课程**全部从调用方传入**——预览组件内部不写死钟点、不写死假课程。
 * 默认演示数据由页面用 ARB 样例文案（`liveIslandPreviewSampleCourse` 等）构造。
 */
data class LiveIslandPreviewInfo(
    /** 课程全名。 */
    val courseName: String,
    /** 课程简称（可空；为空或等于全名时相关行跳过）。 */
    val courseShortName: String? = null,
    /** 地点。 */
    val location: String,
    /** 教师。 */
    val teacher: String,
    /** 开始时间钟面（`HH:mm`）。 */
    val startTime: String,
    /** 结束时间钟面（`HH:mm`）。 */
    val endTime: String,
    /** 备注（可空）。 */
    val note: String? = null,
    /** 下一节课名（可空；为空时「下节课」行显示占位）。 */
    val nextCourseName: String? = null,
    /**
     * 倒计时锚点（毫秒）。null = 静态演示窗口（进页即走），
     * 非 null = 速览测试真实窗口起点，倒计时与真机同步。
     */
    val anchorMillis: Long? = null,
    /**
     * 当前课程的真实起止毫秒（同一天）。
     *
     * 与 [startTime] / [endTime] 成对：真实课程预览时倒计时按这两个边界走，
     * 不再套「12 分 37 秒 / 45 分钟」的演示节奏。null = 没有真实课程数据。
     */
    val startMillis: Long? = null,
    val endMillis: Long? = null,
    /**
     * 这一份数据对应真实课堂的哪个时刻。
     *
     * null = 纯设计/测试构造（沿用 [forDuringEnd] 的固定阶段，不参与空态判断）。
     */
    val moment: LivePreviewMoment? = null,
    /**
     * 锚点是否来自速览测试的**真实**窗口。
     *
     * 与 [anchorMillis] 拆开是为了让渲染层能在静态预览时捕获一次「现在」作为稳定锚点
     * （否则每 tick 都把 now 当锚点，倒计时会永远停在初始值），同时仍按静态节奏计算窗口。
     */
    val anchored: Boolean = anchorMillis != null,
    /** 下课秒级倒计时阈值（秒），仅 before-end 阶段格式化使用。 */
    val endSecondsCountdownThresholdSeconds: Int = 60,
    /** 课中是否提升通知（课中展开态是否出 stage / status 行）。 */
    val promoteDuringClass: Boolean = true,
)

/** 预览时间窗（起止毫秒）。 */
data class LivePreviewWindow(val startMillis: Long, val endMillis: Long)

/**
 * 展开详情的一行。
 *
 * [unfilled] = 课程没填该字段，真机将跳过此行；渲染层对这类行用灰斜体并追加
 * `liveExpandedDetailUnfilledSuffix` 说明（对齐 Dart `_DetailLineText` 的 `(?)` 约定，
 * 但这里用布尔标记而不是往文本里塞 `(?)` 前缀）。
 */
data class LiveDetailLine(val text: String, val unfilled: Boolean = false)

// ───────────────────────────── 纯逻辑 ─────────────────────────────

/**
 * 显示设置页纯逻辑（零 IO、确定性，全部有手推期望值的 JVM 单测）。
 */
object LiveDisplayLogic {

    /** 上课前快捷操作「自动执行」的可选提前分钟数（Dart `_quickActionAutoMinutesOptions`）。 */
    val QUICK_ACTION_AUTO_MINUTES_OPTIONS: List<Int> = listOf(5, 10, 15, 20, 30)

    /** 小米岛左侧文字可选颜色（Dart `_labelColors`）——6 色点。 */
    val LABEL_COLORS: List<String> = listOf(
        "#FFFFFF",
        "#E2E8F0",
        "#BFDBFE",
        "#A7F3D0",
        "#FDE68A",
        "#F9A8D4",
    )

    /** 小米岛左侧文字字号范围 / 步数（Dart slider：min 1, max 32, divisions 31）。 */
    const val LABEL_FONT_SIZE_MIN = 1.0
    const val LABEL_FONT_SIZE_MAX = 32.0
    const val LABEL_FONT_SIZE_DIVISIONS = 31

    /** 左侧文字偏移范围（-2..2，divisions 40）。 */
    const val LABEL_OFFSET_MIN = -2.0
    const val LABEL_OFFSET_MAX = 2.0
    const val LABEL_OFFSET_DIVISIONS = 40

    /** 左侧图标圆角范围（0..12，divisions 12）。 */
    const val LABEL_LOGO_CORNER_MIN = 0.0
    const val LABEL_LOGO_CORNER_MAX = 12.0
    const val LABEL_LOGO_CORNER_DIVISIONS = 12

    // ── 默认展开字段顺序 ───────────────────────────────────────────

    /**
     * 本页可操作的展开详情字段全集（顺序即默认行序），按阶段。
     *
     * 逐字照 `lib/utils/live_expanded_detail_fields.dart:20-41`：
     * - 课前页不含 stage / progress / status（课前恒为提升态，这三行渲染不出）；
     * - 课中页九字段，顺序按提升态行序（progress 在 status 前、shortName 靠后）。
     */
    fun defaultDetailFieldsForStage(forDuringEnd: Boolean): List<LiveExpandedDetailField> =
        if (forDuringEnd) {
            listOf(
                LiveExpandedDetailField.PROGRESS,
                LiveExpandedDetailField.STATUS,
                LiveExpandedDetailField.TIME,
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
                LiveExpandedDetailField.STAGE,
            )
        } else {
            listOf(
                LiveExpandedDetailField.TIME,
                LiveExpandedDetailField.LOCATION,
                LiveExpandedDetailField.TEACHER,
                LiveExpandedDetailField.SHORT_NAME,
                LiveExpandedDetailField.NEXT_COURSE,
                LiveExpandedDetailField.NOTE,
            )
        }

    /**
     * 展开详情当前工作顺序（`resolveExpandedDetailWorkOrder`）。
     *
     * 名单未设置（null）→ 可见集全开、按默认序；已设置 → 取「名单 ∩ 可见集」，
     * 名单里没提到的可见字段即被用户关掉；存储里残留的不可见字段（如课前名单里的
     * stage）被剔除。
     */
    fun resolveDetailWorkOrder(
        state: LiveDisplayState,
        forDuringEnd: Boolean,
    ): List<LiveExpandedDetailField> {
        val visible = defaultDetailFieldsForStage(forDuringEnd)
        val configured = state.expandedDetailFields ?: return visible.toList()
        return configured.filter { visible.contains(it) }
    }

    /** 已隐藏字段（可见集里不在工作顺序中的），按默认序排列。 */
    fun resolveHiddenDetailFields(
        state: LiveDisplayState,
        forDuringEnd: Boolean,
    ): List<LiveExpandedDetailField> {
        val visible = defaultDetailFieldsForStage(forDuringEnd)
        val enabled = resolveDetailWorkOrder(state, forDuringEnd)
        return visible.filter { !enabled.contains(it) }
    }

    /**
     * 切换某字段显隐，返回新的 `expandedDetailFields`。
     *
     * 照 Dart `_toggleExpandedDetailField`：关到只剩一个时保留「最后开会话」
     * （列表始终至少渲染一行）；其余情况移除；未显示则追加到末尾。
     */
    fun toggleDetailField(
        state: LiveDisplayState,
        field: LiveExpandedDetailField,
        forDuringEnd: Boolean,
    ): List<LiveExpandedDetailField> {
        val work = resolveDetailWorkOrder(state, forDuringEnd).toMutableList()
        if (work.contains(field)) {
            if (work.size == 1) return work // 至少保留一行
            work.remove(field)
        } else {
            work.add(field)
        }
        return work
    }

    /**
     * 落位排序：把 [oldIndex] 处字段挪到 [newIndex]，返回新列表。
     *
     * 照 Dart `_reorderExpandedDetailField`：目标下标先 clamp 到 [0, size-1]，
     * 相同则原样返回（框架已把下移的插入位校正为目标下标，不再手动减一）。
     */
    fun reorderDetailField(
        state: LiveDisplayState,
        oldIndex: Int,
        newIndex: Int,
        forDuringEnd: Boolean,
    ): List<LiveExpandedDetailField> {
        val work = resolveDetailWorkOrder(state, forDuringEnd).toMutableList()
        if (oldIndex < 0 || oldIndex >= work.size) return work
        val target = newIndex.coerceIn(0, work.size - 1)
        if (target == oldIndex) return work
        val item = work.removeAt(oldIndex)
        work.add(target, item)
        return work
    }

    /**
     * 无障碍「上移 / 下移」：把 [field] 在已显示顺序里挪 [delta] 格，越界不变。
     */
    fun moveDetailFieldBy(
        state: LiveDisplayState,
        field: LiveExpandedDetailField,
        delta: Int,
        forDuringEnd: Boolean,
    ): List<LiveExpandedDetailField> {
        val work = resolveDetailWorkOrder(state, forDuringEnd).toMutableList()
        val index = work.indexOf(field)
        if (index < 0) return work
        val target = index + delta
        if (target < 0 || target >= work.size) return work
        val item = work.removeAt(index)
        work.add(target, item)
        return work
    }

    /** 重置展开详情 → null（未自定义），页面即按阶段默认顺序全显示。 */
    fun resetDetailFields(): List<LiveExpandedDetailField>? = null

    // ── 显示内容副标题 / 置灰判定 ──────────────────────────────────

    /**
     * 课程名行是否该挂「左侧已显示课程名」提示。
     *
     * 照 Dart `_courseNameSubtitle`：仅当开关打开、且开了左侧图标、且左侧内容含课程名时提示。
     */
    fun showCourseNameDuplicatedHint(state: LiveDisplayState): Boolean =
        state.showCourseName &&
            state.enableMiuiIslandLabelImage &&
            (state.miuiIslandLabelContent == MiuiIslandLabelContent.COURSE_NAME ||
                state.miuiIslandLabelContent == MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION)

    /** 地点行是否该挂「左侧已显示地点」提示（同上规则，换地点）。 */
    fun showLocationDuplicatedHint(state: LiveDisplayState): Boolean =
        state.showLocation &&
            state.enableMiuiIslandLabelImage &&
            (state.miuiIslandLabelContent == MiuiIslandLabelContent.LOCATION ||
                state.miuiIslandLabelContent == MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION)

    /** 「显示阶段状态文案」行置灰：倒计时开启时它不生效（Dart AnimatedOpacity）。 */
    fun shouldDimStageText(state: LiveDisplayState): Boolean = state.showCountdown

    /** 「隐藏前缀」行置灰：倒计时关闭时它不生效。 */
    fun shouldDimHidePrefix(state: LiveDisplayState): Boolean = !state.showCountdown

    /** 上课前快捷操作是否要求「勿扰模式访问权限」（Dart `requiresDoNotDisturbAccess`）。 */
    fun requiresDoNotDisturbAccess(action: LiveBeforeClassQuickAction): Boolean = when (action) {
        LiveBeforeClassQuickAction.NONE -> false
        LiveBeforeClassQuickAction.SILENT -> false
        LiveBeforeClassQuickAction.DO_NOT_DISTURB -> true
        LiveBeforeClassQuickAction.PRIORITY_ONLY -> true
        LiveBeforeClassQuickAction.BOTH -> true
    }

    /** 快捷操作「自动执行」下拉项：0（不自动执行）+ 5/10/15/20/30 分钟。 */
    fun quickActionAutoMinuteOptions(): List<Int> = listOf(0) + QUICK_ACTION_AUTO_MINUTES_OPTIONS

    // ── 倒计时格式化（12 分支，逐字 port CountdownFormat.kt）────────

    /**
     * 倒计时秒数格式化（Dart `_formatIslandCountdown`）。**12 个分支逐条对齐**。
     *
     * 期望值（手推，[thresholdSeconds] = 60）：
     * - SMART / 0s        -> `0秒`
     * - SMART / 59s       -> `59秒`（≤阈值走秒）
     * - SMART / 61s       -> `2分钟`（60<61≤120，向上取整）
     * - SMART / 119s      -> `2分钟`
     * - SMART / 121s      -> `2分钟`（>120 向下取整分钟）
     * - SMART / 600s      -> `10分钟`
     * - SMART_MIN_S / 61s -> `2min`
     * - MINUTE_SECOND_CN / 319s -> `5分钟19秒`（319=5*60+19）
     * - MINUTE_SECOND_CN / 300s -> `5分钟`（秒为 0 只留分钟）
     * - MINUTE_SECOND_CN / 45s  -> `45秒`（分钟为 0 只留秒）
     * - MINUTE_SECOND_COLON / 319s -> `05:19`
     * - MINUTE_SECOND_MIN_S / 319s -> `5min19s`
     * - MINUTE_SECOND_MIN_SLASH_S / 319s -> `5min/19s`
     * - MINUTE_SECOND_MIN_SLASH_S / 300s -> `5min`（去尾部斜杠）
     * - MINUTE_ONLY_CN / 180s -> `3分钟`（向下取整）
     * - MINUTE_ONLY_CN / 30s  -> `1分钟`（不足一分钟至少 1 分钟）
     * - MINUTE_ONLY_MIN / 180s -> `3min`
     * - MINUTE_ONLY_SLASH / 180s -> `3/min`
     * - SECOND_ONLY_CN / 45s -> `45秒`
     * - SECOND_ONLY_SHORT / 45s -> `45s`
     * - SECOND_ONLY_SLASH / 45s -> `45/s`
     */
    fun formatCountdown(
        totalSeconds: Int,
        style: LiveCountdownTextStyle,
        thresholdSeconds: Int = 60,
    ): String {
        val s = if (totalSeconds <= 0) 0 else totalSeconds
        return when (style) {
            LiveCountdownTextStyle.SMART_MIN_S ->
                smartCountdown(s, thresholdSeconds, "min", "s")
            LiveCountdownTextStyle.MINUTE_SECOND_CN ->
                minuteSecondCountdown(s, "分钟", "秒")
            LiveCountdownTextStyle.MINUTE_SECOND_COLON ->
                "%02d:%02d".format(s / 60, s % 60)
            LiveCountdownTextStyle.MINUTE_SECOND_MIN_S ->
                minuteSecondCountdown(s, "min", "s")
            LiveCountdownTextStyle.MINUTE_SECOND_MIN_SLASH_S ->
                minuteSecondCountdown(s, "min/", "s")
            LiveCountdownTextStyle.MINUTE_ONLY_CN ->
                "${minutesFloor(s)}分钟"
            LiveCountdownTextStyle.MINUTE_ONLY_MIN ->
                "${minutesFloor(s)}min"
            LiveCountdownTextStyle.MINUTE_ONLY_SLASH ->
                "${minutesFloor(s)}/min"
            LiveCountdownTextStyle.SECOND_ONLY_CN -> "${s}秒"
            LiveCountdownTextStyle.SECOND_ONLY_SHORT -> "${s}s"
            LiveCountdownTextStyle.SECOND_ONLY_SLASH -> "${s}/s"
            LiveCountdownTextStyle.SMART ->
                smartCountdown(s, thresholdSeconds, "分钟", "秒")
        }
    }

    /** 从毫秒剩余量格式化（负值按 0 秒处理，与 Dart `millis ~/ 1000` 一致）。 */
    fun formatCountdownMillis(
        remainingMillis: Long,
        style: LiveCountdownTextStyle,
        thresholdSeconds: Int = 60,
    ): String {
        val seconds = if (remainingMillis <= 0L) 0 else (remainingMillis / 1000L).toInt()
        return formatCountdown(seconds, style, thresholdSeconds)
    }

    private fun smartCountdown(
        totalSeconds: Int,
        thresholdSeconds: Int,
        minuteSuffix: String,
        secondSuffix: String,
    ): String {
        if (totalSeconds <= thresholdSeconds) return "$totalSeconds$secondSuffix"
        if (totalSeconds > 120) return "${(totalSeconds / 60).coerceAtLeast(1)}$minuteSuffix"
        if (totalSeconds > 60) return "${((totalSeconds + 59) / 60).coerceAtLeast(1)}$minuteSuffix"
        return "$totalSeconds$secondSuffix"
    }

    private fun minuteSecondCountdown(
        totalSeconds: Int,
        minuteSuffix: String,
        secondSuffix: String,
    ): String {
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        if (minutes > 0 && seconds > 0) return "$minutes$minuteSuffix$seconds$secondSuffix"
        if (minutes > 0) {
            val trimmed = if (minuteSuffix.endsWith("/")) minuteSuffix.dropLast(1) else minuteSuffix
            return "$minutes$trimmed"
        }
        return "$seconds$secondSuffix"
    }

    private fun minutesFloor(totalSeconds: Int): Int = (totalSeconds / 60).coerceAtLeast(1)

    // ── 预览窗口 ───────────────────────────────────────────────────

    /**
     * 课前预览窗口（Dart `_beforeWindow`）。
     *
     * - 锚定速览窗口（anchored=true）：start = 锚点，end = 锚点 + 1s（课前变体只差 1 秒）。
     * - 静态演示（anchored=false）：start = 锚点 + 12 分 37 秒，end = start + 45 分。
     */
    fun previewBeforeWindow(anchorMillis: Long, anchored: Boolean): LivePreviewWindow =
        if (anchored) {
            LivePreviewWindow(anchorMillis, anchorMillis + 1_000L)
        } else {
            val start = anchorMillis + (12 * 60 + 37) * 1000L
            LivePreviewWindow(start, start + 45 * 60 * 1000L)
        }

    /**
     * 课中/下课预览窗口（Dart `_endWindow`）。
     *
     * - 锚定速览：start = 锚点 - 2s，end = 锚点 + 28s。
     * - 静态演示：start = 锚点 - 41 分 40 秒，end = start + 45 分。
     */
    fun previewEndWindow(anchorMillis: Long, anchored: Boolean): LivePreviewWindow =
        if (anchored) {
            LivePreviewWindow(anchorMillis - 2_000L, anchorMillis + 28_000L)
        } else {
            val start = anchorMillis - (41 * 60 + 40) * 1000L
            LivePreviewWindow(start, start + 45 * 60 * 1000L)
        }

    /**
     * 预览实际使用的窗口，优先级：
     * 1. 速览会话锚点（`anchored`）——倒计时跟真机同步，压过课程钟点；
     * 2. 真实课程起止毫秒——设置页静态预览也按用户课表走，不再编演示时长；
     * 3. 老演示节奏——仅在设计稿/纯测试构造（既无锚点也无真实钟点）时才有意义。
     */
    fun previewWindowFor(
        info: LiveIslandPreviewInfo,
        stage: LivePreviewStage,
        nowMillis: Long,
    ): LivePreviewWindow {
        val anchor = info.anchorMillis
        if (info.anchored && anchor != null) {
            return if (stage == LivePreviewStage.BEFORE_CLASS) {
                previewBeforeWindow(anchor, anchored = true)
            } else {
                previewEndWindow(anchor, anchored = true)
            }
        }
        val start = info.startMillis
        val end = info.endMillis
        if (start != null && end != null && end > start) {
            return LivePreviewWindow(start, end)
        }
        val fallbackAnchor = anchor ?: nowMillis
        return if (stage == LivePreviewStage.BEFORE_CLASS) {
            previewBeforeWindow(fallbackAnchor, anchored = false)
        } else {
            previewEndWindow(fallbackAnchor, anchored = false)
        }
    }

    /** 距窗口结束的剩余毫秒（可为负，交由格式化按 0 处理）。 */
    fun remainingMillis(window: LivePreviewWindow, nowMillis: Long): Long =
        window.endMillis - nowMillis

    /** 距窗口开始的剩余毫秒。 */
    fun millisUntilStart(window: LivePreviewWindow, nowMillis: Long): Long =
        window.startMillis - nowMillis

    // ── 摘要态文本拼装（islandCriticalText）────────────────────────

    /** 阶段词（ARB `liveIslandPreviewStage*`）。 */
    fun stageWord(stage: LivePreviewStage): String = when (stage) {
        LivePreviewStage.BEFORE_CLASS -> DisplaySettingsStrings.stageBeforeClass.zh
        LivePreviewStage.DURING_CLASS -> DisplaySettingsStrings.stageInClass.zh
        LivePreviewStage.BEFORE_END -> DisplaySettingsStrings.stageBeforeEnd.zh
    }

    /**
     * islandCourseName：课程名（受 showCourseName / useShortName 门控，原生 5 字截断）。
     *
     * 空串表示该段不参与拼接。
     */
    fun islandCourseName(state: LiveDisplayState, info: LiveIslandPreviewInfo): String {
        if (!state.showCourseName) return ""
        val short = info.courseShortName?.trim()
        val name = if (state.useShortName && !short.isNullOrEmpty()) short else info.courseName
        return if (name.length > 5) name.substring(0, 5) else name
    }

    /**
     * islandCriticalText：`[课程名, 地点, 状态]` 过滤空白后以空格拼接。
     *
     * 即摘要胶囊摄像头右侧那一条文本；「显示内容」那组开关影响的正是这里。
     */
    fun islandCriticalText(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
        nowMillis: Long,
    ): String {
        val name = islandCourseName(state, info)
        val location = if (state.showLocation) info.location else ""
        val status = statusLine(state, stage, info, nowMillis)
        return listOf(name, location, status).filter { it.isNotEmpty() }.joinToString(" ")
    }

    /**
     * islandCriticalStatusText：课中且显示倒计时 = 裸倒计时，其余 = visibleStatusText。
     */
    fun statusLine(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
        nowMillis: Long,
    ): String {
        val duringOrEndingSoon =
            stage == LivePreviewStage.DURING_CLASS || stage == LivePreviewStage.BEFORE_END
        if (duringOrEndingSoon && state.showCountdown && stage == LivePreviewStage.DURING_CLASS) {
            val window = previewWindowFor(info, stage, nowMillis)
            return formatCountdownMillis(
                remainingMillis(window, nowMillis),
                state.countdownTextStyle,
                60,
            )
        }
        return visibleStatusText(state, stage, info, nowMillis)
    }

    /**
     * visibleStatusText：!showCountdown 时由 showStageText 决定阶段词；
     * 倒计时前缀受 hidePrefixText 控制。
     */
    fun visibleStatusText(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
        nowMillis: Long,
    ): String {
        if (!state.showCountdown) {
            return if (state.showStageText) stageWord(stage) else ""
        }
        return when (stage) {
            LivePreviewStage.BEFORE_CLASS -> {
                val window = previewWindowFor(info, stage, nowMillis)
                val raw = formatCountdownMillis(millisUntilStart(window, nowMillis), state.countdownTextStyle, 60)
                untilClassStart(raw, state.hidePrefixText)
            }
            LivePreviewStage.DURING_CLASS -> stageWord(stage)
            LivePreviewStage.BEFORE_END -> {
                val window = previewWindowFor(info, stage, nowMillis)
                val raw = formatCountdownMillis(
                    remainingMillis(window, nowMillis),
                    state.countdownTextStyle,
                    info.endSecondsCountdownThresholdSeconds,
                )
                untilClassEnd(raw, state.hidePrefixText)
            }
        }
    }

    /** 「距上课 X」前缀（hidePrefixText 时不加）。 */
    fun untilClassStart(raw: String, hidePrefixText: Boolean): String =
        if (hidePrefixText) raw else DisplaySettingsStrings.untilClassStart.filled("time", raw)

    /** 「距下课 X」前缀。 */
    fun untilClassEnd(raw: String, hidePrefixText: Boolean): String =
        if (hidePrefixText) raw else DisplaySettingsStrings.untilClassEnd.filled("time", raw)

    // ── 展开态预览文本拼装 ─────────────────────────────────────────

    /** 展开态标题课程名：useShortName 门控 + 8 字截断（超出补 `..`）。 */
    fun titleCourseName(state: LiveDisplayState, info: LiveIslandPreviewInfo): String {
        val short = info.courseShortName?.trim()
        val name = if (state.useShortName && !short.isNullOrEmpty()) short else info.courseName
        return if (name.length > 8) name.substring(0, 8) + ".." else name
    }

    /** notificationTitle：课前/下课提醒带阶段前缀，课中只有课程名。 */
    fun expandedTitle(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
    ): String {
        val course = titleCourseName(state, info)
        return when (stage) {
            LivePreviewStage.BEFORE_CLASS ->
                DisplaySettingsStrings.previewTitleBeforeClass.filled("course", course)
            LivePreviewStage.BEFORE_END ->
                DisplaySettingsStrings.previewTitleBeforeEnd.filled("course", course)
            LivePreviewStage.DURING_CLASS -> course
        }
    }

    /** 课中时间显示文案：`start - end`（课程钟面）。 */
    fun timeRangeText(info: LiveIslandPreviewInfo): String = "${info.startTime} - ${info.endTime}"

    /** 该阶段是否提升态（课前与下课恒提升，课中看开关）。 */
    fun isPromoted(stage: LivePreviewStage, promoteDuringClass: Boolean): Boolean =
        if (stage == LivePreviewStage.DURING_CLASS) promoteDuringClass else true

    /** 课中带进度块：仅课中且显示倒计时时成立。 */
    fun hasProgressBlock(state: LiveDisplayState, stage: LivePreviewStage): Boolean =
        stage == LivePreviewStage.DURING_CLASS && state.showCountdown

    /**
     * promotedContentText（展开态正文）：课中带进度块时 = 倒计时 · 地点；
     * 其余 = visibleStatusText · timeRange · 地点 · 教师，过滤空白后以 ` · ` 拼接。
     */
    fun expandedSummaryLine(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
        nowMillis: Long,
    ): String {
        val parts: List<String> = if (hasProgressBlock(state, stage)) {
            val window = previewWindowFor(info, stage, nowMillis)
            listOfNotNull(
                formatCountdownMillis(remainingMillis(window, nowMillis), state.countdownTextStyle, 60),
                if (state.showLocation) info.location else null,
            )
        } else {
            listOfNotNull(
                expandedStatusText(state, stage, info, nowMillis),
                timeRangeText(info),
                if (state.showLocation) info.location else null,
                info.teacher,
            )
        }
        return parts.filter { it.isNotEmpty() }.joinToString(" · ")
    }

    /** 展开态状态文案：课中且显示倒计时 = 裸倒计时，其余 = visibleStatusText。 */
    fun expandedStatusText(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
        nowMillis: Long,
    ): String {
        if (!state.showCountdown) return if (state.showStageText) stageWord(stage) else ""
        return when (stage) {
            LivePreviewStage.BEFORE_CLASS -> {
                val window = previewWindowFor(info, stage, nowMillis)
                val raw = formatCountdownMillis(millisUntilStart(window, nowMillis), state.countdownTextStyle, 60)
                untilClassStart(raw, state.hidePrefixText)
            }
            LivePreviewStage.DURING_CLASS -> {
                val window = previewWindowFor(info, stage, nowMillis)
                formatCountdownMillis(remainingMillis(window, nowMillis), state.countdownTextStyle, 60)
            }
            LivePreviewStage.BEFORE_END -> {
                val window = previewWindowFor(info, stage, nowMillis)
                val raw = formatCountdownMillis(
                    remainingMillis(window, nowMillis),
                    state.countdownTextStyle,
                    info.endSecondsCountdownThresholdSeconds,
                )
                untilClassEnd(raw, state.hidePrefixText)
            }
        }
    }

    /**
     * 展开详情行（Dart `_detailLines`）。
     *
     * 顺序 = 用户配置顺序（null → 预览固定默认序，**不含 stage**：progress / status /
     * time / location / teacher / shortName / next / note）；值空缺时按原生规则处理：
     * location / teacher / next / note 显示 `(?)` 占位（[LiveDetailLine.unfilled]），
     * shortName 直接跳行，progress 仅课中且显示倒计时时出两行（下一节点 / 整节下课）。
     */
    fun expandedDetailLines(
        state: LiveDisplayState,
        stage: LivePreviewStage,
        info: LiveIslandPreviewInfo,
        nowMillis: Long,
    ): List<LiveDetailLine> {
        val order = state.expandedDetailFields
            ?: PREVIEW_DEFAULT_DETAIL_ORDER
        val promoted = isPromoted(stage, info.promoteDuringClass)
        val lines = mutableListOf<LiveDetailLine>()
        for (field in order) {
            when (field) {
                LiveExpandedDetailField.STAGE ->
                    if (!promoted) lines.add(LiveDetailLine(stageWord(stage)))

                LiveExpandedDetailField.SHORT_NAME -> {
                    val displayShort = shortNameLabel(info)
                    if (displayShort != null) {
                        lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineShortName.filled("value", displayShort)))
                    }
                }

                LiveExpandedDetailField.PROGRESS ->
                    if (hasProgressBlock(state, stage)) {
                        lines.add(
                            LiveDetailLine(
                                DisplaySettingsStrings.detailLineProgressNext.filled(
                                    "value",
                                    stageWord(LivePreviewStage.BEFORE_END),
                                ),
                            ),
                        )
                        val window = previewWindowFor(info, stage, nowMillis)
                        lines.add(
                            LiveDetailLine(
                                DisplaySettingsStrings.detailLineProgressFinal.filled(
                                    "value",
                                    formatCountdownMillis(
                                        remainingMillis(window, nowMillis),
                                        state.countdownTextStyle,
                                        60,
                                    ),
                                ),
                            ),
                        )
                    }

                LiveExpandedDetailField.STATUS ->
                    if (!promoted && !hasProgressBlock(state, stage)) {
                        val status = expandedStatusText(state, stage, info, nowMillis)
                        if (status.isNotEmpty()) {
                            lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineStatus.filled("value", status)))
                        }
                    }

                LiveExpandedDetailField.TIME ->
                    lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineTime.filled("value", timeRangeText(info))))

                LiveExpandedDetailField.LOCATION -> {
                    val loc = info.location.trim()
                    if (loc.isNotEmpty()) {
                        lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineLocation.filled("value", loc)))
                    } else {
                        lines.add(
                            LiveDetailLine(
                                DisplaySettingsStrings.detailLineLocation.filled(
                                    "value",
                                    DisplaySettingsStrings.unfilledValue.zh,
                                ),
                                unfilled = true,
                            ),
                        )
                    }
                }

                LiveExpandedDetailField.TEACHER -> {
                    val teacher = info.teacher.trim()
                    if (teacher.isNotEmpty()) {
                        lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineTeacher.filled("value", teacher)))
                    } else {
                        lines.add(
                            LiveDetailLine(
                                DisplaySettingsStrings.detailLineTeacher.filled(
                                    "value",
                                    DisplaySettingsStrings.unfilledValue.zh,
                                ),
                                unfilled = true,
                            ),
                        )
                    }
                }

                LiveExpandedDetailField.NEXT_COURSE -> {
                    val next = info.nextCourseName?.trim()
                    if (!next.isNullOrEmpty()) {
                        lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineNext.filled("value", next)))
                    } else {
                        lines.add(
                            LiveDetailLine(
                                DisplaySettingsStrings.detailLineNext.filled(
                                    "value",
                                    DisplaySettingsStrings.unfilledValue.zh,
                                ),
                                unfilled = true,
                            ),
                        )
                    }
                }

                LiveExpandedDetailField.NOTE -> {
                    val note = info.note?.trim()
                    if (!note.isNullOrEmpty()) {
                        lines.add(LiveDetailLine(DisplaySettingsStrings.detailLineNote.filled("value", note)))
                    } else {
                        lines.add(
                            LiveDetailLine(
                                DisplaySettingsStrings.detailLineNote.filled(
                                    "value",
                                    DisplaySettingsStrings.unfilledValue.zh,
                                ),
                                unfilled = true,
                            ),
                        )
                    }
                }
            }
        }
        return lines
    }

    /**
     * 展开态预览固定默认字段序（Dart `_detailLines` 里 `expandedDetailFields ?? const [...]`）。
     *
     * **注意**：它与设置页的「阶段可见字段」（[defaultDetailFieldsForStage]）不是一回事——
     * 这里是原生存储兜底序，不含 stage；两者各管一边，不要互相纠正。
     */
    val PREVIEW_DEFAULT_DETAIL_ORDER: List<LiveExpandedDetailField> = listOf(
        LiveExpandedDetailField.PROGRESS,
        LiveExpandedDetailField.STATUS,
        LiveExpandedDetailField.TIME,
        LiveExpandedDetailField.LOCATION,
        LiveExpandedDetailField.TEACHER,
        LiveExpandedDetailField.SHORT_NAME,
        LiveExpandedDetailField.NEXT_COURSE,
        LiveExpandedDetailField.NOTE,
    )

    /** shortNameLabel：简称非空且 ≠ 课程全名，否则返回 null（整行跳过）。 */
    fun shortNameLabel(info: LiveIslandPreviewInfo): String? {
        val raw = info.courseShortName?.trim() ?: return null
        if (raw.isEmpty()) return null
        return if (raw == info.courseName.trim()) null else raw
    }

    /** 某阶段该预览哪些阶段（课中/下课页 = 课中 + 下课提醒；课前页 = 即将上课）。 */
    fun stagesFor(forDuringEnd: Boolean): List<LivePreviewStage> =
        if (forDuringEnd) {
            listOf(LivePreviewStage.DURING_CLASS, LivePreviewStage.BEFORE_END)
        } else {
            listOf(LivePreviewStage.BEFORE_CLASS)
        }

    /**
     * 真实课堂时刻优先的阶段选择。
     *
     * - 上课中 → 上课中 + 下课提醒（两页都如实显示岛此刻的状态）；
     * - 课间 → 即将上课（下一节，课前页与课中/下课页都先看到它）；
     * - 无课 → 空列表（页面不画岛卡，改画诚实空态）；
     * - `moment == null` → 老口径（设计稿 / 纯测试构造）。
     */
    fun stagesFor(
        forDuringEnd: Boolean,
        moment: LivePreviewMoment?,
    ): List<LivePreviewStage> = when (moment) {
        LivePreviewMoment.IN_CLASS ->
            listOf(LivePreviewStage.DURING_CLASS, LivePreviewStage.BEFORE_END)
        LivePreviewMoment.BETWEEN_CLASSES ->
            listOf(LivePreviewStage.BEFORE_CLASS)
        LivePreviewMoment.NO_COURSE -> emptyList()
        null -> stagesFor(forDuringEnd)
    }
}

// ──────────────── 状态变异纯函数（便于单测与渲染层复用）────────────────

fun LiveDisplayState.withShowCourseName(value: Boolean): LiveDisplayState = copy(showCourseName = value)
fun LiveDisplayState.withShowLocation(value: Boolean): LiveDisplayState = copy(showLocation = value)
fun LiveDisplayState.withShowCountdown(value: Boolean): LiveDisplayState = copy(showCountdown = value)
fun LiveDisplayState.withCountdownTextStyle(style: LiveCountdownTextStyle): LiveDisplayState =
    copy(countdownTextStyle = style)
fun LiveDisplayState.withShowStageText(value: Boolean): LiveDisplayState = copy(showStageText = value)
fun LiveDisplayState.withUseShortName(value: Boolean): LiveDisplayState = copy(useShortName = value)
fun LiveDisplayState.withHidePrefixText(value: Boolean): LiveDisplayState = copy(hidePrefixText = value)
fun LiveDisplayState.withDuringClassTimeDisplayMode(mode: LiveDuringClassTimeDisplayMode): LiveDisplayState =
    copy(duringClassTimeDisplayMode = mode)
fun LiveDisplayState.withEnableMiuiIslandLabelImage(value: Boolean): LiveDisplayState =
    copy(enableMiuiIslandLabelImage = value)
fun LiveDisplayState.withMiuiIslandLabelStyle(value: MiuiIslandLabelStyle): LiveDisplayState =
    copy(miuiIslandLabelStyle = value)
fun LiveDisplayState.withMiuiIslandLabelContent(value: MiuiIslandLabelContent): LiveDisplayState =
    copy(miuiIslandLabelContent = value)
fun LiveDisplayState.withMiuiIslandLabelFontColor(value: String): LiveDisplayState =
    copy(miuiIslandLabelFontColor = value)
fun LiveDisplayState.withMiuiIslandLabelFontWeight(value: MiuiIslandLabelFontWeight): LiveDisplayState =
    copy(miuiIslandLabelFontWeight = value)
fun LiveDisplayState.withMiuiIslandLabelRenderQuality(value: MiuiIslandLabelRenderQuality): LiveDisplayState =
    copy(miuiIslandLabelRenderQuality = value)
fun LiveDisplayState.withMiuiIslandLabelFontSize(value: Double): LiveDisplayState =
    copy(miuiIslandLabelFontSize = value.coerceIn(LiveDisplayLogic.LABEL_FONT_SIZE_MIN, LiveDisplayLogic.LABEL_FONT_SIZE_MAX))
fun LiveDisplayState.withMiuiIslandLabelOffsetX(value: Double): LiveDisplayState =
    copy(miuiIslandLabelOffsetX = value.coerceIn(LiveDisplayLogic.LABEL_OFFSET_MIN, LiveDisplayLogic.LABEL_OFFSET_MAX))
fun LiveDisplayState.withMiuiIslandLabelOffsetY(value: Double): LiveDisplayState =
    copy(miuiIslandLabelOffsetY = value.coerceIn(LiveDisplayLogic.LABEL_OFFSET_MIN, LiveDisplayLogic.LABEL_OFFSET_MAX))
fun LiveDisplayState.withMiuiIslandLabelLogoPath(value: String?): LiveDisplayState =
    copy(miuiIslandLabelLogoPath = value)
fun LiveDisplayState.withMiuiIslandLabelLogoCornerRadius(value: Double): LiveDisplayState =
    copy(miuiIslandLabelLogoCornerRadius = value.coerceIn(LiveDisplayLogic.LABEL_LOGO_CORNER_MIN, LiveDisplayLogic.LABEL_LOGO_CORNER_MAX))
fun LiveDisplayState.withMiuiIslandExpandedIconMode(value: MiuiIslandExpandedIconMode): LiveDisplayState =
    copy(miuiIslandExpandedIconMode = value)
fun LiveDisplayState.withMiuiIslandExpandedIconPath(value: String?): LiveDisplayState =
    copy(miuiIslandExpandedIconPath = value)
fun LiveDisplayState.withExpandedDetailFields(value: List<LiveExpandedDetailField>?): LiveDisplayState =
    copy(expandedDetailFields = value)
fun LiveDisplayState.withBeforeClassQuickAction(value: LiveBeforeClassQuickAction): LiveDisplayState =
    copy(beforeClassQuickAction = value)
fun LiveDisplayState.withBeforeClassQuickActionAutoMinutes(value: Int): LiveDisplayState =
    copy(beforeClassQuickActionAutoMinutes = value)
fun LiveDisplayState.withDuringEndFollowBeforeClass(value: Boolean): LiveDisplayState =
    copy(duringEndFollowBeforeClass = value)
fun LiveDisplayState.withEndSecondsCountdownThreshold(value: Int): LiveDisplayState =
    copy(endSecondsCountdownThreshold = value)
fun LiveDisplayState.withPromoteDuringClass(value: Boolean): LiveDisplayState =
    copy(promoteDuringClass = value)

/** 恢复默认（= 全字段默认值）。 */
fun LiveDisplayState.resetDisplayDefaults(): LiveDisplayState = LiveDisplayState()
