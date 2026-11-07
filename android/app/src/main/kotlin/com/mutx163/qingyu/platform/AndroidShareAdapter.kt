package com.mutx163.qingyu.platform

import android.app.Activity
import android.app.PendingIntent
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import androidx.core.content.FileProvider
import com.mutx163.qingyu.pages.export.IcsShareLaunchSignal
import com.mutx163.qingyu.pages.export.IcsShareLogic
import com.mutx163.qingyu.pages.export.IcsShareSpec
import java.io.File
import java.io.IOException
import java.time.LocalDate

/**
 * 分享结果的三种结局（页面据此弹 toast：成功 / 已取消 / 失败）。
 *
 * 2026-11-05 之前这里只有 `Launched` / `Failed` 两种，而 `Launched` 是「送出了 Intent」——
 * 用户把系统面板划掉之后不会有任何提示。Dart（`share_plus`）在
 * `ShareResultStatus.dismissed` 时会弹「已取消分享日历」
 * （`v2.1.4.1:lib/screens/ics_export_screen.dart:805-811`），本类改成走
 * `IntentSender` + `ActivityResultContracts.StartIntentSenderForResult` 之后才拿得到
 * 「用户选了目标」还是「用户划掉了」这个信息。
 *
 * `Failed` 的 [IcsShareFailure] 是给**接线与排障**用的细分原因，不含任何用户可见文案
 * （文案走 ARB，属 Lead 补文案的范围；本批不新造键）。
 */
sealed interface IcsShareOutcome {

    /** 用户真的在分享面板里选定了目标应用（收到了 `EXTRA_CHOSEN_COMPONENT` 回执）。 */
    data object Shared : IcsShareOutcome

    /**
     * 用户把分享面板划掉了：面板关了、回执通道是通的、但没有任何目标被选中。
     *
     * **这不是失败**：Dart 同款只说「已取消分享日历」。归成 `Failed` 会让用户以为导出坏了，
     * 归成 `Shared` 会谎报「已分享 N 个事件」。
     */
    data object Cancelled : IcsShareOutcome

    /**
     * 面板关了，但**拿不到可信结果**（回执通道没接上——manifest 少一行接收器声明）。
     *
     * 此时宿主**不提示**：分不清「用户划掉」和「回执没送到」，宁可不说，
     * 也不能在用户分享成功之后跟他说「你取消了」。
     */
    data object Unconfirmed : IcsShareOutcome

    /** 拉起之前 / 拉起时就失败，原因见 [reason]。 */
    data class Failed(val reason: IcsShareFailure) : IcsShareOutcome
}

/**
 * 「准备分享」的两半结果：要么拿到了可拉起的 [Ready]，要么在拉起之前就失败了。
 *
 * 拆成两步是因为拉起必须由 Activity 的 launcher 做（要在自己的 Activity 里收结果），
 * 适配器拿不到 launcher，只能把 [Ready.chooser] 交回宿主去 launch。
 */
sealed interface IcsSharePreparation {

    /**
     * 可以拉起了：[chooser] 是带广播 sender 的选择器 Intent（宿主用
     * `ActivityResultContracts.StartActivityForResult` 拉起），[resultRelayAvailable] 表示
     * 回执通道是否可用（manifest 是否声明了接收器）——不可用时宿主对「没回执」保持沉默。
     */
    data class Ready(
        val spec: IcsShareSpec,
        val chooser: Intent,
        val resultRelayAvailable: Boolean,
    ) : IcsSharePreparation

    /** 拉起之前就失败（写文件 / FileProvider / Uri 形状）。 */
    data class Failed(val reason: IcsShareFailure) : IcsSharePreparation
}

/** 分享失败的具体原因。 */
enum class IcsShareFailure {

    /**
     * 文件写不进缓存目录（磁盘满、目录被删、权限异常）。
     * 对应 Dart 的 `IcsExportFailed` 分支。
     */
    WRITE_FAILED,

    /**
     * `FileProvider` 不可用：manifest 里的 `<provider>` 没注册，或 `res/xml` 的路径声明
     * 没覆盖 `cacheDir/ics-export/`。
     *
     * （provider 已于 2026-10-29 由 Lead 注册进 `AndroidManifest.xml`；这条留着是因为
     * 声明漂了同样会走到这里，而不是去 crash。）
     */
    PROVIDER_UNAVAILABLE,

    /**
     * provider 起来了但形状与本批契约不符（authority 或第一段路径不是 `ics_export`，
     * 说明 xml 的 `<cache-path name="…">` 与本批常量漂了）。
     */
    PROVIDER_MISMATCH,

    /**
     * 拉起阶段失败（系统拒绝 / `IntentSender` 拿不到 / 设备上没有任何能接
     * `text/calendar` 的应用）。
     *
     * 不再细分「无目标」：真正 `launch` 发生在宿主侧（launcher 才能接结果），
     * 这里拿不到那个 `ActivityNotFoundException`；细分只会留下一个永远填不上的枚举值。
     */
    LAUNCH_FAILED,
}

