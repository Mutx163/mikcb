package com.mutx163.qingyu.pages.live

import kotlin.math.abs

/**
 * 「提醒时间」子屏状态（模型层，纯 Kotlin，零 Android 依赖）。
 *
 * 对应 Flutter `lib/screens/live_settings_subpages.dart:80-289` 的
 * `_LiveReminderTimingScreenState._draft`；字段真值来自
 * `lib/models/timetable_settings.dart` 的 `live*` 字段（构造默认值见该文件
 * `:830-885`）。这里只放本页能改到的 9 个字段，其余字段由宿主持有。
 */
data class ReminderTimingState(
    /** 「上课前提醒」开关（Dart `liveEnableBeforeClass`，默认 true）。 */
    val liveEnableBeforeClass: Boolean = true,
    /** 「课中与下课提醒」开关的左半（Dart `liveEnableDuringClass`，默认 true）。 */
    val liveEnableDuringClass: Boolean = true,
    /** 「课中与下课提醒」开关的右半（Dart `liveEnableBeforeEnd`，默认 true）。 */
    val liveEnableBeforeEnd: Boolean = true,
    /** 「重点提醒切入时机」：0=一上课就切换，其余=下课前 N 分钟（Dart `liveClassReminderStartMinutes`，默认 0）。 */
    val liveClassReminderStartMinutes: Int = 0,
    /** 「课中状态栏通知」开关（Dart `liveShowDuringClassNotification`，默认 true）。 */
    val liveShowDuringClassNotification: Boolean = true,
    /** 「展示超级岛」开关（Dart `livePromoteDuringClass`，默认 true）。 */
    val livePromoteDuringClass: Boolean = true,
    /** 「上课前弹出时间」分钟数（Dart `liveShowBeforeClassMinutes`，默认 20，取值见 [ReminderTimingLogic.BEFORE_CLASS_MINUTES_OPTIONS]）。 */
    val liveShowBeforeClassMinutes: Int = 20,
    /** 「下课前秒级阈值」（Dart `liveEndSecondsCountdownThreshold`，默认 60，取值见 [ReminderTimingLogic.END_SECONDS_OPTIONS]）。 */
    val liveEndSecondsCountdownThreshold: Int = 60,
    /** 「课中时间样式」（Dart `liveDuringEndTimeDisplayMode`，默认 nearest）。 */
    val liveDuringEndTimeDisplayMode: LiveDuringClassTimeDisplayMode =
        LiveDuringClassTimeDisplayMode.NEAREST,
)

// `LiveDuringClassTimeDisplayMode` 统一定义在 DisplaySettingsModel.kt（同包共用，避免重复声明）。

/**
 * 「重点提醒切入时机」右侧当前效果摘要的四种口径。
 *
 * 对应 Dart `_buildLiveClassReminderLeadSummary`（`live_settings_subpages.dart:50-67`）：
 * 只描述「怎么切」，不重复具体分钟/秒数——那两个值就在本页「时间阈值」组里。
 * 渲染层据此查 [ReminderTimingStrings.leadSummaryText]。
 */
enum class ReminderLeadSummary {
    /** 一上课就切重点提醒（`liveClassReminderStartMinutes == 0`）。 */
    IMMEDIATE,

    /** 课中普通通知，下课前切重点提醒。 */
    KEEP_NORMAL,

    /** 课中普通通知，下课前切超级岛。 */
    ISLAND,

    /** 下课前才开始重点提醒。 */
    FOCUSED,
}

/**
 * 「课中状态栏通知」行副标题的三种口径。
 *
 * 对应 Dart 渲染层里的内联三元（`live_settings_subpages.dart:176-180`）：
 * 按切入时机与「展示超级岛」开关选一句。渲染层据此查
 * [ReminderTimingStrings.duringClassStatusHintText]。
 */
enum class DuringClassStatusHint {
    /** 保留状态栏通知（切入时机 = 一上课就切换）。 */
    KEEP_STATUS_NOTIFICATION,

    /** 重点提醒前用普通通知（切入时机非 0 且开启了超级岛）。 */
    NORMAL_THEN_LEAD,

