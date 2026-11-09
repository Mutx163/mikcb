package com.mutx163.qingyu.pages.settings

import java.util.Locale

/**
 * 超级岛自检页（`lib/screens/settings/settings_live.dart:168-1186`）结构模型。
 *
 * ## 这一页其实是一个「原生状态面板」
 *
 * 14 个区块里只有一半是设置项：假期覆盖、测试通知、上岛状态、时间校正、本地日志
 * 是给测试者手动拨的；另外九块（`_LiveTestingSection.debug*` / `rawJson`）是
 * **原生诊断数据的只读渲染**，`_debugStatus == null`（还没拉到）时整段不出现。
 * 所以模型把「有没有拉到调试数据」做成 [LiveSelfCheckData.debugLoaded]，
 * 而不是让调用方拼一个可能为空的结构。
 *
 * ## 逐项对照
 *
 * | Flutter（行号见 Dart 源） | 本模型 | 官方 Miuix 对应物 |
 * |---|---|---|
 * | `HyperosSectionLabel(liveTestingHolidayOverride)`（:717） | `SettingsLabel` | preference category |
 * | `HyperosSwitchTile(假期模式)`（:720-732） | `liveSelfCheck.holidaySwitch` | `MiuixSwitchPreference` |
 * | `_DebugStatusChip(自检测试进行中)`（:756-763） | `SettingsDescription` | 见下方口径 1 |
 * | `_DebugStatusChip(选课测试中 · X)`（:777-785） | `SettingsDescription` | 同上 |
 * | `HyperosControlCard(测试通知)`（:749-827） | `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 * | `HyperosControlCard(上岛状态诊断)`（:847-979） | `SettingsInline(CONTROL_CARD)` | 同上 |
 * | `HyperosSliderTile(时间校正)`（:995-1033） | `liveSelfCheck.timeCorrection` | `MiuixSliderPreference` |
 * | `_DebugSectionCard`×8（:1041-1114） | `SettingsLabel` + `SettingsGroup` | preference category + `basic.Card` |
 * | `HyperosAccordion(原始 JSON)`（:1115-1148） | `SettingsInline(CONTROL_CARD)` | 官方无折叠卡（见口径 2） |
 * | `HyperosControlCard(本地诊断日志)`（:1149-1183） | `SettingsInline(CONTROL_CARD)` | `basic.Card` + 官方 `Button` |
 *
 * ## 三处「形状不同、文案与顺序忠实」的口径（评审可查）
 *
 * 1. **状态芯片**：Dart 的 `_DebugStatusChip`（:1224-1259）是「图标 + 文字」的胶囊。
 *    `SettingsNode` 词汇表没有胶囊槽位，这里落成 [SettingsDescription]（整宽一行字）。
 *    渲染层将来补 chip 槽位时只改映射，不动任何文案。
 * 2. **原始 JSON 折叠块**：官方 0.8.8 没有折叠卡；模型用 `CONTROL_CARD` 装
 *    「标题 + 副标题 + 折叠内容」，折叠行为归渲染层/宿主，模型只保证两句文案在位。
 * 3. **`HyperosControlCard` 的容器边界**：Dart 把芯片、小标题、按钮、开关、脚注
 *    全塞在同一个 `Card` 里（`:846-978`）。模型按**屏上顺序**把它们摊成同级的
 *    卡头 + 整宽文案 + 开关分组：顺序一字不差，容器由渲染层决定。
 *
 * ## 不写进模型的行为（接线层必须照做）
 *
 * - 每秒轮询 `_refreshDebugStatus`（:269-283），且**自动刷新开关只挡诊断拉取，
 *   不挡按钮翻转**（:272-278）；
 * - 假期覆盖开关写失败要把开关拨回真源（:224-258）——落盘失败与规则拒绝是两条
 *   不同的提示（`settings_shared.dart:45-80`）；
 * - 导出日志的两级回退（先平台通道，拿不到就落临时 JSON 快照，:330-382），
 *   快照必须脱敏（:396-413）。
 */
object SettingsLiveSelfCheckPage {

    const val ID = "settings-live-self-check"

    const val ID_TITLE_KEY = "liveSelfCheckTitle"

