package com.mutx163.qingyu.pages.import

/**
 * 导入入口页（「导入课程」方式页）对「子页导入成功」信号的**三态决策**（纯函数，JVM 可测）。
 *
 * ## 为什么三态（J8 / J11，2026-11-10 评审六推翻两输入方案）
 *
 * 发布版入口页靠 `Navigator.pop(true)` 的**返回值**自关：只有它自己 push 出去的子页成功
 * 返回 true 才关。Compose 侧没有返回值，只有进程级代数（[ImportShellBridge.importGeneration]）。
 * 关键事实：**正常流程与外部入口流程在入口页眼里输入完全相同**——都被子页盖住
 * （`pageResumed=false`）、子页成功后 `markImported()` 紧接 `onBack()` 弹自己、入口页回前台
 * 且代数增长。两者要的结果却相反：
 *
 * | 流程 | 谁推的子页 | 发布版结果 | 期望 |
 * |---|---|---|---|
 * | 入口页 → 选 ICS/表格/识图/教务 → 导入成功 | **入口页自己** | `pop(true)` 为真 | 入口页自关 |
 * | 外部「打开方式」分享 .ics（壳 pushPage 压在入口页上） | **壳** | 返回无人消费 | 停在入口页 |
 *
 * 所以必须补一个「本页自己推的子页」状态位（[awaitingMyChild]），它的来源是入口页的
 * 四个导航分支；外部入口路径不经过那里，天然为 false。
 *
 * ## 三态
 *
 * - **Consume**：`awaitingMyChild && pageResumed && importGeneration > baseline`
 *   —— 自己的子页回来了且本页在前台：推进基线 + `onBack()`；
 * - **Wait**：`awaitingMyChild && !pageResumed` —— 自己的子页还在上面（正常流程里子页刚弹、本页
 *   还没回到 RESUMED）：**不推进基线**，回前台再判（正常流程的自关全靠这一条）；
 * - **Ignore**：其余（含「不是本页推的子页，即外部入口」被盖住）：推进基线、不消费。
 */
object ImportEntrySignalLogic {

    enum class Decision {
        /** 消费：推进基线 + `onBack()`。 */
        Consume,

        /** 等：**不推进基线**，等本页回到 RESUMED 再判。 */
        Wait,

        /** 忽略：推进基线、不消费（外部入口推来的那一页的结果不属于本页）。 */
        Ignore,
    }

    /**
     * @param awaitingMyChild 本页是否自己 push 过导入子页且还没处理完它的结果
     * @param pageResumed 入口页是否 RESUMED（导航条目级生命周期）
     * @param importGeneration 当前「导入成功」代数
     * @param importGenerationAtMount 本页基线（挂载时 / 上次处理到的代数）
     */
    fun decide(
        awaitingMyChild: Boolean,
        pageResumed: Boolean,
        importGeneration: Int,
        importGenerationAtMount: Int,
    ): Decision = when {
        awaitingMyChild && pageResumed && importGeneration > importGenerationAtMount -> Decision.Consume
        awaitingMyChild && !pageResumed -> Decision.Wait
        else -> Decision.Ignore
    }

    /**
     * 决策之后的新基线：**只有 [Decision.Wait] 不推进**（其余两种都推进，防止回到前台补触发）。
     *
     * 把「推进基线」也收进纯函数，避免「调用方到底推没推」只靠源码守卫行锚证明。
     */
    fun baselineAfter(
        decision: Decision,
        importGeneration: Int,
        importGenerationAtMount: Int,
    ): Int = when (decision) {
        Decision.Wait -> importGenerationAtMount
        Decision.Consume, Decision.Ignore -> importGeneration
    }
}
