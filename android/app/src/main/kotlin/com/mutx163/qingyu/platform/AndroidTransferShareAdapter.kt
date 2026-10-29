package com.mutx163.qingyu.platform

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.mutx163.qingyu.share.TransferShareContract
import java.io.File
import java.io.IOException

/**
 * 「数据备份与迁移」页 `.mikcb` 传输包的**系统分享适配器**（Android 胶水半边）。
 *
 * 职责只有三件：把包体写成 `cacheDir/transfer-share/<fileName>` → 用 `FileProvider`
 * 换成 content Uri → `Intent.createChooser` 拉起系统分享面板。
 *
 * **所有判据来自 [TransferShareContract]**（纯 Kotlin、JVM 单测覆盖）：authority、缓存目录、
 * 相对路径、MIME、字节上限、失败分类全由它给，本类不自己拍字符串——否则这些值将没有任何
 * 测试能钉住（本文件引 `android.*`，进不了单测 classpath）。手势照抄同目录的
 * [AndroidShareAdapter]（ICS 分享），差异只有两点：文件名/正文由调用方给（`.mikcb` 包体是
 * 现成的 JSON 文本），失败分类多一项 `PROVIDER_UNAVAILABLE`。
 *
 * ## 为什么 manifest 里还没有 provider 也能编译、也能跑
 *
 * provider 的 `<provider>` 声明属 Lead（多会话共用 manifest，本泳道不许碰）。**没注册时**
 * [share] 会稳定返回 [TransferShareContract.Failure.PROVIDER_UNAVAILABLE]——不崩、不静默无反应、
 * 也不会误报成「写盘失败」。注册要粘的片段见本批交付说明。
 *
 * ## 真机未验（L4）
 *
 * 「系统分享面板是否真的弹出」「目标应用能否打开收到的 `.mikcb`」只能由用户在真机上验证；
 * 本类只保证编译通过与纯逻辑单测（契约层）通过。
 */
