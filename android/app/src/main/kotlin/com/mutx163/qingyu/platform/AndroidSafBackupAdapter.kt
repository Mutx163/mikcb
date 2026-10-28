package com.mutx163.qingyu.platform

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import com.mutx163.qingyu.pages.sync.BackupExportOutcome
import com.mutx163.qingyu.pages.sync.BackupFileFailureKind
import com.mutx163.qingyu.pages.sync.BackupFileReadLogic
import com.mutx163.qingyu.pages.sync.BackupFileReadResult
import com.mutx163.qingyu.pages.sync.BackupFileWriteLogic
import com.mutx163.qingyu.pages.sync.BackupFileWriteResult
import com.mutx163.qingyu.pages.sync.BackupIoFailure
import com.mutx163.qingyu.pages.sync.BackupSafContract
import com.mutx163.qingyu.pages.sync.CoupleStrings
import com.mutx163.qingyu.pages.sync.SafImportOutcome
import com.mutx163.qingyu.pages.sync.WriteFailure
import com.mutx163.qingyu.pages.sync.WriteSuccess
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.time.LocalDateTime

/**
 * 本地备份「选文件 / 存文件」的 **SAF 适配器**（C2 的 Android 胶水半边）。
 *
 * ## 这一层只做三件事
 *
 * 1. **拼 SAF Intent**：导入用 `ACTION_OPEN_DOCUMENT`、导出用 `ACTION_CREATE_DOCUMENT`，
 *    所有 action / MIME / 文件名判据来自 [BackupSafContract]（纯 Kotlin、JVM 单测覆盖）；
 * 2. **Uri ⇄ 字节**：从 `content://` 读字节（先按 OpenableColumns.SIZE 短路，再限长读，绝不把
 *    超大文件读进内存）、把 UTF-8 文本写进 `content://`；
 * 3. **转交模型**：读到的文本交给 [BackupFileReadLogic.read]；要写的快照交给
 *    [BackupFileWriteLogic.write]。
 *
 * 本类**不自己拍任何字符串**（MIME/名/动作都在契约层），也**不渲染任何用户文案**
 * （toast 由壳接线层按 ARB 决定；本类只返回带分类的结局枚举）。
 *
 * ## 为什么在这里而不是 `pages/sync/`
 *
 * `scripts/test-kotlin-module.ps1` 的「纯 Kotlin」判定是整目录的：一个 `import android.*`
 * 会让整个目录被 JVM 单测跳过。所以任何 `Context` / `Uri` / `Intent` 胶水一律留在 `platform/`，
 * 与 [PrefsKeyValueStore] / [AndroidShareAdapter] 同一约定。
 *
 * ## 壳侧还要做什么（属 Lead，不在本类）
 *
 * SAF 的「拉起系统选择器并接回结果」需要 Activity 的 `registerForActivityResult` 或
 * `onActivityResult`，这在壳 Activity 上注册。**不需要改 AndroidManifest**（SAF 用的是系统
 * 文档选择器，不像 FileProvider 那样要 `<provider>`）。具体注册清单见交付说明。
 *
 * ## 诚实边界
 *
 * 本类进不了 JVM 单测（引 `android.*`），真机「选文件→恢复后数据真回来 / 导出文件能被别的
 * 应用打开」只能由用户在真机（L4）验证。此处仅保证「编译通过」与「纯逻辑单测过」。
 */
class AndroidSafBackupAdapter(private val context: Context) {

    // ------------------------------------------------------------------
    // SAF Intent（接线层把这两个 Intent 交给 registerForActivityResult 或 startActivityForResult）
    // ------------------------------------------------------------------

