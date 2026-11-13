package com.mutx163.qingyu.pages.import.warehouse

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
