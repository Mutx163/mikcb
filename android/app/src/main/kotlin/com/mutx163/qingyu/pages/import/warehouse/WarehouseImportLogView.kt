package com.mutx163.qingyu.pages.import.warehouse

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * 导入执行日志的**展示模型**（纯 Kotlin，无 Compose、无 `android.*`）。
 *
 * 面板页（`WarehouseImportLogPage`，composeP1）只做三件事：拿 [buildLogSections] 的结果铺列表、
 * 把 [LogEmphasis] 映射成主题颜色、把 [buildShareText] 的结果交给剪贴板/分享。**分组与行格式
 * 不在这里以外的地方再实现一遍**——否则 L0（只编 `main/`）就测不到那部分，只能靠真机看，
 * 而真机看不了「行格式对不对」。
 *
 * ## 三条约定
 *
 * 1. **组头是 ASCII 单词**（`RUN 3 · TIMEOUT`）：日志面板不新增任何 ARB 键，跨语言也能读；
 *    状态取 run 的 `failed` / `finished` / `endReason`，没理由时回落 `OK` / `RUNNING`。
 * 2. **行格式 `HH:mm:ss.SSS CATEGORY k=v k=v`**：与 `WarehouseImportLogExport` 的落盘格式同一
 *    形状，用户对着屏幕念一行、文件里搜同一行能搜到。**值不截断**（长 selector 要能看全），
 *    横向滚动由 UI 负责；值里的换行折成空格，保证一条日志只占一行。
 * 3. **强调色只说语义**（[LogEmphasis]），不出现任何颜色值：颜色映射在渲染层做，
 *    这样深/浅色与主题走同一套 `MiuixTheme.colorScheme`。
 *
 * 纯 JVM：只用 `java.time`，L0 直接可测。
 */

/** 一条日志的强调级别（**不含颜色值**：渲染层按主题映射）。 */
enum class LogEmphasis {
    /** 普通信息。 */
    NORMAL,

    /** 跳过类（宏回放的 `status=skipped`，带 `skipReason`）。 */
    WARN,

    /** 失败类（`FAILURE` / `INTERNAL` / `status=failed`，以及失败 run 里的每一条）。 */
    ERROR,
}

/** 面板上的一行：已格式化的文本 + 强调级别。 */
data class LogLine(
    val text: String,
    val emphasis: LogEmphasis,
)

/** 面板上的一个 run 分组：ASCII 组头 + 该 run 的全部行。 */
data class LogSection(
    val title: String,
    val lines: List<LogLine>,
)

/** 分享用的两份文本（主题 + 正文）；拼装在纯逻辑层，UI 只负责发 Intent。 */
data class WarehouseLogShareText(
    val subject: String,
    val text: String,
)

object WarehouseImportLogView {

    /** 组头前缀（面板与导出里都不许再拼一次，守卫盯着渲染层）。 */
    const val RUN_HEADER_PREFIX: String = "RUN "

    /** 组头里编号与状态之间的分隔（`RUN 3 · TIMEOUT`）。 */
    const val RUN_HEADER_SEPARATOR: String = " · "

    const val STATUS_FAILED: String = "FAILED"
    const val STATUS_RUNNING: String = "RUNNING"

    /** run 正常收尾但没写 `endReason` 时的回落状态。 */
    const val STATUS_OK: String = "OK"

    /** 宏回放步骤状态字段（`WarehouseMacroReplayer.logMacroStep` 写的就是这个键）。 */
    const val STEP_STATUS_FIELD: String = "status"
    const val STEP_STATUS_FAILED: String = "failed"
    const val STEP_STATUS_SKIPPED: String = "skipped"

    /** 跳过的原因字段（与 `status=skipped` 同时出现，单独判一次防字段被裁掉）。 */
    const val SKIP_REASON_FIELD: String = "skipReason"

    /** 分享模板里「日志正文放这里」的占位符（B2 若把模板改成含 `{log}` 也照此替换）。 */
    const val SHARE_TEXT_LOG_PLACEHOLDER: String = "{log}"

    private val ENTRY_TIME_FORMAT: DateTimeFormatter =
        DateTimeFormatter.ofPattern("HH:mm:ss.SSS").withZone(ZoneId.systemDefault())

