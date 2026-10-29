package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.LenientJson

/**
 * 「超级岛 · 显示设置」与「提醒时段」两页的**读写层**（纯 Kotlin，零 Android 依赖）。
 *
 * ## 为什么需要这一层
 *
 * 两页的模型层（[LiveDisplayState] / [ReminderTimingState]）早就搬完了，
 * 但**没人负责读盘与落盘**：壳直接 `LiveDisplayState()` 起手，`onPersist` 是空实现
 * ⇒ 进页面永远看到默认值、改了也不留。本层补的就是这一段。
 *
 * ## 键名从哪来（三处必须一致，谁都不能自己改）
 *
 * 1. Dart 写侧：`lib/models/timetable_settings.dart:1145-1240`（`toJson`）；
 * 2. Dart 读侧：同文件 `:1544-1700`（`fromJson`，含逐字段回退规则）；
 * 3. **原生消费侧**：`LiveUpdateScheduler.kt:1610-1770` 用 `settingsJson.optXxx("live…")`
 *    真读这些键去下发超级岛。三处键名/枚举 wire 值本文件全部对齐；
 *    wire 值本身在 `lib/models/settings/timetable_settings_extensions.dart:140-290`。
 *
 * ## 两套键（本层最容易被写错的地方）
 *
 * Dart 的显示设置**不是一套字段**：
 *
 * - 上课前档 = `liveShowCourseName` …（`beforeClassDisplaySettings`）；
 * - 课中/下课档 = `liveDuringEndShowCourseName` …（`duringEndDisplaySettings`，`:2543-2573`）；
 * - `liveDuringEndFollowBeforeClass`（默认 `true`）为真时，课中档**就是**上课前档
 *   （`duringEndDisplaySettings => liveDuringEndFollowBeforeClass ? beforeClassDisplaySettings : …`）。
 *
 * Kotlin 的 [LiveDisplayState] 只有一套字段，所以本层按 `forDuringEnd` **选键组**：
 * 课中/下课页写 `liveDuringEnd*`，绝不把上课前档的设置写脏。
 * 课中档缺键时**逐字段回退**到上课前档（Dart `:1568-1680` 的 `?? lenient...(json['live...'])`），
 * 这条回退不是可选项：老存档里课中档那些键本来就不存在。
 *
 * ## 为什么写的是「补丁」不是整份 JSON
 *
 * `timetable_settings` 是 Dart 侧 250+ 字段的一个大 JSON 对象。
 * [TimetableStore.saveSettingsPatch] 是读-合并-写，本层只交出自己这几十个键
 * ⇒ 不会把主题、壁纸、同步配置这些别人的字段冲掉（单测里钉了这条）。
 */
class LiveDisplayStore(private val store: TimetableStore) {

    /** 读「显示设置」页的当前值；`forDuringEnd = true` 走课中/下课档键组。 */
    fun loadDisplay(forDuringEnd: Boolean): LiveDisplayState {
        val json = store.loadSettingsJson()
        return if (forDuringEnd) LiveDisplayCodec.readDuringEnd(json) else LiveDisplayCodec.readBeforeClass(json)
    }

    /** 写「显示设置」页；只覆盖本页拥有的键，盘上其余字段原样保留。 */
    fun saveDisplay(state: LiveDisplayState, forDuringEnd: Boolean) {
        val patch = if (forDuringEnd) {
            LiveDisplayCodec.duringEndPatch(state)
        } else {
            LiveDisplayCodec.beforeClassPatch(state)
        }
        store.saveSettingsPatch(patch)
    }

    /** 读「提醒时段」页当前值。 */
    fun loadReminderTiming(): ReminderTimingState =
        LiveDisplayCodec.readReminderTiming(store.loadSettingsJson())

    /** 写「提醒时段」页；同样只覆盖本页拥有的键。 */
    fun saveReminderTiming(state: ReminderTimingState) {
        store.saveSettingsPatch(LiveDisplayCodec.reminderTimingPatch(state))
    }
}

/**
 * `live*` 这批键的编解码（纯函数，无 IO，可直接 JVM 单测）。
 *
 * 读侧一律走 [LenientJson]（= Dart `lenient_json_readers.dart` 的 Kotlin 对应物）：
 * 有值就收、收不下按缺键，由调用方 `?: 默认值` 兜底，**绝不猜值**。
 */
object LiveDisplayCodec {

