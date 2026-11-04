package com.mutx163.qingyu.app

/**
 * 启动对账（settings → native pref **单向**）的纯决策 + 执行骨架。
 *
 * ## 为什么单独拆出来
 *
 * 原先这段 `if/else` 直接长在 `pages/ShellWiring.kt` 的初始化里，只有「编译通过」，
 * 没有任何 JVM 用例能钉住语义。这里把**判断**（settings 值 + 当前 pref → 动作）与
 * **副作用**（排/取消闹钟、写 pref）切成两半：决策是纯函数，副作用经 [PrefReconcilePort]
 * 注入，测试用假实现即可覆盖「差异才动、一致不动、缺键不动」三条口径。
 *
 * ## 语义（每一条都有对应用例）
 *
 * 1. settings 里有该键、且与 pref 不一致 ⇒ 执行一次对应动作；
 * 2. settings 里有该键、且与 pref 一致 ⇒ [PrefReconcileAction.NO_CHANGE]，**不产生副作用**
 *    （每次启动都重排闹钟是浪费，也会把上一次的触发点往后推）；
 * 3. settings 里**没有**该键 ⇒ [PrefReconcileAction.NO_CHANGE]，**不覆盖 pref**——
 *    旧版用户只写了 pref、Compose 新建档案还没有这个键，覆盖会把他们的开关静默关掉；
 * 4. 对同一份输入连续对账两次，第二次的动作集为空（幂等）。
 *
 * 周报的「开 / 关」在 pref 层有状态（`WeeklyReportScheduler.isEnabled`），所以关闭对应
 * [PrefReconcileAction.CANCEL_SCHEDULE]；`liveHideFromRecents` 的 pref 是纯值，差异只对应
 * [PrefReconcileAction.WRITE_PREF]。
 */
enum class PrefReconcileAction {
    /** 值缺失或与 pref 一致：什么都不做。 */
    NO_CHANGE,

    /** settings=true、pref=false：排下一次周报。 */
    ENABLE_SCHEDULE,

    /** settings=false、pref=true：取消周报。 */
    CANCEL_SCHEDULE,

    /** 与 pref 不一致：把值写回 native pref。 */
    WRITE_PREF,
}

/**
 * 启动对账要触碰的外部世界（`ShellWiring` 用真实实现，单测用假实现）。
 *
 * `weeklyReportEnabled` / `liveHideFromRecents` 各自读当前运行时值——决策必须**以现状**为基准，
 * 否则「一致就不动」这条根本无从判断。
 */
interface PrefReconcilePort {
    fun weeklyReportEnabled(): Boolean

    fun scheduleWeeklyReport()

    fun cancelWeeklyReport()

    fun liveHideFromRecents(): Boolean

    fun writeLiveHideFromRecents(value: Boolean)
}

object NativePrefReconcileLogic {

    /** settings JSON 里的键（`lib/models/timetable_settings.dart` 同名）。 */
    const val KEY_WEEKLY_REPORT_ENABLED = "weeklyReportEnabled"
    const val KEY_LIVE_HIDE_FROM_RECENTS = "liveHideFromRecents"

    /**
     * 周报开关的决策。
     *
     * @param settingsValue settings JSON 里的值；null = 键不存在（旧档 / 新建档案未写过）。
     * @param currentPref 当前 `WeeklyReportScheduler` 里的开关状态。
     */
    fun decideWeeklyReport(
        settingsValue: Boolean?,
        currentPref: Boolean,
    ): PrefReconcileAction = when {
        settingsValue == null -> PrefReconcileAction.NO_CHANGE
        settingsValue == currentPref -> PrefReconcileAction.NO_CHANGE
        settingsValue -> PrefReconcileAction.ENABLE_SCHEDULE
        else -> PrefReconcileAction.CANCEL_SCHEDULE
    }

    /**
     * 「从最近任务隐藏」开关的决策。
     *
     * @param settingsValue settings JSON 里的值；null = 键不存在。
     * @param currentPref 当前 `native_runtime_prefs` / `hide_from_recents` 的值。
     */
    fun decideLiveHideFromRecents(
        settingsValue: Boolean?,
        currentPref: Boolean,
    ): PrefReconcileAction = when {
        settingsValue == null -> PrefReconcileAction.NO_CHANGE
        settingsValue == currentPref -> PrefReconcileAction.NO_CHANGE
        else -> PrefReconcileAction.WRITE_PREF
    }

    /**
     * 对一份 settings 快照执行启动对账。
     *
     * @return 本次**真正执行**的动作（顺序固定：周报在前，隐藏任务在後）。
     *         第二次对同一份快照调用时返回空表——这就是幂等的可断言形态。
     */
    fun reconcile(
        settings: Map<String, Any?>,
        port: PrefReconcilePort,
    ): List<PrefReconcileAction> {
        val applied = ArrayList<PrefReconcileAction>(2)

        val weeklyValue = settings[KEY_WEEKLY_REPORT_ENABLED] as? Boolean
        when (decideWeeklyReport(weeklyValue, port.weeklyReportEnabled())) {
            PrefReconcileAction.ENABLE_SCHEDULE -> {
                port.scheduleWeeklyReport()
                applied += PrefReconcileAction.ENABLE_SCHEDULE
            }
            PrefReconcileAction.CANCEL_SCHEDULE -> {
                port.cancelWeeklyReport()
                applied += PrefReconcileAction.CANCEL_SCHEDULE
            }
            PrefReconcileAction.NO_CHANGE,
            PrefReconcileAction.WRITE_PREF,
            -> Unit
        }

        val hideValue = settings[KEY_LIVE_HIDE_FROM_RECENTS] as? Boolean
        when (decideLiveHideFromRecents(hideValue, port.liveHideFromRecents())) {
            PrefReconcileAction.WRITE_PREF -> {
                // 决策只在「值存在且与 pref 不同」时返回 WRITE_PREF，hideValue 必非 null。
                port.writeLiveHideFromRecents(hideValue == true)
                applied += PrefReconcileAction.WRITE_PREF
            }
            PrefReconcileAction.NO_CHANGE,
            PrefReconcileAction.ENABLE_SCHEDULE,
            PrefReconcileAction.CANCEL_SCHEDULE,
            -> Unit
        }

        return applied
    }
}