    /**
     * 导入用的「打开文档」Intent。
     *
     * 形态：`ACTION_OPEN_DOCUMENT` + `CATEGORY_OPENABLE` + 通配 `type`（星号+斜杠+星号）+
     * `EXTRA_MIME_TYPES=[application/json, application/octet-stream]`。
     * 与 `ActivityResultContracts.OpenDocument()`（输入 `BackupSafContract.OPEN_MIME_TYPES`）等价。
     */
    fun openDocumentIntent(): Intent =
        Intent(BackupSafContract.ACTION_OPEN_DOCUMENT).apply {
            addCategory(BackupSafContract.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(BackupSafContract.EXTRA_MIME_TYPES, BackupSafContract.OPEN_MIME_TYPES)
        }

    /**
     * 导出用的「新建文档」Intent（默认文件名 = 当前时间的
     * `mikcb-backup-yyyyMMdd-HHmm.json`）。
     *
     * 与 `ActivityResultContracts.CreateDocument(BackupSafContract.MIME_JSON)` 等价。
     */
    fun createDocumentIntent(
        fileName: String = BackupSafContract.defaultFileName(LocalDateTime.now()),
    ): Intent =
        Intent(BackupSafContract.ACTION_CREATE_DOCUMENT).apply {
            addCategory(BackupSafContract.CATEGORY_OPENABLE)
            type = BackupSafContract.MIME_JSON
            putExtra(BackupSafContract.EXTRA_TITLE, fileName)
        }

    // ------------------------------------------------------------------
    // 导入：Uri → 字节 → 读模型
    // ------------------------------------------------------------------

    /**
     * 读用户选中的备份文件并交给读模型。
     *
     * 顺序：先按 `OpenableColumns.SIZE` 短路超大文件（不读内存），再限长读（超过上限立即停，
     * 同样不读满），最后 UTF-8 解码后交给 [BackupFileReadLogic.read]。
     * 「文件太大」由读模型给 [BackupFileFailureKind.FILE_TOO_LARGE]，统一在
     * [SafImportOutcome.Parsed] 里，接线层不需要为它单独分支。
     */
    fun read(uri: Uri, maxBytes: Int = BackupFileReadLogic.MAX_FILE_BYTES): SafImportOutcome {
        val declaredSize = querySize(uri)
        if (declaredSize != null && declaredSize > maxBytes) {
            return SafImportOutcome.Parsed(tooLargeFailure(maxBytes, "declared=$declaredSize"))
        }
        val bytes = try {
            readBounded(uri, maxBytes) ?: return SafImportOutcome.Parsed(
                tooLargeFailure(maxBytes, "read>limit"),
            )
        } catch (e: SecurityException) {
            return SafImportOutcome.IoFailed(BackupIoFailure.SECURITY_ERROR)
        } catch (e: IOException) {
            return SafImportOutcome.IoFailed(BackupIoFailure.OPEN_INPUT_FAILED)
        }
        val content = String(bytes, Charsets.UTF_8)
        return SafImportOutcome.Parsed(BackupFileReadLogic.read(content, maxBytes))
    }

    // ------------------------------------------------------------------
    // 导出：快照 → 写模型 → 字节 → Uri
    // ------------------------------------------------------------------

    /**
     * 把快照写成 JSON 并落进用户选中的文件。
     *
     * 先让 [BackupFileWriteLogic.write] 产出「一定能读回」的自校验文本（信封/空课表/字节上限
     * 都先自检），落盘失败再折算成 [BackupExportOutcome.IoFailed]。全程不抛异常。
     *
     * @param fileName 仅用于回报（写进 [BackupExportOutcome.Saved.fileName]），实际文件名由
     *   `ACTION_CREATE_DOCUMENT` 的 `EXTRA_TITLE` 预填、用户可改，落盘以 Uri 为准。
     */
    fun write(
        uri: Uri,
        snapshot: Map<String, Any?>,
        declaredSha256: String? = null,
        fileName: String = BackupSafContract.defaultFileName(LocalDateTime.now()),
    ): BackupExportOutcome {
        return when (val result = BackupFileWriteLogic.write(snapshot, declaredSha256)) {
            is WriteFailure -> BackupExportOutcome.Rejected(result)
            is WriteSuccess -> {
                try {
                    val out = context.contentResolver.openOutputStream(uri)
                        ?: return BackupExportOutcome.IoFailed(BackupIoFailure.OPEN_OUTPUT_FAILED)
                    out.use { stream ->
                        stream.write(result.content.toByteArray(Charsets.UTF_8))
                        stream.flush()
                    }
                    BackupExportOutcome.Saved(
                        fileName = fileName,
                        byteLength = result.byteLength,
                        checksumEmbedded = result.checksumEmbedded,
                    )
                } catch (e: SecurityException) {
                    BackupExportOutcome.IoFailed(BackupIoFailure.SECURITY_ERROR)
                } catch (e: IOException) {
                    BackupExportOutcome.IoFailed(BackupIoFailure.IO_ERROR)
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // 内部：限长读 / 尺寸查询 / 构造「太大」失败
    // ------------------------------------------------------------------

    /**
     * 从 Uri 限长读取。超过 [maxBytes] 返回 null（不读满内存）；正常返回整段字节。
     * 打不开流抛 [IOException]，权限问题抛 [SecurityException]，由调用方折算。
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

    /**
     * 构造与读模型同口径的「文件太大」失败（复用 [CoupleStrings.importFileTooLarge] 文案与
     * [BackupFileReadLogic.formatByteBudget] 预算格式，不另造字符串）。
     */
    private fun tooLargeFailure(maxBytes: Int, note: String): BackupFileReadResult.Failure =
        BackupFileReadResult.Failure(
            kind = BackupFileFailureKind.FILE_TOO_LARGE,
            errorCode = null,
            userMessage = CoupleStrings.importFileTooLarge.filled(
                "size",
                BackupFileReadLogic.formatByteBudget(maxBytes.toLong()),
            ),
            damage = "$note; limit=$maxBytes",
        )
}
