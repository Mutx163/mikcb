package com.mutx163.qingyu.pages.sync

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 本地备份「选文件 / 存文件」的 SAF（Storage Access Framework）契约（纯 Kotlin，可 JVM 单测）。
 *
 * ## 为什么把字符串常量单独拎出来
 *
 * 真正碰 `android.content.Intent` / `ContentResolver` 的适配器（`main: platform/AndroidSafBackupAdapter.kt`）
 * **进不了 JVM 单测**（`test-kotlin-module.ps1` 会因 `import android.*` 整目录跳过）。若把
 * MIME、action、文件名格式写死在适配器里，这些值就没有任何测试能钉住——写错一个字符只会
 * 在真机上表现为「系统选择器不认这个文件」。所以判据全放本层，适配器只做「把这里的常量
 * 塞进 Intent、把 Uri 交给读写模型」。
 *
 * 类比：I3 的 [com.mutx163.qingyu.pages.export.IcsShareLogic] 之于 `AndroidShareAdapter`。
 *
 * ## 诚实边界
 *
 * 这里只固化**契约值**（action 字符串 / MIME / 文件名格式 / 扩展名判定），不产生任何
 * `Intent` 对象，也不读设备。真正的 SAF 交互与权限由壳 Activity 的
 * `registerForActivityResult` 承担（属 Lead）。
 */
object BackupSafContract {

    /**
     * 备份文件 MIME（Dart `data_transfer_service.dart` 用 `application/json` 分享备份）。
     * 本 C2 导出的是**全量同步快照 JSON**（与 WebDAV 上传同格式），故为 JSON。
     */
    const val MIME_JSON: String = "application/json"

    /**
     * `.mikcb` 等扩展名在部分文件管理器里被报告成八位字节流。选文件时把它一并放进
     * MIME 过滤，避免用户能看到、却点不动的备份文件。
     */
    const val MIME_OCTET_STREAM: String = "application/octet-stream"

    /**
     * 选文件（导入）时允许的 MIME 集合。
     *
     * 用法：`Intent.ACTION_OPEN_DOCUMENT` 上把 `type` 设成通配（星号+斜杠+星号），再用
     * `putExtra(EXTRA_MIME_TYPES, OPEN_MIME_TYPES)` 收窄。之所以不直接把 `type` 设成
     * `application/json`：SAF 的类型过滤以 provider 上报的 MIME 为准，很多 provider 把
     * `*.mikcb` 报成 `application/octet-stream`，只给 json 会让这类文件在选择器里变灰。
     */
    val OPEN_MIME_TYPES: Array<String> = arrayOf(MIME_JSON, MIME_OCTET_STREAM)

    /**
     * 系统「打开文档」动作的字面量。
     *
     * 与 `android.content.Intent.ACTION_OPEN_DOCUMENT`**逐字相同**（`"android.intent.action.OPEN_DOCUMENT"`），
     * 但本层不 `import android.*` 求值，而是写字面量——好让纯 JVM 单测能钉住它，
     * 也避免把一个 Android 类型带进模型层。`BackupSafContractTest` 里有对字面量的断言。
     */
    const val ACTION_OPEN_DOCUMENT: String = "android.intent.action.OPEN_DOCUMENT"

    /** 系统「新建文档」动作的字面量，等价于 `Intent.ACTION_CREATE_DOCUMENT`。 */
    const val ACTION_CREATE_DOCUMENT: String = "android.intent.action.CREATE_DOCUMENT"

    /** 新建文档对话框里预填的标题键，等价于 `Intent.EXTRA_TITLE`。 */
    const val EXTRA_TITLE: String = "android.intent.extra.TITLE"

    /** `Intent.EXTRA_MIME_TYPES` 的字面量（选文件时收窄 MIME 集合用）。 */
    const val EXTRA_MIME_TYPES: String = "android.intent.extra.MIME_TYPES"

    /** 打开目录类选择器需要的类别，等价于 `Intent.CATEGORY_OPENABLE`。 */
    const val CATEGORY_OPENABLE: String = "android.intent.category.OPENABLE"

    /** 导出文件名前缀（对齐 Dart `data_transfer_service.dart` 的 `mikcb-backup-` 命名）。 */
    const val FILE_NAME_PREFIX: String = "mikcb-backup"

    /**
     * 导出文件扩展名。
     *
     * 选 `json`（不是 `.mikcb`）：本 C2 导出的是**全量同步快照 JSON**，与 `.mikcb`
     * 数据迁移全量备份（`data_transfer_service.dart` 的 `buildFullBackupJson`，backupType=`full`）
     * **不是同一种格式**。用 `.json` 明确它是「快照 JSON」，避免被误当成 `.mikcb` 迁移备份。
     */
    const val FILE_EXTENSION: String = "json"