    // ── 上课前档（22 个显示字段）────────────────────────────────────
    const val KEY_SHOW_COURSE_NAME = "liveShowCourseName"
    const val KEY_SHOW_LOCATION = "liveShowLocation"
    const val KEY_SHOW_COUNTDOWN = "liveShowCountdown"
    const val KEY_COUNTDOWN_TEXT_STYLE = "liveCountdownTextStyle"
    const val KEY_SHOW_STAGE_TEXT = "liveShowStageText"
    const val KEY_USE_SHORT_NAME = "liveUseShortName"
    const val KEY_HIDE_PREFIX_TEXT = "liveHidePrefixText"
    const val KEY_DURING_CLASS_TIME_DISPLAY_MODE = "liveDuringClassTimeDisplayMode"
    const val KEY_ENABLE_LABEL_IMAGE = "liveEnableMiuiIslandLabelImage"
    const val KEY_LABEL_STYLE = "liveMiuiIslandLabelStyle"
    const val KEY_LABEL_CONTENT = "liveMiuiIslandLabelContent"
    const val KEY_LABEL_FONT_COLOR = "liveMiuiIslandLabelFontColor"
    const val KEY_LABEL_FONT_WEIGHT = "liveMiuiIslandLabelFontWeight"
    const val KEY_LABEL_RENDER_QUALITY = "liveMiuiIslandLabelRenderQuality"
    const val KEY_LABEL_FONT_SIZE = "liveMiuiIslandLabelFontSize"
    const val KEY_LABEL_OFFSET_X = "liveMiuiIslandLabelOffsetX"
    const val KEY_LABEL_OFFSET_Y = "liveMiuiIslandLabelOffsetY"
    const val KEY_LABEL_LOGO_PATH = "liveMiuiIslandLabelLogoPath"
    const val KEY_LABEL_LOGO_CORNER_RADIUS = "liveMiuiIslandLabelLogoCornerRadius"
    const val KEY_EXPANDED_ICON_MODE = "liveMiuiIslandExpandedIconMode"
    const val KEY_EXPANDED_ICON_PATH = "liveMiuiIslandExpandedIconPath"
    const val KEY_EXPANDED_DETAIL_FIELDS = "liveExpandedDetailFields"

    // ── 课中/下课档（22 个显示字段，前缀 liveDuringEnd）──────────────
    // 注意课中档的时间显示键叫 liveDuringEndTimeDisplayMode，
    // **不是** liveDuringEndDuringClassTimeDisplayMode——Dart `:1630` 与原生调度器都按前者读。
    const val KEY_DURING_END_SHOW_COURSE_NAME = "liveDuringEndShowCourseName"
    const val KEY_DURING_END_SHOW_LOCATION = "liveDuringEndShowLocation"
    const val KEY_DURING_END_SHOW_COUNTDOWN = "liveDuringEndShowCountdown"
    const val KEY_DURING_END_COUNTDOWN_TEXT_STYLE = "liveDuringEndCountdownTextStyle"
    const val KEY_DURING_END_SHOW_STAGE_TEXT = "liveDuringEndShowStageText"
    const val KEY_DURING_END_USE_SHORT_NAME = "liveDuringEndUseShortName"
    const val KEY_DURING_END_HIDE_PREFIX_TEXT = "liveDuringEndHidePrefixText"
    const val KEY_DURING_END_TIME_DISPLAY_MODE = "liveDuringEndTimeDisplayMode"
    const val KEY_DURING_END_ENABLE_LABEL_IMAGE = "liveDuringEndEnableMiuiIslandLabelImage"
    const val KEY_DURING_END_LABEL_STYLE = "liveDuringEndMiuiIslandLabelStyle"
    const val KEY_DURING_END_LABEL_CONTENT = "liveDuringEndMiuiIslandLabelContent"
    const val KEY_DURING_END_LABEL_FONT_COLOR = "liveDuringEndMiuiIslandLabelFontColor"
    const val KEY_DURING_END_LABEL_FONT_WEIGHT = "liveDuringEndMiuiIslandLabelFontWeight"
    const val KEY_DURING_END_LABEL_RENDER_QUALITY = "liveDuringEndMiuiIslandLabelRenderQuality"
    const val KEY_DURING_END_LABEL_FONT_SIZE = "liveDuringEndMiuiIslandLabelFontSize"
    const val KEY_DURING_END_LABEL_OFFSET_X = "liveDuringEndMiuiIslandLabelOffsetX"
    const val KEY_DURING_END_LABEL_OFFSET_Y = "liveDuringEndMiuiIslandLabelOffsetY"
    const val KEY_DURING_END_LABEL_LOGO_PATH = "liveDuringEndMiuiIslandLabelLogoPath"
    const val KEY_DURING_END_LABEL_LOGO_CORNER_RADIUS =
        "liveDuringEndMiuiIslandLabelLogoCornerRadius"
    const val KEY_DURING_END_EXPANDED_ICON_MODE = "liveDuringEndMiuiIslandExpandedIconMode"
    const val KEY_DURING_END_EXPANDED_ICON_PATH = "liveDuringEndMiuiIslandExpandedIconPath"
    const val KEY_DURING_END_EXPANDED_DETAIL_FIELDS = "liveDuringEndExpandedDetailFields"

