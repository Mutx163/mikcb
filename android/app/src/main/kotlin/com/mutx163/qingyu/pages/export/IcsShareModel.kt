package com.mutx163.qingyu.pages.export

import java.time.LocalDate

/**
 * ICS 导出结果的**分享意图契约**（I3A，纯 Kotlin，无 Android 依赖，可 JVM 测）。
 *
 * **为什么需要这一层**：Dart 侧走 `share_plus` 的 `XFile.fromData(...)`，文件名与 MIME 直接交给插件；
 * Android 原生侧没有 `share_plus`，必须自己 `FileProvider.getUriForFile` + `Intent.createChooser`。
 * 一旦把 authority、目录、MIME、extras 这些字符串散落在 `platform/` 的适配器里，就没有任何
 * JVM 测试能钉住它们（`platform/` 引 `android.*`，进不了单测 classpath）。所以判据全放这里，
 * 适配器 `platform/AndroidShareAdapter.kt` 只照单执行，**不自己拍字符串**。
 *
 * 对应 Dart 源：`lib/screens/ics_export_screen.dart` 的 `_shareResult`（ShareParams：一个
 * `text/calendar` 文件 + `text` + `subject`），文件名规则见 `IcsExportLogic.buildFileName`。
 */
data class IcsShareSpec(
    /** 落地文件名（含 `.ics`），同时作为分享出去的显示名。 */
    val fileName: String,
    /** 相对 `context.cacheDir` 的路径，形如 `ics-export/xxx.ics`（适配器 `File(cacheDir, it)`）。 */
    val localRelativePath: String,
    /** `Intent.setType` 的值。 */
    val mimeType: String,
    /** `Intent` action。 */
    val action: String,
    /** `EXTRA_STREAM` 的键（Mac 平台无；Android 上是 `android.intent.extra.STREAM`）。 */
    val extraStreamKey: String,
    /** `EXTRA_TEXT` 的键。 */
    val extraTextKey: String,
    /** `EXTRA_SUBJECT` 的键。 */
    val extraSubjectKey: String,
    /** 分享附言（ARB `icsExportShareText`）。 */
    val text: String,
    /** 分享主题（ARB `icsExportShareSubject`）。 */
    val subject: String,
    /**
     * 选择器标题。**为 null**：Dart `share_plus` 不传标题，本批也不新造文案
     * （界面可见文字要走 ARB，属 Lead 补文案的范围）。
     */
    val chooserTitle: String?,
    /** 是否要 `FLAG_GRANT_READ_URI_PERMISSION`（content Uri 必须授读，否则目标应用打不开）。 */
    val grantReadPermission: Boolean,
    /** `ClipData` 的标签（部分接收方只读 ClipData，标签用文件名，不额外造文案）。 */
    val clipDataLabel: String,
    /** FileProvider 的 authority。 */
    val providerAuthority: String,
)

/**
 * 系统分享面板关闭时的**三种结局**。
 *
 * 为什么判据在纯 Kotlin 这一层：适配器引 `android.*` 进不了 JVM 单测，而「用户划掉面板 ≠
 * 分享成功、也 ≠ 拉起失败」必须被测试钉住（Dart 在取消时弹「已取消分享日历」，
 * 不弹「导出失败」）。
 *
 * **怎么得知「选了谁」**：照 `share_plus` 的做法（发布版就用它，见
 * `share_plus-12.0.2/android/.../Share.kt` + `ShareSuccessManager.kt`）——给
 * `Intent.createChooser(intent, title, sender)` 传一个广播 `PendingIntent` 的 sender，
 * 系统在**用户真的选定目标时**把 `EXTRA_CHOSEN_COMPONENT` 投进那个广播。
 * 它**不看** activity result 的 `resultCode`/`data`：`ShareSuccessManager.onActivityResult`
 * 的注释就是 "Called regardless of success or dismissal"。所以「面板关了但没有回执」
 * 才是取消——单看 resultCode 会把成功也判成取消（Android 选择器普遍恒回 `RESULT_CANCELED`）。
 */
enum class IcsShareLaunchSignal {
    /** 收到了回执：用户在面板里选定了某个目标应用。 */
    CONFIRMED,

    /** 面板关了、回执通道是通的，但没有任何目标被选中 ⇒ 用户划掉了。**不是失败**。 */
    CANCELLED,

    /**
     * 面板关了，但**拿不到可信信号**（回执通道没接上 / 回执可疑）。
     *
     * 这时既不报成功也不报取消：宁可不说话，也不能在用户真分享成功之后跟他说「你取消了」。
     */
    INDETERMINATE,
}

/**
 * 分享意图的纯逻辑判据来源。**适配器只读这里，不另立一套字符串。**
 *
 * 常量与 Android 框架/`androidx.core` 的契约一一对应，改一个就必须同步改：
 * - [PROVIDER_AUTHORITY_SUFFIX] ↔ `AndroidManifest.xml` 里 `<provider android:authorities="${applicationId}.fileprovider">`
 * - [PROVIDER_ROOT_ELEMENT] / [PROVIDER_PATH_NAME] / [providerCachePath] ↔ `res/xml/file_paths.xml` 里
 *   `<cache-path name="ics_export" path="ics-export/"/>`
 * - [SHARE_DIR_NAME] 是我们真正写文件的目录，必须被上面那条 `path` 覆盖
 * - [ACTION_SEND] / [EXTRA_STREAM] / [EXTRA_TEXT] / [EXTRA_SUBJECT] ↔ `android.content.Intent` 常量
 */
object IcsShareLogic {

    /** `android.content.Intent.ACTION_SEND`。 */
    const val ACTION_SEND: String = "android.intent.action.SEND"

    /** `android.content.Intent.EXTRA_STREAM`。 */
    const val EXTRA_STREAM: String = "android.intent.extra.STREAM"