    /** 具名路由（:154-158、`debug_deep_link_route_registry.dart:64,70`）。 */
    const val ROUTE_SELF_CHECK = "/settings/live/self-check"
    const val ROUTE_KEEP_ALIVE = "/settings/live/keep-alive"

    /** 时间校正的上下限与档数（:1001-1004）。 */
    const val TIME_CORRECTION_MIN = -30.0
    const val TIME_CORRECTION_MAX = 30.0
    const val TIME_CORRECTION_DIVISIONS = 60

    fun spec(
        state: SettingsPageState,
        data: LiveSelfCheckData = LiveSelfCheckData(),
    ): SettingsPageSpec {
        val s = SettingsStringsExt3
        val nodes = mutableListOf<SettingsNode>()

        // ── 区块 1：假期状态覆盖（:713-737，仅非 release 构建）
        if (!data.isReleaseBuild) {
            nodes += SettingsLabel(
                id = "liveSelfCheck.section.holidayOverride",
                textKey = s.liveTestingHolidayOverride.key,
                text = s.liveTestingHolidayOverride.text,
            )
            nodes += SettingsGroup(
                id = "liveSelfCheck.group.holidayOverride",
                children = listOf(holidaySwitchRow(data)),
            )
            nodes += SettingsGap("liveSelfCheck.gap.holidayOverride")
        }

        // ── 区块 2：测试通知（:738-832）
        // 两颗芯片在 Dart 里位于卡内、按钮之上（:756-763 / :777-785），
        // 摊平后排在卡之前以保持屏上顺序。
        if (data.sessionActive) {
            nodes += SettingsDescription(
                id = "liveSelfCheck.desc.sessionRunning",
                textKey = s.liveTestingSessionRunning.key,
                text = s.liveTestingSessionRunning.text,
            )
        }
        data.courseTestLabel?.let { label ->
            nodes += SettingsDescription(
                id = "liveSelfCheck.desc.courseTestChip",
                textKey = s.liveTestingCourseTestActiveChip.key,
                text = s.liveTestingCourseTestActiveChip.filled("course", label),
            )
        }
        nodes += SettingsInline(
            id = "liveSelfCheck.card.notification",
            kind = InlineKind.CONTROL_CARD,
            note = "测试通知卡（:749-827）：卡内是 4~6 个官方 Button 组成的动作区，" +
                "胶囊芯片已提到卡前（见文件头口径 1）",
            labelKey = s.liveTestingNotificationTitle.key,
            label = s.liveTestingNotificationTitle.text,
            valueKey = s.liveTestingNotificationSubtitle.key,
            value = s.liveTestingNotificationSubtitle.text,
            texts = notificationButtons(data),
        )
        nodes += SettingsGap("liveSelfCheck.gap.notification")

        // ── 区块 3：上岛状态诊断（:833-984）
        nodes += SettingsInline(
            id = "liveSelfCheck.card.islandStatus",
            kind = InlineKind.CONTROL_CARD,
            note = "上岛状态诊断卡头（:847-848）：副标题在 Dart 里被删（:849 注释），" +
                "卡内动作是刷新诊断 / 导出并分享日志",
            labelKey = s.liveTestingIslandStatusTitle.key,
            label = s.liveTestingIslandStatusTitle.text,
            texts = islandStatusButtons(data),
        )
        // 学期未填的红色提示（:860-870）：Dart 里在卡内最前
        if (data.semesterUnset) {
            nodes += SettingsDescription(
                id = "liveSelfCheck.desc.semester",
                textKey = s.pleaseSetSemesterStartDate.key,
                text = s.pleaseSetSemesterStartDate.text,
            )
        }
        // 第一颗芯片：服务运行中 / 服务未运行（:875-885）
        nodes += SettingsDescription(
            id = "liveSelfCheck.desc.serviceStatus",
            textKey = if (data.serviceRunning) {
                s.liveTestingServiceStatusRunning.key
            } else {
                s.liveTestingServiceStatusStopped.key
            },
            text = if (data.serviceRunning) {
                s.liveTestingServiceStatusRunning.text
            } else {
                s.liveTestingServiceStatusStopped.text
            },
        )
        // 第二颗芯片：原生给的 statusText（:886-895），空则不渲染
        if (data.statusText.isNotEmpty()) {
            nodes += SettingsDescription(
                id = "liveSelfCheck.desc.promotableStatus",
                textKey = NON_ARB_TEXT,
                text = data.statusText,
            )
        }
        // 不上岛原因：小标题 + 正文（:898-912）
        nodes += SettingsLabel(
            id = "liveSelfCheck.label.noIslandReason",
            textKey = s.liveTestingNoIslandReasonTitle.key,
            text = s.liveTestingNoIslandReasonTitle.text,
        )
        nodes += SettingsDescription(
            id = "liveSelfCheck.desc.noIslandReason",
            textKey = noIslandReasonKey(data),
            text = noIslandReasonText(data),
        )
        // 自动刷新开关（:946-964）：卡内唯一的 preference 行
        nodes += SettingsGroup(
            id = "liveSelfCheck.group.islandStatus",
            children = listOf(autoRefreshRow(data)),
        )
        // 上次刷新时刻（:965-976）
        nodes += SettingsDescription(
            id = "liveSelfCheck.desc.refreshedAt",
            textKey = if (data.refreshedAtText == null) {
                s.liveTestingNotRefreshed.key
            } else {
                s.liveTestingRefreshedAt.key
            },
            text = if (data.refreshedAtText == null) {
                s.liveTestingNotRefreshed.text
            } else {
                s.liveTestingRefreshedAt.filled("time", data.refreshedAtText)
            },
        )
        nodes += SettingsGap("liveSelfCheck.gap.islandStatus")

        // ── 区块 4：时间校正（:985-1040）
        nodes += SettingsLabel(
            id = "liveSelfCheck.section.timeCorrection",
            textKey = s.timeCorrectionTitle.key,
            text = s.timeCorrectionTitle.text,
        )
        nodes += SettingsGroup(
            id = "liveSelfCheck.group.timeCorrection",
            children = listOf(timeCorrectionRow(data)),
        )
        nodes += SettingsGap("liveSelfCheck.gap.timeCorrection")

        // ── 区块 5：九块调试卡（:678-688，debugStatus 有值才出现）
        if (data.debugLoaded) {
            LiveDebugSection.entries.forEach { section ->
                val suffix = section.camelSuffix()
                nodes += SettingsLabel(
                    id = "liveSelfCheck.section.debug$suffix",
                    textKey = section.titleKey(),
                    text = section.titleText(),
                )
                nodes += SettingsGroup(
                    id = "liveSelfCheck.group.debug$suffix",
                    children = (data.debugSections[section] ?: emptyList()).mapIndexed { index, row ->
                        debugValueRow(section, suffix, index, row)
                    },
                )
                nodes += SettingsGap("liveSelfCheck.gap.debug$suffix")
            }
            // 原始 JSON 折叠卡（:1115-1148）；卡头被删，只有折叠项自己的两句
            nodes += SettingsInline(
                id = "liveSelfCheck.card.rawJson",
                kind = InlineKind.CONTROL_CARD,
                note = "原始 JSON 折叠块（:1115-1148）：官方 0.8.8 无折叠卡，见文件头口径 2",
                labelKey = s.liveTestingExpandRawJson.key,
                label = s.liveTestingExpandRawJson.text,
                valueKey = s.liveTestingExpandRawJsonSubtitle.key,
                value = s.liveTestingExpandRawJsonSubtitle.text,
                texts = listOf(SettingsInlineText(NON_ARB_TEXT, data.rawDebugJson)),
            )
            nodes += SettingsGap("liveSelfCheck.gap.rawJson")
        }

        // ── 区块 6：本地诊断日志（:1149-1183，永远最后且没有段后空档）
        nodes += SettingsInline(
            id = "liveSelfCheck.card.localLogs",
            kind = InlineKind.CONTROL_CARD,
            note = "本地诊断日志卡（:1149-1183）：副标题在 Dart 里被删（:1151 注释，" +
                "三个按钮里没有导出，文案与实际不符）",
            labelKey = s.liveTestingLocalLogsTitle.key,
            label = s.liveTestingLocalLogsTitle.text,
            texts = localLogButtons(data),
        )

        return SettingsPageSpec(
            id = ID,
            titleKey = s.liveSelfCheckTitle.key,
            title = s.liveSelfCheckTitle.text,
            nodes = nodes,
        )
    }

