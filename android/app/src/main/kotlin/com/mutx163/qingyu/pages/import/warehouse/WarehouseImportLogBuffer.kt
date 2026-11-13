package com.mutx163.qingyu.pages.import.warehouse

/**
 * 导入日志条目分类（固定枚举）。
 *
 * 落盘里 `category` 那一列就是这些名字，**不再有第二种写法**：用户在日志里看到的
 * `MACRO_STEP` / `GATE` / `FAILURE` 与代码里同名，排查时不用再翻译一次。
 */
enum class WarehouseLogCategory {
    /** 宏回放的一步（步号 / 类型 / selector / 状态 / 耗时 / 跳过原因）。 */
    MACRO_STEP,

    /** 「现在能不能执行导入脚本」的闸门裁决（Ready 或拒绝原因）。 */
    GATE,

    /** 适配脚本侧事件（目前只有失败点；桥与 console 钩子留到第 2 步）。 */
    SCRIPT,

    /** 网页桥接事件（**本批还没有接点**，枚举先占位，第 2 步接 composeP1 时用）。 */
    BRIDGE,

    /** 一次导入失败的服务消息原文（`code|k=v`）。 */
    FAILURE,

    /** 本模块自己出的错（写盘失败、不变量被踩……）——**这类必须可见**，见 `WarehouseImportLogFileWriter` 的 KDoc。 */
    INTERNAL,
}

/** 一条日志。`fields` 在**入队时就已脱敏**（见 [WarehouseLogRedaction]，不允许出现明文口令/账号/完整 URL）。 */
data class WarehouseImportLogEntry(
    val tsMs: Long,
    val category: WarehouseLogCategory,
    val fields: Map<String, String>,
)

/**
 * 一次导入（一个 run）的全部条目。
 *
 * @param failed 这一次 run 是不是失败收尾（`markFailure` 置真）
 * @param finished `markEnd` / `markFailure` 已经收尾；false = 还在跑
 */
data class WarehouseImportLogRun(
    val runId: String,
    val school: String,
    val adapterId: String,
    val entries: List<WarehouseImportLogEntry>,
    val endReason: String?,
    val failed: Boolean,
    val finished: Boolean,
)

/** 一次取数：按 run 分组，导出层只读它，不碰 buffer 内部结构。 */
data class WarehouseImportLogSnapshot(
    val runs: List<WarehouseImportLogRun>,
    val lastFailureReason: String?,
) {
    /** 条目总数（判定「有没有东西可写」用）。 */
    val entryCount: Int
        get() = runs.sumOf { it.entries.size }

    /** 这批快照里是否有失败 run。 */
    val hasFailure: Boolean
        get() = runs.any { it.failed }

    /** 最后开的那一个 run（表头的 school / adapter 取它）。 */
    val currentRun: WarehouseImportLogRun?
        get() = runs.lastOrNull()

    /** 最近一次失败 run（保留语义的主角）。 */
    val lastFailedRun: WarehouseImportLogRun?
        get() = runs.lastOrNull { it.failed }
}

/**
 * 教务导入的**运行日志缓冲**（P0 验证通道的第一步：先有数据，再好谈面板）。
 *
 * ## 为什么用户要它
 *
 * 用户不会看 logcat。导入失败时，「哪一步、哪个闸门、什么码」这些东西现在只进
 * `Log.*`，所以对用户来说等于没有。这个 buffer 把它们留成可导出的一段文本
 * （落盘见 `WarehouseImportLogFileWriter`，UI 面板是下一步）。
 *
 * ## 保留语义（**不是 takeLast**）
 *
 * `snapshot()` 的**下界保证**是「最近一次失败 run 的全部条目 + 当前 run 的全部条目」
 * 两条都在。刻意**没有**写成「取最近 N 条」：环形窗口会先把失败那一轮的开头挤掉，
 * 而「失败 run 的第一条」恰恰是最值钱的那一行（它说明这一轮从哪开始、入口地址是什么）。
 * 配套用例：`WarehouseImportLogExportTest.失败run首条必须保留_不是takeLast`。
 *
 * [capacity] 只约束**已成功收尾**的 run 保留多少条尾窗；失败 run 与当前 run 不截断。
 * 一次导入的条数由宏步数决定（几十到几百），所以这两个 run 不设上限是安全的。
 *
 * ## 线程模型
 *
 * 所有读写都在 `lock` 里；回放（IO 协程）、WebView 回调（主线程）、写盘（宿主收尾）
 * 可能并发进同一个 buffer。`snapshot()` 给的是**不可变副本**，之后 buffer 继续写不影响它。
 *
 * 纯 JVM：不 import `android.*`，L0 直接可测。
 */
