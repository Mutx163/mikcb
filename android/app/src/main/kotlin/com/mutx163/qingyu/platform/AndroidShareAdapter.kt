package com.mutx163.qingyu.platform

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.mutx163.qingyu.pages.export.IcsShareLogic
import com.mutx163.qingyu.pages.export.IcsShareSpec
import java.io.File
import java.io.IOException
import java.time.LocalDate

/**
 * 分享结果的三种结局（页面据此弹 toast：成功 / 已取消由系统面板自身负责 / 失败）。
 *
 * `Failed` 的 [IcsShareFailure] 是给**接线与排障**用的细分原因，不含任何用户可见文案
 * （文案走 ARB，属 Lead 补文案的范围；本批不新造键）。
 */
sealed interface IcsShareOutcome {

    /** 选择器已拉起。[fileName] 为落地的 `.ics` 名。 */
    data class Launched(val fileName: String) : IcsShareOutcome

    /** 没拉起来，原因见 [reason]。 */
    data class Failed(val reason: IcsShareFailure) : IcsShareOutcome
}

/** 分享失败的具体原因。 */
enum class IcsShareFailure {

    /**
     * 文件写不进缓存目录（磁盘满、目录被删、权限异常）。
     * 对应 Dart 的 `IcsExportFailed` 分支。
     */
    WRITE_FAILED,

    /**
     * `FileProvider` 不可用 —— **当前仓库的真实状态**：`AndroidManifest.xml` 里还没有
     * `<provider android:name="androidx.core.content.FileProvider" .../>` 注册
     * （全仓 `FileProvider` 0 处，注册属 Lead）。另一种成因是 `res/xml` 下的路径声明 xml
     * 没有覆盖 `cacheDir/ics-export/`。
     */
    PROVIDER_UNAVAILABLE,

    /**
     * provider 起来了但形状与本批契约不符（authority 或第一段路径不是 `ics_export`，
     * 说明 xml 的 `<cache-path name="…">` 与本批常量漂了）。
     */
    PROVIDER_MISMATCH,

    /** 设备上没有任何能接 `text/calendar` 的应用（`ActivityNotFoundException`）。 */
    NO_TARGET,

    /** 系统拒绝拉起（`SecurityException` 等非「无目标」的启动失败）。 */
    LAUNCH_FAILED,
}

/**
 * ICS 导出文件的**系统分享适配器**（I3A）。
 *
 * 职责只有三件：把 `.ics` 写进自己缓存目录 → `FileProvider.getUriForFile` 换成 content Uri →
 * `Intent.createChooser` 拉起系统分享面板。
 *
 * **所有判据来自 [com.mutx163.qingyu.pages.export.IcsShareLogic]**（纯 Kotlin、JVM 单测覆盖）：
 * 文件名、MIME、action、extras 键、authority、相对路径、chooser 标题全由它给，
 * 本类不自己拍任何字符串 —— 否则这些值将没有任何测试能钉住（本文件引 `android.*`，进不了单测）。
 *
 * **未接线的部分（诚实说明）**：
 * 1. `AndroidManifest.xml` 的 `<provider>` 与 `res/xml` 路径声明属 Lead，本批未做；
 *    注册前 [share] 会稳定返回 [IcsShareFailure.PROVIDER_UNAVAILABLE]，不会崩、不会静默无反应。
 * 2. 页面调用点（`IcsExportPage` 的 `onShareExported`）属别批写作用域，本批未接。
 * 3. 真机（L4）未验：系统分享面板是否真的弹出、文件能否落到目标应用，归用户。
 *
 * 用法（接线后）：
 * ```
 * when (val outcome = adapter.share(content, profile.name, from, to)) {
 *     is IcsShareOutcome.Launched -> toast(icsExportShared)
 *     is IcsShareOutcome.Failed -> toast(icsExportFailed)
 * }
 * ```
 */