    /** 「课中/下课页是否跟随上课前设置」（默认 `true`，两页共用）。 */
    const val KEY_DURING_END_FOLLOW_BEFORE_CLASS = "liveDuringEndFollowBeforeClass"

    // ── 两页共用 / 提醒时段用的顶层字段 ─────────────────────────────
    const val KEY_ENABLE_BEFORE_CLASS = "liveEnableBeforeClass"
    const val KEY_ENABLE_DURING_CLASS = "liveEnableDuringClass"
    const val KEY_ENABLE_BEFORE_END = "liveEnableBeforeEnd"
    const val KEY_PROMOTE_DURING_CLASS = "livePromoteDuringClass"
    const val KEY_SHOW_DURING_CLASS_NOTIFICATION = "liveShowDuringClassNotification"
    const val KEY_SHOW_BEFORE_CLASS_MINUTES = "liveShowBeforeClassMinutes"
    const val KEY_CLASS_REMINDER_START_MINUTES = "liveClassReminderStartMinutes"
    const val KEY_END_SECONDS_COUNTDOWN_THRESHOLD = "liveEndSecondsCountdownThreshold"
    const val KEY_BEFORE_CLASS_QUICK_ACTION = "liveBeforeClassQuickAction"
    const val KEY_BEFORE_CLASS_QUICK_ACTION_AUTO_MINUTES =
        "liveBeforeClassQuickActionAutoMinutes"

    // ══════════════════════════════ 读 ══════════════════════════════

    /** 上课前档（Dart `beforeClassDisplaySettings`，`:2515-2541`）。 */
    fun readBeforeClass(json: Map<String, Any?>): LiveDisplayState = LiveDisplayState(
        showCourseName = bool(json, KEY_SHOW_COURSE_NAME, true),
        showLocation = bool(json, KEY_SHOW_LOCATION, true),
        showCountdown = bool(json, KEY_SHOW_COUNTDOWN, true),
        countdownTextStyle = countdownTextStyle(json[KEY_COUNTDOWN_TEXT_STYLE]),
        showStageText = bool(json, KEY_SHOW_STAGE_TEXT, true),
        useShortName = bool(json, KEY_USE_SHORT_NAME, true),
        hidePrefixText = bool(json, KEY_HIDE_PREFIX_TEXT, true),
        duringClassTimeDisplayMode =
            LiveDuringClassTimeDisplayMode.fromValue(LenientJson.string(json[KEY_DURING_CLASS_TIME_DISPLAY_MODE])),
        enableMiuiIslandLabelImage = bool(json, KEY_ENABLE_LABEL_IMAGE, false),
        miuiIslandLabelStyle = labelStyle(json[KEY_LABEL_STYLE]),
        miuiIslandLabelContent = labelContent(json[KEY_LABEL_CONTENT]),
        miuiIslandLabelFontColor = LenientJson.string(json[KEY_LABEL_FONT_COLOR]) ?: "#FFFFFF",
        miuiIslandLabelFontWeight = labelFontWeight(json[KEY_LABEL_FONT_WEIGHT]),
        miuiIslandLabelRenderQuality = labelRenderQuality(json[KEY_LABEL_RENDER_QUALITY]),
        miuiIslandLabelFontSize = double(json, KEY_LABEL_FONT_SIZE, 14.0),
        miuiIslandLabelOffsetX = double(json, KEY_LABEL_OFFSET_X, 0.0),
        miuiIslandLabelOffsetY = double(json, KEY_LABEL_OFFSET_Y, 0.0),
        miuiIslandLabelLogoPath = LenientJson.string(json[KEY_LABEL_LOGO_PATH]),
        miuiIslandLabelLogoCornerRadius = double(json, KEY_LABEL_LOGO_CORNER_RADIUS, 8.0),
        miuiIslandExpandedIconMode = expandedIconMode(json[KEY_EXPANDED_ICON_MODE]),
        miuiIslandExpandedIconPath = LenientJson.string(json[KEY_EXPANDED_ICON_PATH]),
        expandedDetailFields = expandedFields(json[KEY_EXPANDED_DETAIL_FIELDS]),
        beforeClassQuickAction = quickAction(json[KEY_BEFORE_CLASS_QUICK_ACTION]),
        beforeClassQuickActionAutoMinutes = int(json, KEY_BEFORE_CLASS_QUICK_ACTION_AUTO_MINUTES, 0),
        duringEndFollowBeforeClass = bool(json, KEY_DURING_END_FOLLOW_BEFORE_CLASS, true),
        endSecondsCountdownThreshold = int(json, KEY_END_SECONDS_COUNTDOWN_THRESHOLD, 60),
        promoteDuringClass = bool(json, KEY_PROMOTE_DURING_CLASS, true),
    )