    /**
     * 快照 → 面板分组（按 run 顺序，组头编号从 1 起）。
     *
     * 失败 run 里的**每一条**都标 `ERROR`：用户报障时最先看的是「这一轮全挂了」，逐条再看是
     * 哪一步；只标 `FAILURE` 那一条的话，前面正常的步骤会被读成「这些没出事」。
     */
    fun buildLogSections(snapshot: WarehouseImportLogSnapshot): List<LogSection> =
        snapshot.runs.mapIndexed { index, run ->
            LogSection(
                title = buildRunTitle(index + 1, run),
                lines = run.entries.map { entry ->
                    LogLine(
                        text = formatEntryLine(entry),
                        emphasis = if (run.failed) LogEmphasis.ERROR else logEmphasis(entry),
                    )
                },
            )
        }

    /**
     * 单条日志的强调级别（只看条目本身；失败 run 的整体标记在 [buildLogSections] 里做）。
     *
     * 三档：失败（`FAILURE` / `INTERNAL` / `status=failed`）→ `ERROR`；跳过（`status=skipped`
     * 或带 `skipReason`）→ `WARN`；其余 → `NORMAL`。
     */
    fun logEmphasis(entry: WarehouseImportLogEntry): LogEmphasis {
        val status = entry.fields[STEP_STATUS_FIELD]?.trim()?.lowercase()
        return when {
            entry.category == WarehouseLogCategory.FAILURE ||
                entry.category == WarehouseLogCategory.INTERNAL -> LogEmphasis.ERROR

            status == STEP_STATUS_FAILED -> LogEmphasis.ERROR
            status == STEP_STATUS_SKIPPED -> LogEmphasis.WARN
            entry.fields.containsKey(SKIP_REASON_FIELD) -> LogEmphasis.WARN
            else -> LogEmphasis.NORMAL
        }
    }

    /**
     * 一行日志：`HH:mm:ss.SSS CATEGORY k=v k=v`。
     *
     * 值里的换行折成空格（一行一条，UI 的横向滚动才有意义）；**其余一律原样**，不截断、
     * 不排序、不省略空值——空 `k=` 本身也是信息。
     */
    fun formatEntryLine(entry: WarehouseImportLogEntry): String {
        val builder = StringBuilder(96)
        builder.append(ENTRY_TIME_FORMAT.format(Instant.ofEpochMilli(entry.tsMs)))
            .append(' ')
            .append(entry.category.name)
        for ((key, value) in entry.fields) {
            builder.append(' ').append(key).append('=').append(singleLine(value))
        }
        return builder.toString()
    }

    /**
     * 分享正文：调用方传入的模板 + 日志正文。
     *
     * 模板**由调用方传**（ARB 文案不在本文件里写死）：模板含 [SHARE_TEXT_LOG_PLACEHOLDER] 时原地
     * 替换成正文，否则模板作为开头一段、空一行后接正文。正文用
     * [WarehouseImportLogExport.buildText]（落盘那份同源：同样对每个字段再过一遍脱敏）。
     *
     * @param nowMs 表头 `time` 用的时间（默认当前毫秒；测试注入固定值）
     */
    fun buildShareText(
        snapshot: WarehouseImportLogSnapshot,
        deviceInfo: WarehouseDeviceInfo,
        shareTextTemplate: String,
        shareSubjectTemplate: String,
        nowMs: Long = System.currentTimeMillis(),
    ): WarehouseLogShareText {
        val body = WarehouseImportLogExport.buildText(snapshot, deviceInfo, nowMs)
        val template = shareTextTemplate.trim()
        val text = when {
            template.isEmpty() -> body
            template.contains(SHARE_TEXT_LOG_PLACEHOLDER) ->
                template.replace(SHARE_TEXT_LOG_PLACEHOLDER, body)

            else -> template + "\n\n" + body
        }
        return WarehouseLogShareText(
            subject = shareSubjectTemplate.trim(),
            text = text,
        )
    }

    // ---------------------------------------------------------------------
    // 内部
    // ---------------------------------------------------------------------

    private fun buildRunTitle(index: Int, run: WarehouseImportLogRun): String {
        val status = when {
            run.failed -> STATUS_FAILED
            !run.finished -> STATUS_RUNNING
            else -> normalizeEndReason(run.endReason)
        }
        return "$RUN_HEADER_PREFIX$index$RUN_HEADER_SEPARATOR$status"
    }

    /** `endReason` → 组头状态词（`timeout` → `TIMEOUT`、`page navigation` → `PAGE_NAVIGATION`）。 */
    private fun normalizeEndReason(reason: String?): String {
        val text = reason?.trim().orEmpty()
        if (text.isEmpty()) return STATUS_OK
        return text.uppercase().replace(' ', '_')
    }

    /** 值里的换行折成空格：一条日志只占一行（横向滚动的前提）。 */
    private fun singleLine(value: String): String =
        value.replace('\r', ' ').replace('\n', ' ')
}
