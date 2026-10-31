package com.mutx163.qingyu.platform

import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.io.IOException

/**
 * 情侣课表「选文件 / 存文件」的 **SAF 胶水**。
 *
 * ## 为什么另起一个类，不复用 `AndroidSafBackupAdapter`
 *
 * 那个类绑的是**本地备份的模型层类型**（`BackupFileReadResult` / `BackupSafContract` /
 * `BackupFileWriteLogic`），返回值是「备份恢复」语义的枚举。情侣页只需要两件最朴素的事：
 * **读一段 UTF-8 文本**、**写一段 UTF-8 文本**——把它接进备份那套枚举里，
 * 会让「情侣导入失败」和「备份恢复失败」共用一套分类，读代码的人分不清是谁的业务。
 *
 * ## 为什么导出不再「只用 SAF」（2026-10-29 二轮修正）
 *
 * 这一节原来写的是「本仓 `AndroidManifest.xml` 里**没有** `FileProvider` 声明，
 * 所以分享文件必然失败，只能退到 SAF」。**那句话现在已经过期**：
 * `7c8d11b6`（2026-10-29 19:04）给 manifest 注册了
 * `${applicationId}.fileprovider`，`res/xml/file_paths.xml` 也声明了
 * `transfer_share → cacheDir/transfer-share/`，分享文件这条路已经通了。
 *
 * 所以现在导出**优先走系统分享面板**（`AndroidTransferShareAdapter`，与 Dart 的
 * `share_plus` 同口径），本类只剩两件事：
 * 1. **导入**：`ACTION_OPEN_DOCUMENT` 读 UTF-8（[readUtf8]）；
 * 2. **导出兜底**：分享面板起不来（provider 异常 / 没有可接收的应用）时，
 *    退回 `ACTION_CREATE_DOCUMENT` 让用户自己选保存位置（[writeUtf8]）。
 *
 * 保留 SAF 兜底而不是直接删掉：宁可多一条「一定能存下来」的路，也不要在
 * 分享失败的机型上把用户导出的数据弄丢。
 *
 * ## 诚实边界
 *
 * 本类引 `android.*`，进不了 JVM 单测（与 `AndroidShareAdapter` / `AndroidSafBackupAdapter`
 * 同一约定）。这里只保证「编译通过」；「真机上选文件/存文件真能用」只能由用户在真机验。
 */
class CoupleTransferAdapter(private val context: Context) {

    /** 导入用：打开文档。MIME 与备份导入取同一组（`.mikcb` 常被识别成 octet-stream）。 */
    fun openDocumentIntent(): Intent =
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, OPEN_MIME_TYPES)
        }

    /** 导出用：新建文档（默认文件名由调用方给）。 */
    fun createDocumentIntent(fileName: String): Intent =
        Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = MIME_JSON
            putExtra(Intent.EXTRA_TITLE, fileName)
        }

    /**
     * 从 `content://` 读 UTF-8 文本。
     *
     * **限长读**：超过 [maxBytes] 立刻放弃（返回 null），不把超大文件读进内存——
     * Android 上 OOM 是杀进程，不是可捕获异常（与 Dart 侧 `withData: false` 的理由同一条）。
     *
     * @return null = 读不到 / 超过上限 / 内容不是合法 UTF-8。
     */
    fun readUtf8(uri: Uri, maxBytes: Int = MAX_BYTES): String? = try {
        context.contentResolver.openInputStream(uri)?.use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8 * 1024)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                total += read
                if (total > maxBytes) return null
                out.write(buffer, 0, read)
            }
            out.toByteArray().toString(Charsets.UTF_8)
        }
    } catch (_: IOException) {
        null
    } catch (_: SecurityException) {
        null
    } catch (_: IllegalArgumentException) {
        // 有些 provider 对非法 uri 抛这个，不是「文件坏了」而是「选不到」。
        null
    }

    /** 把 UTF-8 文本写进用户选定的位置。@return false = 写失败（调用方据此提示，不假装成功）。 */
    fun writeUtf8(uri: Uri, content: String): Boolean = try {
        val stream = context.contentResolver.openOutputStream(uri, "wt")
        if (stream == null) {
            false
        } else {
            stream.use {
                it.write(content.toByteArray(Charsets.UTF_8))
                it.flush()
            }
            true
        }
    } catch (_: IOException) {
        false
    } catch (_: SecurityException) {
        false
    }

    companion object {
        const val MIME_JSON: String = "application/json"

        /**
         * 单档包体积上限：与 Dart `UnifiedTransferService.maxImportFileBytes` 同一条 20MB。
         * （情侣包只含一份课表，正常远小于它；上限只为挡住「选错文件」。）
         */
        const val MAX_BYTES: Int = 20 * 1024 * 1024

        val OPEN_MIME_TYPES: Array<String> = arrayOf(MIME_JSON, "application/octet-stream")
    }
}