class AndroidShareAdapter(
    private val context: Context,
    /**
     * 派生 FileProvider authority 的 applicationId。默认取 [Context.getPackageName]：
     * 运行期它就是当前变体的 applicationId（含 `.debug` / `.profile` / `.itest` / `.ui` 后缀），
     * 与 manifest 里 `${applicationId}.fileprovider` 一致。
     */
    private val applicationId: String = context.packageName,
) {

    /** 只算契约、不碰文件系统（排障/单测友好）。 */
    fun specFor(profileName: String, from: LocalDate, to: LocalDate): IcsShareSpec =
        IcsShareLogic.spec(applicationId, profileName, from, to)

    /**
     * 把 ICS 正文写进 `cacheDir/<IcsShareLogic.SHARE_DIR_NAME>/<fileName>`（UTF-8）。
     *
     * 写失败返回 null（不抛）：调用方据此走 [IcsShareFailure.WRITE_FAILED]。
     */
    fun writeIcs(spec: IcsShareSpec, content: String): File? {
        val target = File(context.cacheDir, spec.localRelativePath)
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

    /**
     * 由契约 + content Uri 拼装「发给目标应用的那个 Intent」，再包一层选择器。
     *
     * 授读权限做两件事：Intent 上加 `FLAG_GRANT_READ_URI_PERMISSION`，并挂 `ClipData`
     * （部分接收方只认 ClipData 里的 Uri，只给 `EXTRA_STREAM` 会导致那边打不开文件）。
     */
    fun createChooser(spec: IcsShareSpec, contentUri: Uri): Intent {
        val send = Intent(spec.action).apply {
            type = spec.mimeType
            putExtra(spec.extraStreamKey, contentUri)
            putExtra(spec.extraTextKey, spec.text)
            putExtra(spec.extraSubjectKey, spec.subject)
            if (spec.grantReadPermission) {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = ClipData.newRawUri(spec.clipDataLabel, contentUri)
            }
        }
        val chooser = Intent.createChooser(send, spec.chooserTitle)
        if (spec.grantReadPermission) {
            // 某些机型只在选择器这一层认授读标记，两层都加。
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (context !is Activity) {
            // 非 Activity 上下文（Application/Service/Composable 的 LocalContext 常见是 Activity，
            // 但不保证）必须带 NEW_TASK，否则 startActivity 直接抛。
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return chooser
    }

    /**
     * 一条龙：写文件 → content Uri → 选择器 → 拉起系统分享面板。
     *
     * 全程不抛异常：任何失败都折算成 [IcsShareOutcome.Failed]，调用方按枚举分支处理。
     */
    fun share(
        content: String,
        profileName: String,
        from: LocalDate,
        to: LocalDate,
    ): IcsShareOutcome {
        val spec = specFor(profileName, from, to)
        val file = writeIcs(spec, content)
            ?: return IcsShareOutcome.Failed(IcsShareFailure.WRITE_FAILED)

        val contentUri = try {
            FileProvider.getUriForFile(context, spec.providerAuthority, file)
        } catch (e: IllegalArgumentException) {
            // provider 未注册 / 路径未声明：都是「声明侧还没补」，不 crash。
            return IcsShareOutcome.Failed(IcsShareFailure.PROVIDER_UNAVAILABLE)
        }

        val matches = IcsShareLogic.contentUriMatches(
            expectedAuthority = spec.providerAuthority,
            uriAuthority = contentUri.authority,
            firstPathSegment = contentUri.pathSegments.firstOrNull(),
        )
        if (!matches) {
            return IcsShareOutcome.Failed(IcsShareFailure.PROVIDER_MISMATCH)
        }

        return try {
            context.startActivity(createChooser(spec, contentUri))
            IcsShareOutcome.Launched(spec.fileName)
        } catch (e: ActivityNotFoundException) {
            IcsShareOutcome.Failed(IcsShareFailure.NO_TARGET)
        } catch (e: SecurityException) {
            IcsShareOutcome.Failed(IcsShareFailure.LAUNCH_FAILED)
        }
    }
}
