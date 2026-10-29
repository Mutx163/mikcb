package com.mutx163.qingyu.platform

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import com.mutx163.qingyu.ExternalImportReader
import com.mutx163.qingyu.pages.import.ImportTemplateModel
import com.mutx163.qingyu.share.TransferShareContract
import java.io.File
import java.io.IOException

/**
 * 导入三页的 **Android 胶水**：把 SAF 选中的 `content://` 读成有上限的字节，
 * 以及把内置模板分享出去。
 *
 * ## 为什么不复用 `AndroidSafBackupAdapter`
 *
 * 那个适配器**不是通用选文件工具**：它的 `read` 会把内容喂给
 * `BackupFileReadLogic.read`（按备份 JSON 解析并返回 `SafImportOutcome`），
 * 拿它读 `.ics` / `.csv` 等于先做一次无关的备份校验——它**真不够用**，不是没找。
 * 所以这里只补「读字节 + 报尺寸」这一小段（30 行），解析仍全部交给导入域的模型。
 *
 * 尺寸上限直接调现成的 [ExternalImportReader.readCapped]（与「外部应用分享进来」
 * 那条路同一个实现：边读边判，超了立刻丢，绝不先把整份读进内存）。
 *
 * ## 分享模板为什么不用 `AndroidTransferShareAdapter`
 *
 * 那条路的契约把 MIME 钉死成 `application/json`（`.mikcb` 包体专用）。用它将就着
 * 分享 CSV，接收方会按 JSON 打开、直接报格式错。所以这里自己拼一次 `ACTION_SEND`，
 * MIME 用 [ImportTemplateModel.MIME_TYPE]，落盘目录复用 `res/xml/file_paths.xml` 里
 * **已登记**的 `transfer-share/`——不新增 `<cache-path>`，不碰 manifest 与 res/xml。
 *
 * ## 进不了 JVM 单测（诚实说明）
 *
 * 本文件引 `android.*`，只能靠编译通过与真机验收；所有能推的判据（MIME 候选、
 * 文件名、落盘相对路径、模板正文）都在纯 Kotlin 的 `pages/import/` 里，有单测。
 */
class AndroidImportDocumentReader(private val context: Context) {

    sealed interface Result {
        /** 读成功。[fileName] 取自 provider 的 `DISPLAY_NAME`，拿不到为 null。 */
        data class Bytes(val bytes: ByteArray, val fileName: String?) : Result

        /** 超过 [read] 传入的上限（含 provider 自报尺寸超限的短路）。 */
        data object TooLarge : Result

        /** 打不开流 / 权限问题（用户删了文件、provider 撤销授权）。 */
        data object ReadFailed : Result
    }

    /**
     * 限长读一个 `content://`。
     *
     * 顺序：先看 `OpenableColumns.SIZE` 短路（有些 provider 会直接报大小，省一次读），
     * 再走限长读。两者任一超限都返回 [Result.TooLarge]——**不抛异常**，让宿主
     * 走「文件太大」这条真错误分支，而不是静默失败。
     */
    fun read(uri: Uri, maxBytes: Long): Result {
        val fileName = displayName(uri)
        val declared = declaredSize(uri)
        if (declared != null && declared > maxBytes) {
            return Result.TooLarge
        }
        val stream = try {
            context.contentResolver.openInputStream(uri) ?: return Result.ReadFailed
        } catch (e: SecurityException) {
            return Result.ReadFailed
        } catch (e: IOException) {
            return Result.ReadFailed
        }
        val bytes = try {
            stream.use { ExternalImportReader.readCapped(it, maxBytes) }
        } catch (e: SecurityException) {
            return Result.ReadFailed
        } catch (e: IOException) {
            return Result.ReadFailed
        } ?: return Result.TooLarge
        return Result.Bytes(bytes = bytes, fileName = fileName)
    }