    /** 全程显示普通通知（切入时机非 0 且未开超级岛）。 */
    PERSISTENT,
}

/**
 * 「提醒时间」子屏纯逻辑（零 IO、确定性，全部有手推期望值的单测）。
 *
 * 逐字对齐 Flutter `_LiveReminderTimingScreenState`（`live_settings_subpages.dart:80-289`）：
 * - 开关联动：[isDuringClassReminderEnabled] / [withDuringClassReminderEnabled]（Dart `:118-149`）；
 * - 切入时机摘要：[resolveLeadSummary]（Dart `_buildLiveClassReminderLeadSummary` `:50-67`）；
 * - 通知行副标题：[resolveDuringClassStatusHint]（Dart `:176-180`）；
 * - 取值边界：[snapToOption] / [clampBeforeClassMinutes] / [sanitize]。
 */
object ReminderTimingLogic {

    /** 切入时机可选分钟（Dart `:155-162` 的 items 值集：0/5/10/15/20/30）。 */
    val CLASS_REMINDER_START_MINUTES: List<Int> = listOf(0, 5, 10, 15, 20, 30)

    /** 上课前弹出时间可选分钟（Dart `_beforeClassMinutesOptions` `:81-91`）。 */
    val BEFORE_CLASS_MINUTES_OPTIONS: List<Int> = listOf(1, 5, 10, 15, 20, 30, 40, 50, 60)

    /** 下课前秒级阈值可选秒（Dart `_endSecondsOptions` `:92`）。 */
    val END_SECONDS_OPTIONS: List<Int> = listOf(15, 30, 45, 60, 90)

    /** 上课前弹出时间的合法闭区间下界（字段口径 1..60）。 */
    const val BEFORE_CLASS_MINUTES_MIN: Int = 1

    /** 上课前弹出时间的合法闭区间上界。 */
    const val BEFORE_CLASS_MINUTES_MAX: Int = 60

    /**
     * 「课中与下课提醒」开关的显示值 / 生效判据：
     * Dart `_draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd`（`live_settings_subpages.dart:118-119`）。
     *
     * 期望值（手推）：
     * - `(false, false)` -> false
     * - `(true,  false)` -> true
     * - `(false, true )` -> true
     * - `(true,  true )` -> true
     */
    fun isDuringClassReminderEnabled(state: ReminderTimingState): Boolean =
        state.liveEnableDuringClass || state.liveEnableBeforeEnd

    /**
     * 拨动「课中与下课提醒」开关：Dart `copyWith(liveEnableDuringClass: value, liveEnableBeforeEnd: value)`
     * （`live_settings_subpages.dart:144-149`）——两个字段一起写，保持开关值即 OR 判据。
     */
    fun withDuringClassReminderEnabled(
        state: ReminderTimingState,
        enabled: Boolean,
    ): ReminderTimingState = state.copy(
        liveEnableDuringClass = enabled,
        liveEnableBeforeEnd = enabled,
    )

    /**
     * 「重点提醒切入时机」下拉行是否出现：Dart `if (duringClassEnabled)`（`live_settings_subpages.dart:151`）。
     * 课中/下课提醒全关时，切入时机没有意义，整行隐藏。
     */
    fun shouldShowLeadSelect(state: ReminderTimingState): Boolean =
        isDuringClassReminderEnabled(state)