    /**
     * 课中/下课档（Dart `duringEndDisplaySettings`，`:2543-2573`）。
     *
     * **跟随开关为真时直接返回上课前档**（原版就是这么派生的），此时页面上那一组
     * 控件是禁用态，值必须与上课前档逐字一致，否则「跟随」看起来像没生效。
     *
     * 不跟随时按课中档自己那批键读，**缺键逐字段回退到上课前档**（Dart `:1568-1640`）：
     * 老存档里课中档那 20 多个键根本不存在，不回退就会把用户配置显示成默认值。
     */
    fun readDuringEnd(json: Map<String, Any?>): LiveDisplayState {
        val follow = bool(json, KEY_DURING_END_FOLLOW_BEFORE_CLASS, true)
        if (follow) {
            return readBeforeClass(json).copy(duringEndFollowBeforeClass = true)
        }
        return LiveDisplayState(
            showCourseName = boolWithFallback(json, KEY_DURING_END_SHOW_COURSE_NAME, KEY_SHOW_COURSE_NAME, true),
            showLocation = boolWithFallback(json, KEY_DURING_END_SHOW_LOCATION, KEY_SHOW_LOCATION, true),
            showCountdown = boolWithFallback(json, KEY_DURING_END_SHOW_COUNTDOWN, KEY_SHOW_COUNTDOWN, true),
            countdownTextStyle = countdownTextStyle(
                json[KEY_DURING_END_COUNTDOWN_TEXT_STYLE] ?: json[KEY_COUNTDOWN_TEXT_STYLE],
            ),
            showStageText = boolWithFallback(json, KEY_DURING_END_SHOW_STAGE_TEXT, KEY_SHOW_STAGE_TEXT, true),
            useShortName = boolWithFallback(json, KEY_DURING_END_USE_SHORT_NAME, KEY_USE_SHORT_NAME, true),
            hidePrefixText = boolWithFallback(json, KEY_DURING_END_HIDE_PREFIX_TEXT, KEY_HIDE_PREFIX_TEXT, true),
            duringClassTimeDisplayMode = LiveDuringClassTimeDisplayMode.fromValue(
                LenientJson.string(json[KEY_DURING_END_TIME_DISPLAY_MODE])
                    ?: LenientJson.string(json[KEY_DURING_CLASS_TIME_DISPLAY_MODE]),
            ),
            enableMiuiIslandLabelImage =
                boolWithFallback(json, KEY_DURING_END_ENABLE_LABEL_IMAGE, KEY_ENABLE_LABEL_IMAGE, false),
            miuiIslandLabelStyle = labelStyle(json[KEY_DURING_END_LABEL_STYLE] ?: json[KEY_LABEL_STYLE]),
            miuiIslandLabelContent = labelContent(json[KEY_DURING_END_LABEL_CONTENT] ?: json[KEY_LABEL_CONTENT]),
            miuiIslandLabelFontColor = LenientJson.string(json[KEY_DURING_END_LABEL_FONT_COLOR])
                ?: LenientJson.string(json[KEY_LABEL_FONT_COLOR])
                ?: "#FFFFFF",
            miuiIslandLabelFontWeight =
                labelFontWeight(json[KEY_DURING_END_LABEL_FONT_WEIGHT] ?: json[KEY_LABEL_FONT_WEIGHT]),
            miuiIslandLabelRenderQuality = labelRenderQuality(
                json[KEY_DURING_END_LABEL_RENDER_QUALITY] ?: json[KEY_LABEL_RENDER_QUALITY],
            ),
            miuiIslandLabelFontSize =
                doubleWithFallback(json, KEY_DURING_END_LABEL_FONT_SIZE, KEY_LABEL_FONT_SIZE, 14.0),
            miuiIslandLabelOffsetX =
                doubleWithFallback(json, KEY_DURING_END_LABEL_OFFSET_X, KEY_LABEL_OFFSET_X, 0.0),
            miuiIslandLabelOffsetY =
                doubleWithFallback(json, KEY_DURING_END_LABEL_OFFSET_Y, KEY_LABEL_OFFSET_Y, 0.0),
            miuiIslandLabelLogoPath = LenientJson.string(json[KEY_DURING_END_LABEL_LOGO_PATH])
                ?: LenientJson.string(json[KEY_LABEL_LOGO_PATH]),
            miuiIslandLabelLogoCornerRadius = doubleWithFallback(
                json,
                KEY_DURING_END_LABEL_LOGO_CORNER_RADIUS,
                KEY_LABEL_LOGO_CORNER_RADIUS,
                8.0,
            ),
            miuiIslandExpandedIconMode =
                expandedIconMode(json[KEY_DURING_END_EXPANDED_ICON_MODE] ?: json[KEY_EXPANDED_ICON_MODE]),
            miuiIslandExpandedIconPath = LenientJson.string(json[KEY_DURING_END_EXPANDED_ICON_PATH])
                ?: LenientJson.string(json[KEY_EXPANDED_ICON_PATH]),
            expandedDetailFields = expandedFields(
                json[KEY_DURING_END_EXPANDED_DETAIL_FIELDS] ?: json[KEY_EXPANDED_DETAIL_FIELDS],
            ),
            beforeClassQuickAction = quickAction(json[KEY_BEFORE_CLASS_QUICK_ACTION]),
            beforeClassQuickActionAutoMinutes =
                int(json, KEY_BEFORE_CLASS_QUICK_ACTION_AUTO_MINUTES, 0),
            duringEndFollowBeforeClass = false,
            endSecondsCountdownThreshold = int(json, KEY_END_SECONDS_COUNTDOWN_THRESHOLD, 60),
            promoteDuringClass = bool(json, KEY_PROMOTE_DURING_CLASS, true),
        )
    }