    // ------------------------------------------------------------------ 行构造

    /** 假期覆盖开关（:720-732）：标题与副标题都随开关态翻转。 */
    private fun holidaySwitchRow(data: LiveSelfCheckData): SettingsRow {
        val s = SettingsStringsExt3
        return settingsRow(
            id = "liveSelfCheck.holidaySwitch",
            component = MiuixRowComponent.SWITCH,
            title = if (data.holidayOverrideEnabled) {
                s.liveTestingHolidayModeEnabled
            } else {
                s.liveTestingHolidayModeDisabled
            },
            subtitle = if (data.holidayOverrideEnabled) {
                s.liveTestingHolidayModeEnabledDesc
            } else {
                s.liveTestingHolidayOverridePurpose
            },
            switchValue = data.holidayOverrideEnabled,
            action = SettingsAction.WRITE_SETTING,
        )
    }

    /** 自动刷新开关（:949-963）：开启时副标题带间隔秒数。 */
    private fun autoRefreshRow(data: LiveSelfCheckData): SettingsRow {
        val s = SettingsStringsExt3
        return settingsRow(
            id = "liveSelfCheck.island.autoRefresh",
            component = MiuixRowComponent.SWITCH,
            title = s.liveTestingAutoRefreshTitle,
            subtitle = if (data.autoRefreshEnabled) {
                s.liveTestingAutoRefreshOn.withArguments(
                    "seconds",
                    data.autoRefreshIntervalSeconds.toString(),
                )
            } else {
                s.liveTestingAutoRefreshOffReason
            },
            switchValue = data.autoRefreshEnabled,
            action = SettingsAction.WRITE_SETTING,
        )
    }

