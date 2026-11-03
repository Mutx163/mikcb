package com.mutx163.qingyu.platform

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import com.mutx163.qingyu.share.TransferShareContract
import com.mutx163.qingyu.transfer.TransferTextDecoding
import java.io.ByteArrayOutputStream
import java.io.IOException

/**
 * 「数据备份与迁移」页 `.mikcb` 传输包的**选文件 / 读取适配器**（Android 胶水半边）。
 *
 * 职责只有两件：拼系统文档选择器 Intent、把用户选中的 `content://` 限长读成 UTF-8 文本。
 * 不解析包体、不做业务判断（解析与预览属模型层/服务层），也不渲染任何用户文案
 * （toast 由壳接线层按 ARB 决定，本类只返回带分类的结局）。
 *
 * 判据来自 [TransferShareContract]（纯 Kotlin、JVM 单测覆盖）：MIME 候选、20 MiB 上限、
 * 超限边界口径。本文件引 `android.*`，进不了 JVM 单测——所以这里**不新造任何阈值**。
 *
 * 手法照抄同目录 [AndroidSafBackupAdapter] 的导入路径：先按 `OpenableColumns.SIZE` 短路，
 * 再限长读（读满上限 + 1 字节就停），最后 UTF-8 解码。
 *
 * ## 壳侧还要做什么（属 Lead，不在本类）
 *
 * 「拉起选择器并接回结果」需要 Activity 侧的 `registerForActivityResult(...)` 或
 * `onActivityResult`：把 [openDocumentIntent] 交给 `ActivityResultContracts.StartActivityForResult`，
 * 拿到 data 里的 `Intent.getData()` 再调 [readText]。**不需要改 AndroidManifest**
 * （SAF 走系统文档选择器，不像 FileProvider 那样要 `<provider>`）。
 *
 * ## 真机未验（L4）
 *
 * 「选择器里能不能看见 `.mikcb` 文件」「选完能不能读到内容」只能由用户在真机验证。
 */
class AndroidTransferDocumentAdapter(private val context: Context) {

    /** 读取的三种结局。**不抛异常**，超限与读失败分得很清楚。 */
    sealed interface ReadResult {

        /** 读到了完整文本（UTF-8 解码后）。 */
        data class Success(val text: String) : ReadResult

        /**
         * 文件字节数超过上限。
         *
         * 两种成因都归到这里：`OpenableColumns.SIZE` 声明的就超了（连流都没开），
         * 或者没声明大小、读到上限 + 1 字节才发现（此时已停止读取，**不会**把超大文件读进内存）。
         */
        data object TooLarge : ReadResult

        /** 打不开流、provider 失效、权限被撤回等。 */
        data object ReadFailed : ReadResult

        /**
         * 字节读到了，但不是合法 UTF-8（截断序列 / 非法字节 / 越界码点）。
         *
         * 与 Dart 文件通道的 `utf8.decode` 同口径：畸形字节直接拒绝，不做替换字符兜底。
         * Dart 的 `TransferPackage.decodeBytes` 里定义了 `transfer_package_utf8_invalid`，
         * 但文件通道**没有走那条路**（`data_transfer_screen.dart:415` 直接 `utf8.decode`），
         * 所以本码目前没有 ARB 文案键——用户文案由壳接线层决定，**本类不造字符串**。
         */
        data object InvalidEncoding : ReadResult
    }

    /**
     * 「打开文档」Intent：`ACTION_OPEN_DOCUMENT` + `CATEGORY_OPENABLE` + 通配 `type`
     * （星号+斜杠+星号）+ `EXTRA_MIME_TYPES = [application/json, application/octet-stream]`。
     *
     * 为什么 `type` 要写通配再收窄：直接设 `application/json` 会让部分 Rom 的选择器
     * 过滤掉扩展名为 `.mikcb` 的文件（系统按扩展名映射不出 `application/json`），
     * 用户就会看到「我明明有这个文件，列表里却没有」。
     *
     * 与 `ActivityResultContracts.OpenDocument()`（输入 `TransferShareContract.OPEN_MIME_TYPES`）等价。
     */
    fun openDocumentIntent(): Intent =
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, TransferShareContract.OPEN_MIME_TYPES.toTypedArray())
        }

    /**
     * 读用户选中的文件为文本。
     *
     * 顺序：
     * 1. 查 `OpenableColumns.SIZE`，用 [TransferShareContract.exceedsLimit] 判（边界值 = 不超）；
     * 2. 查不到大小或没超时，限长读：累计超过上限立刻停并返回 [ReadResult.TooLarge]；
     * 3. 严格 UTF-8 解码（[TransferTextDecoding.decodeStrictUtf8]），畸形字节返回 [ReadResult.InvalidEncoding]。
     *
     * 不判「解码后是空字符串」算不算失败：空文件属内容问题，交给模型层给「文件无法识别」
     * 之类的结论，这里只负责「字节有没有拿到」。
     */
    fun readText(
        uri: Uri,
        maxBytes: Int = TransferShareContract.MAX_IMPORT_BYTES,
    ): ReadResult {
        // 1) 能拿到声明大小就先短路，一个字节都不读。
        val declaredSize = querySize(uri)
        if (declaredSize != null && TransferShareContract.exceedsLimit(declaredSize, maxBytes)) {
            return ReadResult.TooLarge
        }

        // 2) 限长读。readBounded 返回 null = 读的过程中越界。
        val bytes = try {
            readBounded(uri, maxBytes) ?: return ReadResult.TooLarge
        } catch (e: SecurityException) {
            return ReadResult.ReadFailed
        } catch (e: IOException) {
            return ReadResult.ReadFailed
        } catch (e: RuntimeException) {
            // 少数 provider 会在 openInputStream 里抛别的运行时异常（如已卸载的文档 provider）。
            return ReadResult.ReadFailed
        }

        // 3) 严格 UTF-8 解码。畸形字节直接拒绝（与 Dart `utf8.decode` 同口径），
        // 不做替换字符兜底——否则损坏包会带着乱码被当成合法 JSON 导进去。
        val text = TransferTextDecoding.decodeStrictUtf8(bytes)
            ?: return ReadResult.InvalidEncoding
        return ReadResult.Success(text)
    }

    // ------------------------------------------------------------------
    // 内部：限长读 / 尺寸查询
    // ------------------------------------------------------------------

    /**
     * 从 Uri 限长读取：累计超过 [maxBytes] 立刻返回 null（**不读满内存**）。
     *
     * 缓冲区固定 64 KiB，与 [AndroidSafBackupAdapter] 同口径；判据是「累计 > 上限」，
     * 恰好等于上限的文件读得完整、正常返回。
     */
    private fun readBounded(uri: Uri, maxBytes: Int): ByteArray? {
        val stream = context.contentResolver.openInputStream(uri)
            ?: throw IOException("openInputStream returned null")
        return stream.use { input ->
            val out = ByteArrayOutputStream(minOf(maxBytes, 64 * 1024))
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxBytes) return@use null
                out.write(buffer, 0, read)
            }
            out.toByteArray()
        }
    }

    /** 查 provider 上报的文件大小（拿不到返回 null，交给限长读兜底）。 */
    private fun querySize(uri: Uri): Long? = try {
        context.contentResolver
            .query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (index >= 0 && !cursor.isNull(index)) cursor.getLong(index) else null
                } else {
                    null
                }
            }
    } catch (_: Exception) {
        null
    }
}