    /**
     * 提醒时段页（Dart `live_settings_subpages.dart:80-289` 的 `_draft` 初值，
     * 字段真值是 `timetable_settings.dart:1544-1690`）。
     *
     * ⚠️ 「课中与下课提醒」在 Dart 读侧有一处**迁移口径**（`:1551-1560`）：
     * 两个字段任一为 true 就都算 true——它们由同一个开关控制，只留一边为 true
     * 会让界面显示「关」而逻辑仍按「开」跑。这里逐字照抄，不「顺手修正」。
     */
    fun readReminderTiming(json: Map<String, Any?>): ReminderTimingState {
        val duringClass = LenientJson.bool(json[KEY_ENABLE_DURING_CLASS]) ?: true
        val beforeEnd = LenientJson.bool(json[KEY_ENABLE_BEFORE_END]) ?: true
        val duringClassMigrated = duringClass || beforeEnd
        return ReminderTimingState(
            liveEnableBeforeClass = bool(json, KEY_ENABLE_BEFORE_CLASS, true),
            liveEnableDuringClass = duringClassMigrated,
            liveEnableBeforeEnd = duringClassMigrated,
            liveClassReminderStartMinutes = int(json, KEY_CLASS_REMINDER_START_MINUTES, 0),
            liveShowDuringClassNotification = bool(json, KEY_SHOW_DURING_CLASS_NOTIFICATION, true),
            livePromoteDuringClass = bool(json, KEY_PROMOTE_DURING_CLASS, true),
            liveShowBeforeClassMinutes = int(json, KEY_SHOW_BEFORE_CLASS_MINUTES, 20),
            liveEndSecondsCountdownThreshold = int(json, KEY_END_SECONDS_COUNTDOWN_THRESHOLD, 60),
            liveDuringEndTimeDisplayMode = LiveDuringClassTimeDisplayMode.fromValue(
                LenientJson.string(json[KEY_DURING_END_TIME_DISPLAY_MODE])
                    ?: LenientJson.string(json[KEY_DURING_CLASS_TIME_DISPLAY_MODE]),
            ),
        )
    }

    // ══════════════════════════════ 写 ══════════════════════════════

    /**
     * 上课前档补丁。
     *
     * 包含「两页共用」的 4 个顶层键（快捷操作 / 自动分钟 / 秒级阈值 / 提升通知）：
     * 它们在 Dart 里本来就不是分档字段（`copyWithBeforeClassDisplaySettings` 一并写），
     * 而本页确实能改到它们。
     */
    fun beforeClassPatch(state: LiveDisplayState): Map<String, Any?> = linkedMapOf(
        KEY_SHOW_COURSE_NAME to state.showCourseName,
        KEY_SHOW_LOCATION to state.showLocation,
        KEY_SHOW_COUNTDOWN to state.showCountdown,
        KEY_COUNTDOWN_TEXT_STYLE to state.countdownTextStyle.wireValue(),
        KEY_SHOW_STAGE_TEXT to state.showStageText,
        KEY_USE_SHORT_NAME to state.useShortName,
        KEY_HIDE_PREFIX_TEXT to state.hidePrefixText,
        KEY_DURING_CLASS_TIME_DISPLAY_MODE to state.duringClassTimeDisplayMode.value,
        KEY_ENABLE_LABEL_IMAGE to state.enableMiuiIslandLabelImage,
        KEY_LABEL_STYLE to state.miuiIslandLabelStyle.wireValue(),
        KEY_LABEL_CONTENT to state.miuiIslandLabelContent.wireValue(),
        KEY_LABEL_FONT_COLOR to state.miuiIslandLabelFontColor,
        KEY_LABEL_FONT_WEIGHT to state.miuiIslandLabelFontWeight.wireValue(),
        KEY_LABEL_RENDER_QUALITY to state.miuiIslandLabelRenderQuality.wireValue(),
        KEY_LABEL_FONT_SIZE to state.miuiIslandLabelFontSize,
        KEY_LABEL_OFFSET_X to state.miuiIslandLabelOffsetX,
        KEY_LABEL_OFFSET_Y to state.miuiIslandLabelOffsetY,
        KEY_LABEL_LOGO_PATH to state.miuiIslandLabelLogoPath,
        KEY_LABEL_LOGO_CORNER_RADIUS to state.miuiIslandLabelLogoCornerRadius,
        KEY_EXPANDED_ICON_MODE to state.miuiIslandExpandedIconMode.wireValue(),
        KEY_EXPANDED_ICON_PATH to state.miuiIslandExpandedIconPath,
        KEY_EXPANDED_DETAIL_FIELDS to state.expandedDetailFields?.map { it.wireValue },
        KEY_BEFORE_CLASS_QUICK_ACTION to state.beforeClassQuickAction.wireValue(),
        KEY_BEFORE_CLASS_QUICK_ACTION_AUTO_MINUTES to state.beforeClassQuickActionAutoMinutes,
        KEY_DURING_END_FOLLOW_BEFORE_CLASS to state.duringEndFollowBeforeClass,
        KEY_END_SECONDS_COUNTDOWN_THRESHOLD to state.endSecondsCountdownThreshold,
        KEY_PROMOTE_DURING_CLASS to state.promoteDuringClass,
    )