/**
 * ICS 导出文件的**系统分享适配器**（I3A）。
 *
 * 职责只有三件：把 `.ics` 写进自己缓存目录 → `FileProvider.getUriForFile` 换成 content Uri →
 * 带着**结果回调 sender** 的 `Intent.createChooser` 交给宿主拉起（宿主用
 * `StartIntentSenderForResult` 才能知道用户是「选了目标」还是「划掉了」）。
 *
 * **所有判据来自 [com.mutx163.qingyu.pages.export.IcsShareLogic]**（纯 Kotlin、JVM 单测覆盖）：
 * 文件名、MIME、action、extras 键、authority、相对路径、chooser 标题全由它给，
 * 本类不自己拍任何字符串 —— 否则这些值将没有任何测试能钉住（本文件引 `android.*`，进不了单测）。
 *
 * **未接线的部分（诚实说明）**：
 * 1. 页面调用点（`IcsExportPage` 的 `onShareExported`）属别批写作用域，本批未接。
 * 2. 真机（L4）未验：系统分享面板是否真的弹出、取消是否真的收到 `RESULT_CANCELED`、
 *    文件能否落到目标应用，归用户。
 *
 * 用法（宿主侧，`IcsExportHost` 是这么接的）：
 * ```
 * val launcher = rememberLauncherForActivityResult(
 *     ActivityResultContracts.StartIntentSenderForResult(),
 * ) { result ->
 *     when (adapter.outcomeForResult(result.resultCode)) {
 *         is IcsShareOutcome.Shared -> toast(icsExportShared)
 *         IcsShareOutcome.Cancelled -> toast(icsExportCancelled)
 *         is IcsShareOutcome.Failed -> toast(icsExportFailed)
 *     }
 * }
 * when (val prepared = adapter.prepareShare(content, name, from, to)) {
 *     is IcsSharePreparation.Failed -> toast(icsExportFailed)
 *     is IcsSharePreparation.Ready -> launcher.launch(IntentSenderRequest.Builder(prepared.sender).build())
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
     *
     * [sender] 非空时用三参 `Intent.createChooser(intent, title, sender)`：用户选定目标会回
     * `RESULT_OK`、划掉面板会回 `RESULT_CANCELED`，这是唯一能区分「取消」和「成功」的拉起方式。
     */
    fun createChooser(spec: IcsShareSpec, contentUri: Uri, sender: IntentSender? = null): Intent {
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
        val chooser = if (sender != null) {
            Intent.createChooser(send, spec.chooserTitle, sender)
        } else {
            Intent.createChooser(send, spec.chooserTitle)
        }
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
     * 建「用户选了谁」的回执 sender：系统把 `EXTRA_CHOSEN_COMPONENT` 投给
     * [IcsShareResultReceiver]。
     *
     * `FLAG_MUTABLE` 是必须的（API 31+ 不允许对要被框架填充的 PendingIntent 用 immutable）。
     * 回执接收器必须在 manifest 里声明，否则投递无处落地；[prepareShare] 会先把上一个回执
     * 清掉并在 [IcsSharePreparation.Ready.resultRelayAvailable] 里说明通道通不通。
     */
    fun createResultSender(): IntentSender = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, IcsShareResultReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
    ).intentSender

    /**
     * 分享面板关掉之后 → [IcsShareOutcome]。
     *
     * 判据在纯 Kotlin 的 [IcsShareLogic.closeOutcome]（JVM 单测覆盖），本函数只做一次
     * 枚举→outcome 的搬运：**`CANCELLED` 一律归 [IcsShareOutcome.Cancelled]，绝不并进 `Failed`**；
     * `INDETERMINATE`（回执通道不可用）归 [IcsShareOutcome.Unconfirmed]，宿主对它保持沉默。
     */
    fun outcomeForClose(chosenComponent: String?, relayAvailable: Boolean): IcsShareOutcome =
        when (IcsShareLogic.closeOutcome(chosenComponent, relayAvailable)) {
            IcsShareLaunchSignal.CONFIRMED -> IcsShareOutcome.Shared
            IcsShareLaunchSignal.CANCELLED -> IcsShareOutcome.Cancelled
            IcsShareLaunchSignal.INDETERMINATE -> IcsShareOutcome.Unconfirmed
        }

    /**
     * 分享的前半段：写文件 → content Uri → 形状核对 → 带回执 sender 的选择器。
     *
     * 后半段（真正 `launch`）在宿主那边，因为结果只能由它自己的 Activity launcher 接。
     * 全程不抛异常：任何失败都折算成 [IcsSharePreparation.Failed]。
     */
    fun prepareShare(
        content: String,
        profileName: String,
        from: LocalDate,
        to: LocalDate,
    ): IcsSharePreparation {
        val spec = specFor(profileName, from, to)
        val file = writeIcs(spec, content)
            ?: return IcsSharePreparation.Failed(IcsShareFailure.WRITE_FAILED)

        val contentUri = try {
            FileProvider.getUriForFile(context, spec.providerAuthority, file)
        } catch (e: IllegalArgumentException) {
            // provider 未注册 / 路径未声明：都是「声明侧还没补」，不 crash。
            return IcsSharePreparation.Failed(IcsShareFailure.PROVIDER_UNAVAILABLE)
        }

        val matches = IcsShareLogic.contentUriMatches(
            expectedAuthority = spec.providerAuthority,
            uriAuthority = contentUri.authority,
            firstPathSegment = contentUri.pathSegments.firstOrNull(),
        )
        if (!matches) {
            return IcsSharePreparation.Failed(IcsShareFailure.PROVIDER_MISMATCH)
        }

        // 清掉上一次的回执，再把这次的 sender 交给选择器。
        IcsShareResultReceiver.begin()
        val sender = try {
            createResultSender()
        } catch (e: Exception) {
            return IcsSharePreparation.Failed(IcsShareFailure.LAUNCH_FAILED)
        }
        return IcsSharePreparation.Ready(
            spec = spec,
            chooser = createChooser(spec, contentUri, sender),
            // 通道通不通由 manifest 决定；不通时宿主对「没回执」保持沉默，不谎报取消。
            resultRelayAvailable = IcsShareResultReceiver.isDeclared(context),
        )
    }
}