    /** 导入时认作备份候选的扩展名（小写、不含点）。 */
    val ACCEPTED_EXTENSIONS: Set<String> = setOf("json", "mikcb")

    private val FILE_NAME_TIME_FORMAT: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyyMMdd-HHmm")

    /**
     * 生成默认导出文件名：`mikcb-backup-yyyyMMdd-HHmm.json`（时间取传入的 [now]）。
     *
     * 与 Dart `mikcb-backup-${yyyy}${MM}${dd}-${HH}${mm}.$fileExtension` 的**日期时间段形态**一致，
     * 仅扩展名按本 C2 的快照 JSON 取 `json`（见 [FILE_EXTENSION] 的说明）。
     */
    fun defaultFileName(now: LocalDateTime): String =
        "$FILE_NAME_PREFIX-" + FILE_NAME_TIME_FORMAT.format(now) + "." + FILE_EXTENSION

    /**
     * 文件名是否是备份候选（大小写不敏感地看扩展名）。
     *
     * Dart `file_picker` 用 `allowedExtensions: ['json', 'mikcb']` 过滤；SAF 侧 MIME 过滤未必
     * 精确，接线层可再拿本函数对 `OpenableColumns.DISPLAY_NAME` 兜一道（可选）。
     */
    fun isBackupFileCandidate(fileName: String?): Boolean {
        if (fileName.isNullOrBlank()) return false
        val dot = fileName.lastIndexOf('.')
        if (dot < 0 || dot == fileName.length - 1) return false
        return ACCEPTED_EXTENSIONS.contains(fileName.substring(dot + 1).lowercase())
    }
}

/**
 * 从 [BackupSafContract] 的判据到「给用户看的动作结果」的桥（保持纯 Kotlin，可单测）。
 *
 * 真正的 toast 文案走 ARB、由接线层（Lead）决定；本对象只把「写出结果」翻译成一个
 * 不依赖 UI 的 [BackupExportOutcome]，方便页面 `when` 分支。**不新造任何 ARB 文案。**
 */
sealed interface BackupExportOutcome {

    /** 已把 [byteLength] 字节的备份写进用户选的文件。 */
    data class Saved(
        val fileName: String,
        val byteLength: Int,
        val checksumEmbedded: Boolean,
    ) : BackupExportOutcome

    /** 用户取消（系统选择器返回 null Uri）。 */
    object Cancelled : BackupExportOutcome

    /** 写出前就被模型判为不可写（信封坏 / 空课表 / 太大）。 */
    data class Rejected(val failure: WriteFailure) : BackupExportOutcome

    /** 已选好文件但落盘失败（Uri 打不开 / 写到一半 IO 异常 / 权限被拒）。 */
    data class IoFailed(val reason: BackupIoFailure) : BackupExportOutcome
}

/** 备份文件落盘/读取的 IO 失败原因（不含用户文案，文案由接线层按 ARB 决定）。 */
enum class BackupIoFailure {

    /** 选中的 Uri 打不开输入流（provider 失效 / 权限被撤）。 */
    OPEN_INPUT_FAILED,

    /** 选中的 Uri 打不开输出流（只读位置 / provider 失效）。 */
    OPEN_OUTPUT_FAILED,

    /** 读/写过程中途抛 IO（磁盘满、连接断）。 */
    IO_ERROR,

    /** 安全异常（无权限 / provider 拒绝）。 */
    SECURITY_ERROR,
}

/**
 * 导入（选文件 → 读）的结局。
 *
 * 「文件太大」不在这里单列：它由读模型自己判成
 * [BackupFileReadResult.Failure]（`kind == FILE_TOO_LARGE`），统一走 [Parsed]，
 * 接线层只需对读结果按 `kind` 分支即可。这里只兜「连字节都拿不到」的真 IO 问题。
 */
sealed interface SafImportOutcome {

    /** 拿到了文件内容并交给读模型（读成功 / 读失败都在 [result] 里）。 */
    data class Parsed(val result: BackupFileReadResult) : SafImportOutcome

    /** 没拿到内容：Uri 打不开 / 权限 / 读过程中途 IO。 */
    data class IoFailed(val reason: BackupIoFailure) : SafImportOutcome

    /** 用户取消（系统选择器返回 null Uri）。 */
    object Cancelled : SafImportOutcome
}