    /**
     * 切入时机摘要口径，逐字照抄 Dart `_buildLiveClassReminderLeadSummary`（`:50-67`）。
     *
     * 注意第 2/3 条判据用的是 **`liveEnableDuringClass`** 单字段，而不是上面的 OR 判据
     * ——原版就是这么写的，这里保持一致，不做「顺手修正」。
     *
     * 期望值（手推）：
     * - `startMinutes == 0`，其余任意 -> IMMEDIATE
     * - `startMinutes != 0, duringClass=true, show=true,  promote=false` -> KEEP_NORMAL
     * - `startMinutes != 0, duringClass=true, show=true,  promote=true ` -> ISLAND
     * - `startMinutes != 0, duringClass=true, show=false, promote=任意 ` -> FOCUSED
     * - `startMinutes != 0, duringClass=false`（即便 beforeEnd=true）-> FOCUSED
     */
    fun resolveLeadSummary(state: ReminderTimingState): ReminderLeadSummary {
        if (state.liveClassReminderStartMinutes == 0) {
            return ReminderLeadSummary.IMMEDIATE
        }
        if (state.liveEnableDuringClass &&
            state.liveShowDuringClassNotification &&
            !state.livePromoteDuringClass
        ) {
            return ReminderLeadSummary.KEEP_NORMAL
        }
        if (state.liveEnableDuringClass && state.liveShowDuringClassNotification) {
            return ReminderLeadSummary.ISLAND
        }
        return ReminderLeadSummary.FOCUSED
    }

    /**
     * 「课中状态栏通知」行副标题口径，逐字照抄 Dart `:176-180` 的三元。
     *
     * 期望值（手推）：
     * - `startMinutes == 0` -> KEEP_STATUS_NOTIFICATION（优先于 promote 判据）
     * - `startMinutes != 0, promote=true ` -> NORMAL_THEN_LEAD
     * - `startMinutes != 0, promote=false` -> PERSISTENT
     */
    fun resolveDuringClassStatusHint(state: ReminderTimingState): DuringClassStatusHint = when {
        state.liveClassReminderStartMinutes == 0 -> DuringClassStatusHint.KEEP_STATUS_NOTIFICATION
        state.livePromoteDuringClass -> DuringClassStatusHint.NORMAL_THEN_LEAD
        else -> DuringClassStatusHint.PERSISTENT
    }

    /** 上课前弹出时间的显式区间 clamp（口径 1..60）。 */
    fun clampBeforeClassMinutes(value: Int): Int =
        value.coerceIn(BEFORE_CLASS_MINUTES_MIN, BEFORE_CLASS_MINUTES_MAX)

    /**
     * 把任意整数贴到最近的合法选项上（下拉只能选这些值，落库值若越界会让下拉选空）。
     *
     * 命中直接返回；否则取绝对差最小的选项；**并列时取较小者**（选项升序 + `minByOrNull`
     * 返回首个最小值，故结果确定）。空选项表原样返回。
     */
    fun snapToOption(value: Int, options: List<Int>): Int {
        if (options.isEmpty()) return value
        if (value in options) return value
        return options.minByOrNull { abs(it - value) } ?: value
    }

    /** 切入时机贴到 [CLASS_REMINDER_START_MINUTES] 上。 */
    fun snapClassReminderStartMinutes(value: Int): Int =
        snapToOption(value, CLASS_REMINDER_START_MINUTES)

    /** 上课前弹出时间贴到 [BEFORE_CLASS_MINUTES_OPTIONS] 上。 */
    fun snapBeforeClassMinutes(value: Int): Int =
        snapToOption(value, BEFORE_CLASS_MINUTES_OPTIONS)

    /** 下课前秒级阈值贴到 [END_SECONDS_OPTIONS] 上。 */
    fun snapEndSecondsThreshold(value: Int): Int =
        snapToOption(value, END_SECONDS_OPTIONS)

    /**
     * 把外部传入的状态清洗成可安全渲染的形态：三个整数字段贴到各自合法选项上。
     *
     * 为什么用「贴选项」而不是单纯区间 clamp：本页三个时间控件都是下拉，
     * 一旦当前值不在选项集里，下拉的当前项就会落空。布尔与枚举不变（枚举本身合法）。
     */
    fun sanitize(state: ReminderTimingState): ReminderTimingState = state.copy(
        liveClassReminderStartMinutes =
            snapClassReminderStartMinutes(state.liveClassReminderStartMinutes),
        liveShowBeforeClassMinutes =
            snapBeforeClassMinutes(state.liveShowBeforeClassMinutes),
        liveEndSecondsCountdownThreshold =
            snapEndSecondsThreshold(state.liveEndSecondsCountdownThreshold),
    )
}