    /**
     * 时间校正滑杆（:995-1033）。
     *
     * 标题是 `timeCorrectionLabel` 填上读数后的整句（Dart 就是这么拼的），
     * 所以 `titleKey` 与 `title` 值不是 literal 相等——对拍测试按占位符片段比对。
     */
    private fun timeCorrectionRow(data: LiveSelfCheckData): SettingsRow {
        val s = SettingsStringsExt3
        val seconds = data.timeCorrectionSeconds
        return settingsRow(
            id = "liveSelfCheck.timeCorrection",
            component = MiuixRowComponent.SLIDER,
            title = s.timeCorrectionLabel.withArguments(
                "value",
                formatTimeCorrection(seconds),
            ),
            slider = SettingsSliderSpec(
                min = TIME_CORRECTION_MIN,
                max = TIME_CORRECTION_MAX,
                divisions = TIME_CORRECTION_DIVISIONS,
                defaultValue = 0.0,
                // Flutter `live_settings_subpages.dart:260-266`：这根滑杆带
                // `dialogTitle: timeCorrectionTitle` + `dialogHelper: timeCorrectionHelp`，
                // 点行/点读数会弹数值输入框。重构版此前只给了值、没给 helper，
                // 于是行尾没有箭头、点行没反应，`timeCorrectionHelp` 成了孤儿键。
                dialogHelperKey = s.timeCorrectionHelp.key,
                dialogHelper = s.timeCorrectionHelp.text,
            ),
            // :1001 `seconds.toDouble().clamp(-30, 30)`
            sliderValue = seconds.toDouble().coerceIn(TIME_CORRECTION_MIN, TIME_CORRECTION_MAX),
            action = SettingsAction.WRITE_SETTING,
        )
    }

    /** 诊断卡里的一条只读数据（`_DebugValueRow`，:1290-1325）。 */
    private fun debugValueRow(
        section: LiveDebugSection,
        suffix: String,
        index: Int,
        row: LiveDebugRow,
    ): SettingsRow = settingsRow(
        id = "liveSelfCheck.row.${section.name.lowercase()}.$index",
        component = MiuixRowComponent.ARROW,
        // 字段名是原生给的英文 key，不是 ARB 文案（:1214-1222 直接 toString）
        title = ArbText(NON_ARB_TEXT, row.label),
        valueKey = NON_ARB_TEXT,
        // :1278-1280 `isEmpty ? '-' : value`
        value = row.value.ifEmpty { "-" },
        // 纯展示行：不可点、无动作
        enabled = false,
    )

