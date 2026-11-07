package com.mutx163.qingyu.pages.statistics

/**
 * 周报开关的**写路径顺序与补偿**（2026-11-05）。
 *
 * ## 它解决什么
 *
 * 原先壳里的回调是「先写 settings、再排调度」：调度那一步抛错时偏好已经写进去了，界面回滚成
 * 「关」，而盘上是「开」——下次进设置页又跳回「开」，用户看到的是「我关掉的开关自己开了」。
 *
 * 还有更值钱的一条：`scheduleNext` 本身几乎不抛，真正的失败源是 **Android 13+ 通知不可达**
 * （权限没给 / 应用通知被关 / 周报渠道被静默）。此时 `notify()` 会被系统**静默丢弃**，
 * 用户「开了周报却永远收不到」，界面还显示已开启 ⇒ 那就是个假开关。
 *
 * ## 顺序（本文件是唯一真源，壳只负责注入真实副作用）
 *
 * 打开：
 * 1. `canDeliver()` 为假 ⇒ 抛 [WeeklyReportNotificationUnavailableException]，**不写任何状态**；
 * 2. 调度成功后才写 settings；
 * 3. settings 写失败 ⇒ 用 `cancel()` 撤销刚排上的，再抛（页面回滚 UI）。
 *
 * 关闭：
 * 1. `cancel()`（幂等）；
 * 2. settings 写失败 ⇒ 用**开头算好的同一组值** `scheduleNext(planned)` 补偿回写，再抛。
 *
 * ## 为什么「开头算一次」
 *
 * `fireAt` / `title` / `body` 由快照派生、同一次调用内恒定；初始调度与失败补偿复用同一组值，
 * 回滚的就是「关掉之前本来生效的那一组」，与周日 21:00 的边界没有关系，也不需要给
 * `WeeklyReportScheduler` 加只读访问器。
 *
 * ## 副作用全注入
 *
 * 三段副作用（调度 / 撤销 / 写 settings）都由调用方传进来 ⇒ 本文件是纯逻辑，JVM 直测顺序、
 * 「不可达时一个字都不写」与两条补偿路径；真机行为仍需 L2 / 真机确认。
 */
object WeeklyReportToggleLogic {

    /** 一次调度要用的全部值（算一次，初始调度与补偿复用）。 */
    data class Plan(
        val fireAtMillis: Long,
        val title: String,
        val body: String,
    )

    /**
     * 执行一次开关切换；失败以异常抛出，由页面 catch 后回滚 UI 并按异常类型选文案。
     *
     * @param enabled 用户想要的目标状态。
     * @param plan 计算这次要排的触发时刻与通知文案（恒调用一次）。
     * @param canDeliver 系统此刻能不能真的投递通知；只在打开时查。
     * @param scheduleNext 排闹钟 + 落调度器自己的 prefs（`WeeklyReportScheduler.scheduleNext`）。
     * @param cancel 撤销闹钟 + 清调度器 prefs（幂等）。
     * @param writeSettings 写 settings 里的 `weeklyReportEnabled`（唯一真源）。
     */
    fun applyToggle(
        enabled: Boolean,
        plan: () -> Plan,
        canDeliver: () -> Boolean,
        scheduleNext: (Plan) -> Unit,
        cancel: () -> Unit,
        writeSettings: (Boolean) -> Unit,
    ) {
        // ① 通知送不到就拒绝打开：不排调度、不写 settings、不动任何状态。
        if (enabled && !canDeliver()) {
            throw WeeklyReportNotificationUnavailableException()
        }

        // 开头算一次；下面两条路径（正常调度 / 失败补偿）复用同一组值。
        val planned = plan()

        if (enabled) {
            // ② 先调度：这一步抛错时 settings 还没被碰过，页面回滚即真实状态。
            scheduleNext(planned)
            try {
                writeSettings(true)
            } catch (error: Throwable) {
                // ③ settings 写失败：撤销刚排上的闹钟，别留下「偏好是关、闹钟还在」的幽灵。
                runCatching { cancel() }
                throw error
            }
            return
        }

        // 关闭：先撤（幂等），再写 settings。
        cancel()
        try {
            writeSettings(false)
        } catch (error: Throwable) {
            // 补偿回写：把「关掉之前本来生效的那一组」排回去（scheduleNext 幂等，重放安全）。
            runCatching { scheduleNext(planned) }
            throw error
        }
    }
}