    /**
     * 课中/下课档补丁。
     *
     * 写的是 `liveDuringEnd*` 那批键——**不是**上课前档，这是本页与「上课前档页」
     * 共用同一个 [LiveDisplayState] 时唯一的区分点。跟随开关本身也由本页写。
     *
     * ### 与 Dart 的一处**故意**差异
     *
     * Dart 关闭「跟随上课前设置」时只写 `liveDuringEndFollowBeforeClass: false`，
     * 课中档那些键若从没写过就还是缺的 ⇒ 关掉跟随那一刻，页面上的值会**突然跳成默认值**，
     * 而且退出去再进来也看到默认值（用户视角是「我刚设好的设置没了」）。
     * 本层把当前这组值整体写进课中档键：关掉跟随等于「把现在看到的这套固化下来」，
     * 满足台账 §1.1 的「回显」要求（改完再进来还是改后的值）。
     * 这是唯一一处与 Dart 不一致的写入口径，单测里单独钉了一条。
     */
    fun duringEndPatch(state: LiveDisplayState): Map<String, Any?> = linkedMapOf(
        KEY_DURING_END_SHOW_COURSE_NAME to state.showCourseName,
        KEY_DURING_END_SHOW_LOCATION to state.showLocation,
        KEY_DURING_END_SHOW_COUNTDOWN to state.showCountdown,
        KEY_DURING_END_COUNTDOWN_TEXT_STYLE to state.countdownTextStyle.wireValue(),
        KEY_DURING_END_SHOW_STAGE_TEXT to state.showStageText,
        KEY_DURING_END_USE_SHORT_NAME to state.useShortName,
        KEY_DURING_END_HIDE_PREFIX_TEXT to state.hidePrefixText,
        KEY_DURING_END_TIME_DISPLAY_MODE to state.duringClassTimeDisplayMode.value,
        KEY_DURING_END_ENABLE_LABEL_IMAGE to state.enableMiuiIslandLabelImage,
        KEY_DURING_END_LABEL_STYLE to state.miuiIslandLabelStyle.wireValue(),
        KEY_DURING_END_LABEL_CONTENT to state.miuiIslandLabelContent.wireValue(),
        KEY_DURING_END_LABEL_FONT_COLOR to state.miuiIslandLabelFontColor,
        KEY_DURING_END_LABEL_FONT_WEIGHT to state.miuiIslandLabelFontWeight.wireValue(),
        KEY_DURING_END_LABEL_RENDER_QUALITY to state.miuiIslandLabelRenderQuality.wireValue(),
        KEY_DURING_END_LABEL_FONT_SIZE to state.miuiIslandLabelFontSize,
        KEY_DURING_END_LABEL_OFFSET_X to state.miuiIslandLabelOffsetX,
        KEY_DURING_END_LABEL_OFFSET_Y to state.miuiIslandLabelOffsetY,
        KEY_DURING_END_LABEL_LOGO_PATH to state.miuiIslandLabelLogoPath,
        KEY_DURING_END_LABEL_LOGO_CORNER_RADIUS to state.miuiIslandLabelLogoCornerRadius,
        KEY_DURING_END_EXPANDED_ICON_MODE to state.miuiIslandExpandedIconMode.wireValue(),
        KEY_DURING_END_EXPANDED_ICON_PATH to state.miuiIslandExpandedIconPath,
        KEY_DURING_END_EXPANDED_DETAIL_FIELDS to state.expandedDetailFields?.map { it.wireValue },
        KEY_DURING_END_FOLLOW_BEFORE_CLASS to state.duringEndFollowBeforeClass,
        // 这两个键不分档：课中/下课页也能改，且改完两页都要看到（Dart 同一份 `_draft`）。
        KEY_END_SECONDS_COUNTDOWN_THRESHOLD to state.endSecondsCountdownThreshold,
        KEY_PROMOTE_DURING_CLASS to state.promoteDuringClass,
    )