class WarehouseImportLogBuffer(
    private val capacity: Int = DEFAULT_CAPACITY,
    /** 时钟：默认系统毫秒；测试注入固定值，断言文本里的时间列。 */
    private val nowMs: () -> Long = System::currentTimeMillis,
) {
    private val lock = Any()

    /** 保留的 run（按开启顺序），最多 [MAX_RETAINED_RUNS] 个；失败那个永久钉住。 */
    private val runs = ArrayList<MutableRun>()

    private var failedRunId: String? = null
    private var lastFailureReason: String? = null
    private var autoRunCounter = 0

    /** 开一个新 run（同一 runId 重入 = 续写，宿主重试时能接上前面的条目）。 */
    fun beginRun(runId: String, school: String, adapterId: String) {
        synchronized(lock) {
            val last = runs.lastOrNull()
            if (last != null && !last.finished && last.runId == runId) {
                last.school = school
                last.adapterId = adapterId
                return
            }
            if (last != null && !last.finished) {
                // 上一轮没走收尾就被新一轮顶掉：按 superseded 收尾并留在窗口里，
                // 别让「重试」把上一轮的现场整段吞掉。
                last.finished = true
                last.endReason = END_REASON_SUPERSEDED
            }
            runs += MutableRun(runId = runId, school = school, adapterId = adapterId)
            trimLocked()
        }
    }

    /** 本轮正常结束（原因写进表头 `endReason`，例如 `complete` / `cancelled`）。 */
    fun markEnd(reason: String) {
        synchronized(lock) {
            val run = runs.lastOrNull() ?: return
            if (!run.finished) {
                run.finished = true
                run.endReason = reason
                trimEntriesLocked(run)
            }
        }
    }

    /** 本轮失败收尾：**这个 run 从此不被环形窗口淘汰**（见类注释的保留语义）。 */
    fun markFailure(reason: String) {
        synchronized(lock) {
            val run = runs.lastOrNull() ?: return
            run.finished = true
            run.failed = true
            run.endReason = reason
            failedRunId = run.runId
            lastFailureReason = reason
        }
    }

    /**
     * 记一条（`fields` 在这里**就地脱敏**—— buffer 里永远没有明文）。
     *
     * 还没开 run 时自动开一个（`auto-N`）：钩子接在纯函数上（闸门判定），不能要求
     * 调用方先记得 `beginRun` —— 漏调就把日志整段丢了，比多一个 auto run 糟得多。
     */
    fun record(category: WarehouseLogCategory, fields: Map<String, String>) {
        val entry = WarehouseImportLogEntry(
            tsMs = nowMs(),
            category = category,
            fields = WarehouseLogRedaction.redact(fields),
        )
        synchronized(lock) {
            ensureOpenRunLocked().entries += entry
        }
    }

    /** [record] 的便利重载。 */
    fun record(category: WarehouseLogCategory, vararg fields: Pair<String, String>) {
        record(category, linkedMapOf(*fields))
    }

    /** 取一份不可变快照（含失败 run 与当前 run；见类注释的保留语义）。 */
    fun snapshot(): WarehouseImportLogSnapshot = synchronized(lock) {
        WarehouseImportLogSnapshot(
            runs = runs.map { it.toImmutable() },
            lastFailureReason = lastFailureReason,
        )
    }

    /** 清空（新一轮导入 / 测试隔离用）。 */
    fun clear() {
        synchronized(lock) {
            runs.clear()
            failedRunId = null
            lastFailureReason = null
            autoRunCounter = 0
        }
    }

    // ---------------------------------------------------------------------
    // 内部
    // ---------------------------------------------------------------------

    private fun ensureOpenRunLocked(): MutableRun {
        val last = runs.lastOrNull()
        if (last != null && !last.finished) return last
        autoRunCounter += 1
        val auto = MutableRun(runId = "$AUTO_RUN_PREFIX$autoRunCounter", school = "", adapterId = "")
        runs += auto
        trimLocked()
        return auto
    }

    /** 淘汰最旧的 run，但**永不淘汰**最近一次失败 run 与最后一个（当前）run。 */
    private fun trimLocked() {
        while (runs.size > MAX_RETAINED_RUNS) {
            val index = runs.indexOfFirst { candidate ->
                candidate !== runs.last() && candidate.runId != failedRunId
            }
            if (index < 0) return
            runs.removeAt(index)
        }
    }

    /** 成功收尾的 run 只留 [capacity] 条尾窗；失败 run 不截断（首条必须留）。 */
    private fun trimEntriesLocked(run: MutableRun) {
        if (run.failed || run.entries.size <= capacity) return
        val overflow = run.entries.size - capacity
        repeat(overflow) { run.entries.removeAt(0) }
    }

    private class MutableRun(
        val runId: String,
        var school: String,
        var adapterId: String,
    ) {
        val entries = ArrayList<WarehouseImportLogEntry>()
        var endReason: String? = null
        var failed = false
        var finished = false

        fun toImmutable(): WarehouseImportLogRun = WarehouseImportLogRun(
            runId = runId,
            school = school,
            adapterId = adapterId,
            entries = entries.toList(),
            endReason = endReason,
            failed = failed,
            finished = finished,
        )
    }

    companion object {
        /** 环形容量：成功收尾的 run 保留多少条尾窗。 */
        const val DEFAULT_CAPACITY = 500

        /** 最多留几个 run（失败那个钉住，另外留当前与最近一两轮上下文）。 */
        const val MAX_RETAINED_RUNS = 4

        /** 没显式 `beginRun` 时自动开出来的 runId 前缀。 */
        const val AUTO_RUN_PREFIX = "auto-"

        /** 上一轮没走收尾就被顶掉时的 endReason。 */
        const val END_REASON_SUPERSEDED = "superseded"
    }
}

