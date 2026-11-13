package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.infra.AppLogStore
import java.io.File

/**
 * 日志落盘（**薄壳**：只做「拼路径 + 覆盖写 + 失败不抛」）。
 *
 * ## 为什么是覆盖写
 *
 * 固定一个文件 `<filesDir>/warehouse_import_log/last.txt`，每轮导入覆盖它。
 * 这是**天然自限**：不清理也不会越写越多，用户手机里永远只有「最近一次」。
 * 保留策略仍是「只有最近一次」：读取与展示在 `WarehouseImportLogPage`（内存快照），
 * 本文件只负责落盘那份可导出的副本。
 *
 * ## ⚠️ 写失败不抛，但必须留痕
 *
 * 写盘失败（存储满、权限被改、目录被占）**不能**把异常抛回导入收尾链路——那会把
 * 「日志没写成」变成「导入流程炸了」。所以这里吞掉异常、返回 `false`。
 *
 * **面板必须显示这类内部失败**：用户点了「查看日志」却什么都没有时，
 * 「压根没生成」和「生成了但写失败」是两种完全不同的处置（前者去看导入有没有跑，
 * 后者去看存储空间/权限）。只吞不显示，用户只能看到一个空文件和一个说不清的问题。
 * 所以失败时往 buffer 记一条 [WarehouseLogCategory.INTERNAL]。
 *
 * 本函数只落盘并返回是否成功；失败记 `INTERNAL`，读取与展示见 `WarehouseImportLogPage`
 *（它读 `WarehouseImportLog.buffer` 的快照，与这里写的是同一份数据源）。
 *
 * 纯 JVM：只用 `java.io`，不 import `android.*`（`context.filesDir` 由宿主传进来）。
 */
class WarehouseImportLogFileWriter(
    /** 应用私有目录（生产路径是 `context.filesDir`）。 */
    private val baseDir: File,
    private val log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
) {
    /** 生产路径目标文件：`<baseDir>/warehouse_import_log/last.txt`。 */
    fun targetFile(): File = File(File(baseDir, DIR_NAME), FILE_NAME)

    /** 覆盖写 [text] 到 [targetFile]。 */
    fun write(text: String): Boolean = write(targetFile(), text)

    /**
     * 覆盖写 [text] 到 [file]（测试用临时目录；也便于将来按 run 分文件）。
     *
     * @return true = 真的写成功了；false = 失败（已记 INTERNAL，**没抛**）
     */
    fun write(file: File, text: String): Boolean = try {
        file.parentFile?.mkdirs()
        file.writeText(text, Charsets.UTF_8)
        true
    } catch (error: Exception) {
        // 只记文件名，不记绝对路径（里面带包名与用户目录结构）。
        log.record(
            WarehouseLogCategory.INTERNAL,
            linkedMapOf(
                "where" to "WarehouseImportLogFileWriter.write",
                "file" to file.name,
                "error" to (error.message ?: error.javaClass.simpleName),
            ),
        )
        false
    }

    companion object {
        /** 落盘子目录。 */
        const val DIR_NAME = "warehouse_import_log"

        /** 单份日志文件名（覆盖写）。 */
        const val FILE_NAME = "last.txt"
    }
}

/**
 * 宿主收尾的一站式入口：**取快照 → 编文本 → 覆盖写**。
 *
 * 存在的理由：composeP1 宿主那边只允许加个位数的行，把「快照 + 设备信息 + 落盘」三件事
 * 收成一个调用，宿主只需要传 `context.filesDir` 与三个只读字段。
 *
 * @return 是否写成功（失败时 buffer 里已有 INTERNAL，调用方不必再做别的）
 */
fun writeWarehouseImportLogFile(
    filesDir: File,
    deviceInfo: WarehouseDeviceInfo,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
    nowMs: Long = System.currentTimeMillis(),
): Boolean {
    val text = WarehouseImportLogExport.buildText(log.snapshot(), deviceInfo, nowMs)
    return WarehouseImportLogFileWriter(baseDir = filesDir, log = log).write(text)
}

// ---------------------------------------------------------------------------
// C：同一份脱敏文本也进应用日志（诊断页 / 日志面板两个入口看同一条记录）
// ---------------------------------------------------------------------------

/** 应用日志里这条导入记录的分类（诊断页按 category 过滤）。 */
const val WAREHOUSE_IMPORT_APP_LOG_CATEGORY: String = "warehouse.import"

/**
 * 应用日志单条上限：**8 KiB**（UTF-8 字节）。
 *
 * `last.txt` 单份可到 256 KiB，但应用日志是**滚动文件**（512 KiB 全文件，超了保留后一半）：
 * 一条 200 KiB 的导入日志会把文件里其它应用日志整段挤掉。所以这里先自己截，
 * 不把「单条多大」交给 [com.mutx163.qingyu.infra.AppLogStore] 的文件级滚动。
 */