    /** `android.content.Intent.EXTRA_TEXT`。 */
    const val EXTRA_TEXT: String = "android.intent.extra.TEXT"

    /** `android.content.Intent.EXTRA_SUBJECT`。 */
    const val EXTRA_SUBJECT: String = "android.intent.extra.SUBJECT"

    /** `.ics` 的标准 MIME（RFC 5545；`MimeTypeMap` 与 `file_picker` 也映射到它）。 */
    const val MIME_TYPE_CALENDAR: String = "text/calendar"

    /** authority 后缀；与 manifest 的 `${applicationId}.fileprovider` 同一口径。 */
    const val PROVIDER_AUTHORITY_SUFFIX: String = ".fileprovider"

    /** `<paths>` 里包的根元素：我们写的是内部缓存目录。 */
    const val PROVIDER_ROOT_ELEMENT: String = "cache-path"

    /** `<cache-path name="…">` 的 name（决定 content Uri 的第一段路径）。 */
    const val PROVIDER_PATH_NAME: String = "ics_export"

    /** 写文件的子目录名（相对 `cacheDir`）。 */
    const val SHARE_DIR_NAME: String = "ics-export"

    /**
     * FileProvider authority = `<applicationId>.fileprovider`。
     *
     * 用 applicationId 而不是包名常量：本仓各变体带后缀（`.debug` / `.profile` / `.itest` / `.ui`，
     * 见 `android/app/build.gradle` 的 `applicationIdSuffix`），manifest 的 `${applicationId}`
     * 会跟着变，写死成 `com.mutx163.qingyu` 只有正式包能分享。
     *
     * 空 applicationId 直接拒绝：否则会静默生成 `.fileprovider` 这种永远匹配不上的 authority。
     */
    fun fileProviderAuthority(applicationId: String): String {
        val trimmed = applicationId.trim()
        require(trimmed.isNotEmpty()) {
            "applicationId 不能为空：FileProvider authority 由它派生"
        }
        return trimmed + PROVIDER_AUTHORITY_SUFFIX
    }

    /** `res/xml` 下路径声明 xml 里 `<cache-path path="…">` 应写的值（相对 `cacheDir`，带尾斜杠）。 */
    fun providerCachePath(): String = "$SHARE_DIR_NAME/"

    /** 文件相对 `cacheDir` 的路径（适配器 `File(context.cacheDir, 这个值)`）。 */
    fun shareRelativePath(fileName: String): String = "$SHARE_DIR_NAME/$fileName"

    /**
     * 由「课表名 + 导出区间」生成一份完整的分享契约。
     *
     * 文件名不在这里重算：唯一实现是 [IcsExportLogic.buildFileName]（Dart `buildFileName` 的移植），
     * 重复一份 sanitize 规则等于给同一件事造两个判据来源。
     */
    fun spec(
        applicationId: String,
        profileName: String,
        from: LocalDate,
        to: LocalDate,
    ): IcsShareSpec {
        val fileName = IcsExportLogic.buildFileName(profileName, from, to)
        return IcsShareSpec(
            fileName = fileName,
            localRelativePath = shareRelativePath(fileName),
            mimeType = MIME_TYPE_CALENDAR,
            action = ACTION_SEND,
            extraStreamKey = EXTRA_STREAM,
            extraTextKey = EXTRA_TEXT,
            extraSubjectKey = EXTRA_SUBJECT,
            text = ExportStrings.icsExportShareText.text,
            subject = ExportStrings.icsExportShareSubject.text,
            chooserTitle = null,
            grantReadPermission = true,
            clipDataLabel = fileName,
            providerAuthority = fileProviderAuthority(applicationId),
        )
    }

    /**
     * content Uri 形状判据（适配器拿 `FileProvider.getUriForFile` 的结果回对）：
     *
     * `androidx.core.content.FileProvider` 生成的是
     * `content://<authority>/<cache-path 的 name>/<相对路径>`，即
     * authority = `<applicationId>.fileprovider`，第一段路径 = [PROVIDER_PATH_NAME]。
     * 任一条不符说明 manifest 的 provider 声明与本批契约漂了，适配器选择明确失败而不是
     * 把一个来历不明的 Uri 交给目标应用。
     */
    fun contentUriMatches(
        expectedAuthority: String,
        uriAuthority: String?,
        firstPathSegment: String?,
    ): Boolean = uriAuthority == expectedAuthority && firstPathSegment == PROVIDER_PATH_NAME

    /**
     * 分享面板关闭后：`选了谁` + `回执通道通不通` → [IcsShareLaunchSignal]。
     *
     * 三条判据（顺序即优先级）：
     * 1. 收到了目标组件 ⇒ [IcsShareLaunchSignal.CONFIRMED]（有回执就是有回执，不管通道检查结果）；
     * 2. 没收到、且通道可用（`relayAvailable`）⇒ [IcsShareLaunchSignal.CANCELLED]（真取消）；
     * 3. 没收到、通道不可用 ⇒ [IcsShareLaunchSignal.INDETERMINATE]（**不许当取消**：
     *    分不清「用户划掉」和「回执没送到」，宁可不说）。
     *
     * @param chosenComponent 回执里的目标应用（`ComponentName.flattenToString()`）；null = 没回执
     * @param relayAvailable 回执通道是否可用（manifest 里声明了接收器）
     */
    fun closeOutcome(chosenComponent: String?, relayAvailable: Boolean): IcsShareLaunchSignal = when {
        !chosenComponent.isNullOrBlank() -> IcsShareLaunchSignal.CONFIRMED
        relayAvailable -> IcsShareLaunchSignal.CANCELLED
        else -> IcsShareLaunchSignal.INDETERMINATE
    }
}