    /** 提醒时段补丁。 */
    fun reminderTimingPatch(state: ReminderTimingState): Map<String, Any?> = linkedMapOf(
        KEY_ENABLE_BEFORE_CLASS to state.liveEnableBeforeClass,
        KEY_ENABLE_DURING_CLASS to state.liveEnableDuringClass,
        KEY_ENABLE_BEFORE_END to state.liveEnableBeforeEnd,
        KEY_CLASS_REMINDER_START_MINUTES to state.liveClassReminderStartMinutes,
        KEY_SHOW_DURING_CLASS_NOTIFICATION to state.liveShowDuringClassNotification,
        KEY_PROMOTE_DURING_CLASS to state.livePromoteDuringClass,
        KEY_SHOW_BEFORE_CLASS_MINUTES to state.liveShowBeforeClassMinutes,
        KEY_END_SECONDS_COUNTDOWN_THRESHOLD to state.liveEndSecondsCountdownThreshold,
        KEY_DURING_END_TIME_DISPLAY_MODE to state.liveDuringEndTimeDisplayMode.value,
    )

    // ══════════════════════════ 读侧小工具 ══════════════════════════

    private fun bool(json: Map<String, Any?>, key: String, fallback: Boolean): Boolean =
        LenientJson.bool(json[key]) ?: fallback

    private fun boolWithFallback(
        json: Map<String, Any?>,
        key: String,
        fallbackKey: String,
        fallback: Boolean,
    ): Boolean = LenientJson.bool(json[key]) ?: LenientJson.bool(json[fallbackKey]) ?: fallback

    private fun int(json: Map<String, Any?>, key: String, fallback: Int): Int {
        val raw = LenientJson.int(json[key]) ?: return fallback
        // 越界不静默回默认值：夹进 Int 区间（Dart 侧 int 是 64 位，不会溢出）。
        return raw.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
    }

    private fun double(json: Map<String, Any?>, key: String, fallback: Double): Double =
        LenientJson.double(json[key]) ?: fallback

    private fun doubleWithFallback(
        json: Map<String, Any?>,
        key: String,
        fallbackKey: String,
        fallback: Double,
    ): Double = LenientJson.double(json[key]) ?: LenientJson.double(json[fallbackKey]) ?: fallback

    private fun countdownTextStyle(raw: Any?): LiveCountdownTextStyle {
        val value = LenientJson.string(raw)
        return LiveCountdownTextStyle.entries.firstOrNull { it.wireValue() == value }
            ?: LiveCountdownTextStyle.SMART
    }

    private fun labelStyle(raw: Any?): MiuiIslandLabelStyle {
        val value = LenientJson.string(raw)
        return MiuiIslandLabelStyle.entries.firstOrNull { it.wireValue() == value }
            ?: MiuiIslandLabelStyle.TEXT_ONLY
    }

    private fun labelContent(raw: Any?): MiuiIslandLabelContent {
        val value = LenientJson.string(raw)
        return MiuiIslandLabelContent.entries.firstOrNull { it.wireValue() == value }
            ?: MiuiIslandLabelContent.COURSE_NAME
    }

    private fun labelFontWeight(raw: Any?): MiuiIslandLabelFontWeight {
        val value = LenientJson.string(raw)
        return MiuiIslandLabelFontWeight.entries.firstOrNull { it.wireValue() == value }
            ?: MiuiIslandLabelFontWeight.BOLD
    }

    private fun labelRenderQuality(raw: Any?): MiuiIslandLabelRenderQuality {
        val value = LenientJson.string(raw)
        return MiuiIslandLabelRenderQuality.entries.firstOrNull { it.wireValue() == value }
            ?: MiuiIslandLabelRenderQuality.STANDARD
    }

    private fun expandedIconMode(raw: Any?): MiuiIslandExpandedIconMode {
        val value = LenientJson.string(raw)
        return MiuiIslandExpandedIconMode.entries.firstOrNull { it.wireValue() == value }
            ?: MiuiIslandExpandedIconMode.APP_ICON
    }

    private fun quickAction(raw: Any?): LiveBeforeClassQuickAction {
        val value = LenientJson.string(raw)
        return LiveBeforeClassQuickAction.entries.firstOrNull { it.wireValue() == value }
            ?: LiveBeforeClassQuickAction.NONE
    }

    /**
     * 展开详情字段（Dart `parseLiveExpandedDetailFields`，`timetable_settings_live.dart:31-46`）。
     *
     * 两条语义必须原样保留：
     * - 非 List（未设置 / 老数据）→ `null` = **全部显示**（向后兼容）；
     * - List（含空列表）→ 对应顺序：空列表 = **全部隐藏**。
     *
     * 认不出的项**跳过**而不是整表退回 null：老版本写过已下线的字段名时，
     * 用户其余排序不该跟着丢。
     */
    private fun expandedFields(raw: Any?): List<LiveExpandedDetailField>? {
        val list = LenientJson.stringList(raw) ?: return null
        val out = ArrayList<LiveExpandedDetailField>(list.size)
        for (item in list) {
            LiveExpandedDetailField.entries.firstOrNull { it.wireValue == item }?.let(out::add)
        }
        return out
    }
}