/**
 * 进程内**唯一**的导入日志缓冲（落盘固定 `warehouse_import_log/last.txt`，一次导入一份）。
 *
 * 为什么是全局单例而不是层层透传：钩子挂在两个纯函数上（`planWarehouseScriptExecution`）
 * 和回放引擎的构造上，而宿主侧能改的行数被压到个位数。全局一份的代价是测试之间会串味，
 * 所以提供 [reset]；需要隔离的测试自己 `WarehouseImportLogBuffer()` 新建一只，不碰这里。
 */
object WarehouseImportLog {
    @Volatile
    var buffer: WarehouseImportLogBuffer = WarehouseImportLogBuffer()
        private set

    /** 换一只空 buffer（新一轮导入 / 测试隔离）。旧 buffer 的内容随引用一起放掉。 */
    fun reset(): WarehouseImportLogBuffer {
        val fresh = WarehouseImportLogBuffer()
        buffer = fresh
        return fresh
    }

    fun beginRun(runId: String, school: String, adapterId: String) =
        buffer.beginRun(runId, school, adapterId)

    fun markEnd(reason: String) = buffer.markEnd(reason)

    fun markFailure(reason: String) = buffer.markFailure(reason)

    fun record(category: WarehouseLogCategory, fields: Map<String, String>) =
        buffer.record(category, fields)

    fun record(category: WarehouseLogCategory, vararg fields: Pair<String, String>) =
        buffer.record(category, *fields)

    fun snapshot(): WarehouseImportLogSnapshot = buffer.snapshot()
}