    // ------------------------------------------------------------------ 按钮组

    /**
     * 测试通知卡的动作区（:764-823）。
     *
     * 顺序即 Dart 自上而下：开始/取消测试 → 停止测试（有课中测试时）→ 选课测试
     * → 崩溃 / 卡顿（非 release）。
     */
    private fun notificationButtons(data: LiveSelfCheckData): List<SettingsInlineText> {
        val s = SettingsStringsExt3
        val out = mutableListOf<SettingsInlineText>()
        out += inline(
            if (data.sessionActive) s.liveTestingCancelAction else s.liveTestingStartAction,
        )
        if (data.courseTestLabel != null) {
            out += inline(s.liveTestingCourseTestStopAction)
        }
        out += inline(s.liveTestingCourseTestAction)
        if (!data.isReleaseBuild) {
            out += inline(s.liveTestingCrashAction)
            out += inline(s.liveTestingAnrAction)
        }
        return out
    }

    /** 上岛状态卡的两个动作（:914-941）：加载中/导出中分别换文案。 */
    private fun islandStatusButtons(data: LiveSelfCheckData): List<SettingsInlineText> {
        val s = SettingsStringsExt3
        val refresh = if (data.loadingDebugStatus) {
            s.liveTestingRefreshing
        } else {
            s.liveTestingRefreshAction
        }
        val export = if (data.exportingDiagnostics) {
            s.liveTestingExporting
        } else {
            s.liveTestingExportAction
        }
        return listOf(inline(refresh), inline(export))
    }

    /** 本地日志卡的三个动作（:1157-1179）。 */
    private fun localLogButtons(data: LiveSelfCheckData): List<SettingsInlineText> {
        val s = SettingsStringsExt3
        val clear = if (data.clearingDiagnostics) {
            s.liveTestingClearingLogs
        } else {
            s.liveTestingClearLogsAction
        }
        return listOf(
            inline(clear),
            inline(s.liveTestingViewPhoneLogsAction),
            inline(s.liveTestingMoreTesterOptionsAction),
        )
    }

    private fun inline(text: ArbText) = SettingsInlineText(text.key, text.text)

    // ------------------------------------------------------------ 不上岛原因

    /**
     * 不上岛原因的取值优先级（:904-912）：
     * 假期拦住 > 原生说空 > 原生原话。
     *
     * 假期那条是**上游门**：原生服务看不到 Dart 侧的假期判定，服务未运行时
     * 它只会兜底报「原生实时服务未运行」，把真正的假期原因藏在下游诊断里
     * （:838-841 注释，2026-08-30 OPPO 反馈）。
     */
    private fun noIslandReasonKey(data: LiveSelfCheckData): String = when {
        data.holidayBlocksIsland -> SettingsStringsExt3.liveTestingHolidayHidden.key
        data.notIslandReason.isEmpty() -> SettingsStringsExt3.liveTestingNoIslandReasonEmpty.key
        else -> NON_ARB_TEXT
    }

    private fun noIslandReasonText(data: LiveSelfCheckData): String = when {
        data.holidayBlocksIsland -> SettingsStringsExt3.liveTestingHolidayHidden.text
        data.notIslandReason.isEmpty() -> SettingsStringsExt3.liveTestingNoIslandReasonEmpty.text
        else -> data.notIslandReason
    }

    /**
     * 时间校正读数（`settings_shared.dart:25-33` 的 `formatLiveTimeCorrection`）。
     *
     * 三个分支：0 → 不矫正；正数 → 整体延后 N 秒；负数 → 整体提前 |N| 秒。
     */
    fun formatTimeCorrection(seconds: Int): String {
        val s = SettingsStringsExt3
        return when {
            seconds == 0 -> s.liveTimeCorrectionNone.text
            seconds > 0 -> s.liveTimeCorrectionDelay.filled("seconds", seconds.toString())
            else -> s.liveTimeCorrectionAdvance.filled("seconds", (-seconds).toString())
        }
    }