// ══════════════════════ 枚举 ⇄ 磁盘 wire 值 ══════════════════════
// 值全部来自 Dart `timetable_settings_extensions.dart:140-290`，
// 也是原生 `LiveUpdateScheduler` 读到的字符串。**改动即等于让存量配置换档**，
// 其中 `LiveExpandedDetailField.wireValue` 已有自己的定义（复用，不重写）。

/** 倒计时格式的磁盘值（Dart `LiveCountdownTextStyleX.value`，`:153-170`）。 */
fun LiveCountdownTextStyle.wireValue(): String = when (this) {
    LiveCountdownTextStyle.SMART -> "smart"
    LiveCountdownTextStyle.SMART_MIN_S -> "smart_min_s"
    LiveCountdownTextStyle.MINUTE_SECOND_CN -> "minute_second_cn"
    LiveCountdownTextStyle.MINUTE_SECOND_COLON -> "minute_second_colon"
    LiveCountdownTextStyle.MINUTE_SECOND_MIN_S -> "minute_second_min_s"
    LiveCountdownTextStyle.MINUTE_SECOND_MIN_SLASH_S -> "minute_second_min_slash_s"
    LiveCountdownTextStyle.MINUTE_ONLY_CN -> "minute_only_cn"
    LiveCountdownTextStyle.MINUTE_ONLY_MIN -> "minute_only_min"
    LiveCountdownTextStyle.MINUTE_ONLY_SLASH -> "minute_only_slash"
    LiveCountdownTextStyle.SECOND_ONLY_CN -> "second_only_cn"
    LiveCountdownTextStyle.SECOND_ONLY_SHORT -> "second_only_short"
    LiveCountdownTextStyle.SECOND_ONLY_SLASH -> "second_only_slash"
}

/** 左侧图标样式的磁盘值（Dart `MiuiIslandLabelStyleX.value`，`:185-197`）。 */
fun MiuiIslandLabelStyle.wireValue(): String = when (this) {
    MiuiIslandLabelStyle.TEXT_ONLY -> "text_only"
    MiuiIslandLabelStyle.ICON_AND_TEXT -> "icon_and_text"
}

/** 左侧文字内容的磁盘值（Dart `MiuiIslandLabelContentX.value`，`:199-215`）。 */
fun MiuiIslandLabelContent.wireValue(): String = when (this) {
    MiuiIslandLabelContent.COURSE_NAME -> "course_name"
    MiuiIslandLabelContent.LOCATION -> "location"
    MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION -> "course_name_and_location"
}

/** 左侧文字字重的磁盘值（Dart `MiuiIslandLabelFontWeightX.value`，`:217-233`）。 */
fun MiuiIslandLabelFontWeight.wireValue(): String = when (this) {
    MiuiIslandLabelFontWeight.REGULAR -> "regular"
    MiuiIslandLabelFontWeight.MEDIUM -> "medium"
    MiuiIslandLabelFontWeight.BOLD -> "bold"
}

/** 左侧文字清晰度的磁盘值（Dart `MiuiIslandLabelRenderQualityX.value`，`:235-251`）。 */
fun MiuiIslandLabelRenderQuality.wireValue(): String = when (this) {
    MiuiIslandLabelRenderQuality.STANDARD -> "standard"
    MiuiIslandLabelRenderQuality.HIGH -> "high"
    MiuiIslandLabelRenderQuality.ULTRA -> "ultra"
}

/** 展开态大图标模式的磁盘值（Dart `MiuiIslandExpandedIconModeX.value`，`:253-270`）。 */
fun MiuiIslandExpandedIconMode.wireValue(): String = when (this) {
    MiuiIslandExpandedIconMode.APP_ICON -> "app_icon"
    MiuiIslandExpandedIconMode.CUSTOM_IMAGE -> "custom_image"
    MiuiIslandExpandedIconMode.HIDDEN -> "hidden"
}

/** 上课前快捷操作的磁盘值（Dart `LiveBeforeClassQuickActionX.value`，`:262-269`）。 */
fun LiveBeforeClassQuickAction.wireValue(): String = when (this) {
    LiveBeforeClassQuickAction.NONE -> "none"
    LiveBeforeClassQuickAction.SILENT -> "silent"
    LiveBeforeClassQuickAction.DO_NOT_DISTURB -> "do_not_disturb"
    LiveBeforeClassQuickAction.PRIORITY_ONLY -> "priority_only"
    LiveBeforeClassQuickAction.BOTH -> "both"
}
