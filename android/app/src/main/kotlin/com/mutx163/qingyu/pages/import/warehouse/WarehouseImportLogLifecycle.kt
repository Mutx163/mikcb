package com.mutx163.qingyu.pages.import.warehouse

/**
 * 导入日志 run 生命周期的**唯一接线点**（宿主只调四个方法）。
 *
 * ## 为什么要有这一层
 *
 * `WarehouseImportLogBuffer` 的 `beginRun` / `markEnd` / `markFailure` / `reset` 此前只有单测
 * 在调，生产代码零调用（2026-11-14 复核）⇒ 表头 `school` / `adapter` 恒空、`verdict` 永远
 * `running`、「失败」也被算成运行中、`endReason` 恒空、几次尝试全挤进同一个 `auto-N`。
 * 把「什么时候开一轮、什么时候收尾」收在**一个纯 Kotlin 对象**里，宿主侧只剩调用点，
 * 语义可以进 L0 单测，不需要真机。
 *
 * ## 三个语义（改之前先读）
 *
 * 1. **一个导入会话 = 同学校 + 同适配器**。会话第一次开始时 [beginSession] 换一只空 buffer；
 *    同一会话内重试（超时重试、回放重试、页面重进）**不清**，失败那一轮的现场与首条都还在。
 * 2. **每次「执行导入脚本」= 一轮 run**，runId 单调递增（`run-1` / `run-2` …），不再落进
 *    `auto-N`：`auto-N` 只给「没显式开轮就来的记录」兜底，表头字段永远是空的。
 * 3. [endIfOpen] / [failIfOpen] **只作用于还开着的那一轮**。`complete` 可能在「本轮已定局」
 *    之后才到（N10）——那时再 `markEnd` 会把已经写好的成功/失败改写成一个更晚的结论。
 *
 * 纯 JVM：不 import `android.*`，L0 直接可测。
 */
object WarehouseImportLogLifecycle {

    /** 显式 run 的 id 前缀（与 buffer 里兜底用的 `auto-` 区分，导出表头一眼能认）。 */
    const val RUN_ID_PREFIX: String = "run-"

    private var sessionKey: String? = null
    private var runCounter = 0

    /**
     * 进入 / 切到某个导入会话（键用 `schoolId/adapterId`）。
     *
     * 只有键真的变了才 `reset`：同一个导入目标重进页面时，面板里上一轮的现场仍然在；
     * 换学校 / 换适配器才是新会话，旧会话的证据已随收尾写进 `last.txt` 与应用日志。
     */
    @Synchronized
    fun beginSession(key: String) {
        if (sessionKey == key) return
        sessionKey = key
        runCounter = 0
        WarehouseImportLog.reset()
    }

    /**
     * 开一轮（每次执行导入脚本各算一轮）。
     *
     * @return 本轮 runId（`run-N`），便于日志与测试定位
     */
    @Synchronized
    fun beginAttempt(schoolName: String, adapterId: String): String {
        runCounter += 1
        val runId = "$RUN_ID_PREFIX$runCounter"
        WarehouseImportLog.beginRun(runId, schoolName, adapterId)
        return runId
    }

    /**
     * 正常收尾：只收**还没收尾**的那一轮；已定局返回 false（不是失败）。
     *
     * `@Synchronized` 不是装饰：桥线程与主线程可能同时收尾，「先 snapshot 再判 finished
     * 再 mark」在锁外会让两边都拿到 true，调用方就会落两次盘（「只写一次」验收因此失真）。
     */
    @Synchronized
    fun endIfOpen(reason: String): Boolean {
        val current = WarehouseImportLog.snapshot().currentRun ?: return false
        if (current.finished) return false
        WarehouseImportLog.markEnd(reason)
        return true
    }

    /** 失败收尾：同样只作用于还开着的那一轮（同一把锁，理由见 [endIfOpen]）。 */
    @Synchronized
    fun failIfOpen(reason: String): Boolean {
        val current = WarehouseImportLog.snapshot().currentRun ?: return false
        if (current.finished) return false
        WarehouseImportLog.markFailure(reason)
        return true
    }

    /**
     * 记一条 [WarehouseLogCategory.FAILURE]（失败现场的第一行）。
     *
     * 没有开着的 run 时**丢弃**：定局之后迟到的错误不该再开一个 `auto-` 轮，把已经
     * 写好的结论顶成一个新的 `running`。
     *
     * @return true = 真的写进去了
     */
    @Synchronized
    fun recordFailure(code: String, vararg fields: Pair<String, String>): Boolean {
        val current = WarehouseImportLog.snapshot().currentRun ?: return false
        if (current.finished) return false
        val values = linkedMapOf<String, String>("code" to code)
        for ((key, value) in fields) values[key] = value
        WarehouseImportLog.record(WarehouseLogCategory.FAILURE, values)
        return true
    }

    /** 当前是否还有一轮没开收尾（宿主用它判断「现在算不算在导入里」）。 */
    fun isOpen(): Boolean = WarehouseImportLog.snapshot().currentRun?.finished == false

    /** 测试隔离：强制换会话键（等价于「换了一个导入目标」）。 */
    @Synchronized
    fun resetForTest(key: String) {
        sessionKey = null
        beginSession(key)
    }
}