const val WAREHOUSE_IMPORT_APP_LOG_MAX_BYTES: Int = 8 * 1024

/** 截断标记（ASCII，与 [WarehouseImportLogExport.TRUNCATED_NOTE] 同一记号，跨语言可比）。 */
const val WAREHOUSE_IMPORT_APP_LOG_TRUNCATED_NOTE: String = "[TRUNCATED]"

/**
 * 应用日志条目正文：**再过一次** [WarehouseLogRedaction.redactText]（第二道闸），再按 UTF-8
 * 字节截到 [maxBytes]，超出追加一行 [WAREHOUSE_IMPORT_APP_LOG_TRUNCATED_NOTE]。
 *
 * 为什么脱敏要在这里再做一遍：面板/`last.txt` 的干净只证明**那两条出口**干净；
 * 应用日志是第三个出口，多一个出口就多一次「上游把没脱敏的文本递进来」的机会。
 * 这里不信任调用方给的文本（幂等，多跑一次没有副作用）。
 *
 * @param maxBytes 上限（测试可注入小值）
 */
fun warehouseImportAppLogMessage(
    text: String,
    maxBytes: Int = WAREHOUSE_IMPORT_APP_LOG_MAX_BYTES,
): String {
    val redacted = WarehouseLogRedaction.redactText(text)
    val bytes = redacted.toByteArray(Charsets.UTF_8)
    if (bytes.size <= maxBytes) return redacted
    return truncateUtf8Bytes(redacted, maxBytes).trimEnd('\n') +
        "\n" + WAREHOUSE_IMPORT_APP_LOG_TRUNCATED_NOTE
}

/**
 * C 的落点：把一次导入收尾的正文追加进应用日志（`AppLogStore`）。
 *
 * 三件事按顺序做，顺序本身就是纪律：
 * 1. `AppLogStore.isInitialized()` 为假（Android 反射取不到 `filesDir`）→ **跳过、不抛**；
 * 2. 正文再脱敏 + 8 KiB 截断（[warehouseImportAppLogMessage]）；
 * 3. `AppLogStore.append`；写失败只用 buffer 记一条 `INTERNAL`，与 `last.txt` 写失败同一口径。
 *
 * @param snapshot 这次收尾的快照（决定 level / extras：失败 ERROR、其余 INFO）
 * @param text 导出用的同一份正文（宿主已过一遍脱敏；这里再兜一次）
 * @return true = 这次写没抛；false = 未初始化 / 写失败
 */
fun appendWarehouseImportLogToAppLog(
    snapshot: WarehouseImportLogSnapshot,
    text: String,
    log: WarehouseImportLogBuffer = WarehouseImportLog.buffer,
): Boolean {
    if (!AppLogStore.isInitialized()) return false
    val endReason = snapshot.lastFailureReason
        ?: snapshot.currentRun?.endReason
        ?: ""
    val written = AppLogStore.append(
        level = if (snapshot.hasFailure) APP_LOG_LEVEL_ERROR else APP_LOG_LEVEL_INFO,
        category = WAREHOUSE_IMPORT_APP_LOG_CATEGORY,
        message = warehouseImportAppLogMessage(text),
        extras = linkedMapOf(
            "endReason" to endReason.ifEmpty { END_REASON_NONE },
            "entries" to snapshot.entryCount,
        ),
    )
    if (!written) {
        log.record(
            WarehouseLogCategory.INTERNAL,
            linkedMapOf(
                "where" to "appendWarehouseImportLogToAppLog",
                "error" to "app_log_append_failed",
            ),
        )
    }
    return written
}

/** `AppLogStore.append` 的级别取值（`infra/LogGate.kt` 的 `normalizeLogLevel` 认这两个）。 */
private const val APP_LOG_LEVEL_ERROR: String = "error"
private const val APP_LOG_LEVEL_INFO: String = "info"

/** 没有失败原因 / 还没收尾时的占位（extras 里空值看不出是「没记」还是「丢了」）。 */
private const val END_REASON_NONE: String = "none"

/**
 * 按 UTF-8 字节截断，**回退到字符边界**（多字节字符被切一半会写进半截字节）。
 *
 * 与 [WarehouseImportLogExport] 的截断同口径：找最后一个完整字符的右边界。
 */
private fun truncateUtf8Bytes(text: String, maxBytes: Int): String {
    val bytes = text.toByteArray(Charsets.UTF_8)
    if (bytes.size <= maxBytes) return text
    var end = maxBytes
    // UTF-8 续字节形如 10xxxxxx；落在续字节上说明这个字符还没写完整，往左退一个字符。
    while (end > 0 && (bytes[end].toInt() and 0xC0) == 0x80) end--
    return String(bytes, 0, end, Charsets.UTF_8)
}