    internal fun format2(value: Double): String = "%.2f".format(Locale.ROOT, value)
}

/**
 * 自检页的九块调试卡（`settings_live.dart:1188-1203` 的 `_LiveTestingSection` 子集）。
 *
 * 顺序即 Dart 枚举顺序，也是屏上顺序。
 */
enum class LiveDebugSection {
    ENVIRONMENT,
    SERVICE,
    COURSE,
    TIMING,
    SWITCHES,
    DISPLAY,
    NOTIFICATION,
    RECENT_LOGS;

    /** `ENVIRONMENT` → `Environment`（节点 id 用）。 */
    fun camelSuffix(): String = name.lowercase().split('_').joinToString("") { part ->
        part.replaceFirstChar { it.uppercase() }
    }

    /** 卡标题的 ARB 键（:1041-1114 的八处 `l10n.liveTestingSection*`）。 */
    fun titleKey(): String = title().key

    fun titleText(): String = title().text

    private fun title(): ArbText = when (this) {
        ENVIRONMENT -> SettingsStringsExt3.liveTestingSectionEnvironment
        SERVICE -> SettingsStringsExt3.liveTestingSectionService
        COURSE -> SettingsStringsExt3.liveTestingSectionCourse
        TIMING -> SettingsStringsExt3.liveTestingSectionTiming
        SWITCHES -> SettingsStringsExt3.liveTestingSectionSwitches
        DISPLAY -> SettingsStringsExt3.liveTestingSectionDisplay
        NOTIFICATION -> SettingsStringsExt3.liveTestingSectionNotification
        RECENT_LOGS -> SettingsStringsExt3.liveTestingSectionRecentLogs
    }
}

/** 诊断卡里的一条原生字段（键 + 已格式化取值）。 */
data class LiveDebugRow(val label: String, val value: String)

/**
 * 自检页的运行时输入。
 *
 * 默认值按「刚进页面、还没拉到诊断」摆：非 release 构建、无会话、无课程测试、
 * 服务未运行、原因未知、自动刷新开着（Dart :189 `_autoRefreshEnabled = true`）。
 */
data class LiveSelfCheckData(
    /** 正式构建：假期覆盖与崩溃/卡顿按钮都不出现（:672 / :804）。 */
    val isReleaseBuild: Boolean = false,
    val holidayOverrideEnabled: Boolean = false, // timetable_settings.holidayOverrideEnabled 默认 false
    /** 自检测试会话（预设课覆盖层）是否挂着。 */
    val sessionActive: Boolean = false,
    /** 课中测试进行中的课程名；null = 没在测。 */
    val courseTestLabel: String? = null,
    val semesterUnset: Boolean = false,
    val serviceRunning: Boolean = false,
    val holidayBlocksIsland: Boolean = false,
    /** 原生给的不上岛原因；空串 = 「当前无拦截原因」。 */
    val notIslandReason: String = "",
    /** 原生给的上岛判定文字；空串 = 不渲染那颗芯片。 */
    val statusText: String = "",
    val loadingDebugStatus: Boolean = false,
    val exportingDiagnostics: Boolean = false,
    val clearingDiagnostics: Boolean = false,
    val autoRefreshEnabled: Boolean = true, // :189
    /** 已格式化的上次刷新时刻（`HH:mm:ss`）；null = 还没刷过。 */
    val refreshedAtText: String? = null,
    /** 自动刷新间隔秒数（:178 默认 1 秒）。 */
    val autoRefreshIntervalSeconds: Int = 1,
    /** `liveTimeCorrectionSeconds`，默认 0（`timetable_settings.dart:886`）。 */
    val timeCorrectionSeconds: Int = 0,
    /** 原生诊断是否已拉到（`_debugStatus != null`）。 */
    val debugLoaded: Boolean = false,
    val debugSections: Map<LiveDebugSection, List<LiveDebugRow>> = emptyMap(),
    /** 已格式化的原始诊断 JSON（`JsonEncoder.withIndent('  ')`，:634-636）。 */
    val rawDebugJson: String = "",
)