class AndroidTransferShareAdapter(
    private val context: Context,
    /**
     * 派生 FileProvider authority 的 applicationId。默认取 [Context.getPackageName]：
     * 运行期它就是当前变体的 applicationId（`dev` / `perf` / `itest` 分别带
     * `.debug` / `.profile` / `.itest` 后缀），与 manifest 里 `${applicationId}.fileprovider` 一致。
     */
    private val applicationId: String = context.packageName,
) {

    /** 分享的两种结局。**不抛异常**：任何失败都折算成 [Failed] 里的分类。 */
    sealed interface Outcome {

        /** 选择器已拉起。[fileName] 是落地的缓存文件名，[uri] 是交给目标应用读的 content Uri。 */
        data class Launched(val fileName: String, val uri: String) : Outcome

        /** 没拉起来（或没写出去），原因见 [failure]。 */
        data class Failed(val failure: TransferShareContract.Failure) : Outcome
    }

    /**
     * 一条龙：写缓存文件（UTF-8）→ content Uri → 选择器 → 拉起系统分享面板。
     *
     * Intent 形状：`ACTION_SEND` + `type=application/json` + `EXTRA_STREAM`（文件）+
     * `EXTRA_TEXT` / `EXTRA_SUBJECT`（附言与主题）+ `FLAG_GRANT_READ_URI_PERMISSION` + `ClipData`。
     * 授读权限必须**两处都给**：只给 `EXTRA_STREAM`、不挂 `ClipData` 时，部分接收方会拿不到
     * 读权限而打不开文件（ICS 适配器同款注释，2026-10 踩过）。
     *
     * 上下文不是 [Activity]（本仓 wiring 传的就是 `applicationContext`）时必须补
     * `FLAG_ACTIVITY_NEW_TASK`，否则 `startActivity` 直接抛。
     *
     * 失败分类：
     * - 文件名不安全（空 / 带路径分隔符 / 带 `..`）→ [TransferShareContract.Failure.WRITE_FAILED]
     *   （宁可明确失败，也不要让 `FileProvider` 拒掉后误报成 provider 问题）；
     * - 写盘 `IOException` / `SecurityException` → `WRITE_FAILED`；
     * - `FileProvider.getUriForFile` 抛 `IllegalArgumentException`（provider 未注册 / 路径没声明）
     *   → `PROVIDER_UNAVAILABLE`；
     * - 选择器解析不到（`resolveActivity == null`）→ `NO_TARGET`；
     * - `startActivity` 抛 `ActivityNotFoundException` → `NO_TARGET`，抛别的运行时异常
     *   → `LAUNCH_FAILED`。
     */
    fun share(
        fileName: String,
        content: String,
        shareText: String,
        shareSubject: String,
    ): Outcome {
        // 1) 文件名护栏：缓存目录之外的文件不该被 FileProvider 授出去。
        //    providerCacheRelativePath 只是字符串拼接，不校验；这里补上唯一的一处校验。
        if (fileName.isBlank() || fileName.contains('/') || fileName.contains('\\') ||
            fileName.contains("..")
        ) {
            return Outcome.Failed(TransferShareContract.Failure.WRITE_FAILED)
        }

        // 2) 落盘（UTF-8）。IOException = 磁盘满/目录没了；SecurityException = 权限异常。
        val target = File(
            context.cacheDir,
            TransferShareContract.providerCacheRelativePath(fileName),
        )
        try {
            target.parentFile?.mkdirs()
            target.writeText(content, Charsets.UTF_8)
        } catch (e: IOException) {
            return Outcome.Failed(TransferShareContract.Failure.WRITE_FAILED)
        } catch (e: SecurityException) {
            return Outcome.Failed(TransferShareContract.Failure.WRITE_FAILED)
        }

        // 3) authority 由契约派生；applicationId 非法时不必再试 provider，直接归到 provider 这一类。
        val authority = try {
            TransferShareContract.providerAuthority(applicationId)
        } catch (e: IllegalArgumentException) {
            return Outcome.Failed(TransferShareContract.Failure.PROVIDER_UNAVAILABLE)
        }

        // 4) file:// → content://；provider 未注册或路径未声明都会抛 IllegalArgumentException。
        val contentUri = try {
            FileProvider.getUriForFile(context, authority, target)
        } catch (e: IllegalArgumentException) {
            return Outcome.Failed(TransferShareContract.Failure.PROVIDER_UNAVAILABLE)
        }

        val chooser = createChooser(contentUri, fileName, shareText, shareSubject)

        // 5) 先解析再拉起。检查的是**选择器**（`android.intent.action.CHOOSER`）而不是内层
        //    ACTION_SEND：选择器由系统框架自己提供，不受 Android 11+ 包可见性（<queries>）过滤，
        //    所以这里为 null 就是「这台机器真没有分享面板」，不会因为没写 <queries> 而误报。
        if (chooser.resolveActivity(context.packageManager) == null) {
            return Outcome.Failed(TransferShareContract.Failure.NO_TARGET)
        }

        return try {
            context.startActivity(chooser)
            Outcome.Launched(fileName = fileName, uri = contentUri.toString())
        } catch (e: ActivityNotFoundException) {
            Outcome.Failed(TransferShareContract.Failure.NO_TARGET)
        } catch (e: SecurityException) {
            Outcome.Failed(TransferShareContract.Failure.LAUNCH_FAILED)
        } catch (e: RuntimeException) {
            // AndroidRuntimeException 之类（例如非 Activity 上下文漏了 NEW_TASK 的旧机型）。
            Outcome.Failed(TransferShareContract.Failure.LAUNCH_FAILED)
        }
    }

    /**
     * 拼「发给目标应用的那个 Intent」再包一层选择器。
     *
     * 单独抽出来是为了排障与将来的单测留口子（本类进不了 JVM 单测，但壳侧可以手工调它看形状）。
     */
    private fun createChooser(
        contentUri: Uri,
        fileName: String,
        shareText: String,
        shareSubject: String,
    ): Intent {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = TransferShareContract.MIME_JSON
            putExtra(Intent.EXTRA_STREAM, contentUri)
            putExtra(Intent.EXTRA_TEXT, shareText)
            putExtra(Intent.EXTRA_SUBJECT, shareSubject)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            // 部分接收方只认 ClipData 里的 Uri（只给 EXTRA_STREAM 会拿到一个打不开的 Uri）。
            clipData = ClipData.newRawUri(fileName, contentUri)
        }
        val chooser = Intent.createChooser(send, null)
        // 某些机型只在选择器这一层认授读标记，两层都加（ICS 适配器同款处置）。
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (context !is Activity) {
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return chooser
    }
}