    /** provider 上报的用户可见文件名（SAF 的 `DISPLAY_NAME`）；查不到返回 null。 */
    fun displayName(uri: Uri): String? = try {
        context.contentResolver
            .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0 && !cursor.isNull(index)) cursor.getString(index) else null
                } else {
                    null
                }
            }
    } catch (e: SecurityException) {
        null
    } catch (e: RuntimeException) {
        // 个别第三方 provider 会在 query 上抛（stale cursor 之类），名字拿不到不影响导入。
        null
    }

    private fun declaredSize(uri: Uri): Long? = try {
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
    } catch (e: SecurityException) {
        null
    } catch (e: RuntimeException) {
        null
    }
}

/**
 * 「下载轻屿课表模板」的落盘 + 分享。
 *
 * 写进 `cacheDir/transfer-share/<FILE_NAME>`（已登记的 FileProvider 目录），
 * 再 `ACTION_SEND` + `text/csv` 拉起系统分享面板。
 */
class AndroidImportTemplateSharer(
    private val context: Context,
    /**
     * 派生 FileProvider authority 的 applicationId。默认取 [Context.getPackageName]：
     * 运行期就是当前变体的 applicationId（含 `.debug` / `.ui` 后缀），
     * 与 manifest 里的 `${applicationId}.fileprovider` 一致。
     */
    private val applicationId: String = context.packageName,
) {

    sealed interface Outcome {
        /** 分享面板已拉起。 */
        data class Launched(val fileName: String) : Outcome

        /** 没拉起来，原因见 [reason]。 */
        data class Failed(val reason: Failure) : Outcome
    }

    enum class Failure {
        /** 写不进缓存目录（磁盘满 / 目录没了 / 权限异常）。 */
        WRITE_FAILED,

        /** FileProvider 没注册，或 `res/xml` 没覆盖 `transfer-share/`。 */
        PROVIDER_UNAVAILABLE,

        /** 这台设备没有任何接分享的面板。 */
        NO_TARGET,

        /** 启动被系统拒绝（SecurityException / 非 Activity 上下文漏 NEW_TASK 之类）。 */
        LAUNCH_FAILED,
    }

    /** 把模板正文写进缓存目录；失败返回 null（不抛）。 */
    fun writeTemplate(content: String = ImportTemplateModel.CONTENT): File? {
        val target = File(context.cacheDir, ImportTemplateModel.CACHE_RELATIVE_PATH)
        return try {
            target.parentFile?.mkdirs()
            target.writeText(content, Charsets.UTF_8)
            target
        } catch (e: IOException) {
            null
        } catch (e: SecurityException) {
            null
        }
    }

    /** 一条龙：写缓存 → content Uri → 选择器 → 拉起分享面板。 */
    fun shareTemplate(subject: String = ImportTemplateModel.FILE_NAME): Outcome {
        val target = writeTemplate() ?: return Outcome.Failed(Failure.WRITE_FAILED)
        val contentUri = try {
            FileProvider.getUriForFile(
                context,
                // 唯一出处：`share/TransferShareContract.providerAuthority`（纯 Kotlin、有单测）。
                TransferShareContract.providerAuthority(applicationId),
                target,
            )
        } catch (e: IllegalArgumentException) {
            return Outcome.Failed(Failure.PROVIDER_UNAVAILABLE)
        }
        val chooser = Intent(Intent.ACTION_CHOOSER).apply {
            putExtra(
                Intent.EXTRA_INTENT,
                Intent(Intent.ACTION_SEND).apply {
                    type = ImportTemplateModel.MIME_TYPE
                    putExtra(Intent.EXTRA_STREAM, contentUri)
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    clipData = ClipData.newRawUri(ImportTemplateModel.FILE_NAME, contentUri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                },
            )
        }
        if (chooser.resolveActivity(context.packageManager) == null) {
            return Outcome.Failed(Failure.NO_TARGET)
        }
        return try {
            context.startActivity(chooser)
            Outcome.Launched(ImportTemplateModel.FILE_NAME)
        } catch (e: ActivityNotFoundException) {
            Outcome.Failed(Failure.NO_TARGET)
        } catch (e: SecurityException) {
            Outcome.Failed(Failure.LAUNCH_FAILED)
        } catch (e: RuntimeException) {
            Outcome.Failed(Failure.LAUNCH_FAILED)
        }
    }
}
