package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.app.AppLocaleRuntime

import com.mutx163.qingyu.infra.AppUpdateDownloadChannel

/**
 * 「版本更新页 / 高级选项页」的屏上文案 —— **逐字镜像 `lib/l10n/app_zh.arb`**，
 * 键名写在每行注释里。渲染层不许再出现中文字面量（`CjkLiteralGateTest` 管着），
 * 所有字都从这里取；[AboutUpdatePageStringsArbTest] 直读 ARB 对拍，防「看着对其实不一样」。
 *
 * 复用既有 `about*` 键（不新增 ARB 键），因此不触碰 copy-style 基线。
 */
object AboutUpdatePageStrings {

    // ---------- 主页面 ----------

    /** aboutUpdateScreenTitle */
    val screenTitle: String get() = AppLocaleRuntime.text("aboutUpdateScreenTitle", "版本更新")

    /** aboutCheckingForUpdate */
    val checkingForUpdate: String get() = AppLocaleRuntime.text("aboutCheckingForUpdate", "正在检查更新……")

    /** aboutUnreleasedLabel */
    val unreleasedLabel: String get() = AppLocaleRuntime.text("aboutUnreleasedLabel", "未发布")

    /** aboutReleaseNotesTitle */
    val releaseNotesTitle: String get() = AppLocaleRuntime.text("aboutReleaseNotesTitle", "更新说明")

    /** aboutAdvancedOptionsTitle */
    val advancedOptionsTitle: String get() = AppLocaleRuntime.text("aboutAdvancedOptionsTitle", "高级选项")

    /** aboutUpdateNoUpdateHint */
    val noUpdateHint: String get() = AppLocaleRuntime.text("aboutUpdateNoUpdateHint", "当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测")

    /** aboutUpdatedAt = `更新于 {time}` */
    val updatedAtTemplate: String get() = AppLocaleRuntime.text("aboutUpdatedAt", "更新于 {time}")
    fun updatedAt(time: String): String = updatedAtTemplate.replace("{time}", time)

    // ---------- 高级选项 ----------

    /** aboutUpdatePromptTitle */
    val updatePromptTitle: String get() = AppLocaleRuntime.text("aboutUpdatePromptTitle", "弹窗提醒")

    /** aboutUpdatePromptSubtitle */
    val updatePromptSubtitle: String get() = AppLocaleRuntime.text("aboutUpdatePromptSubtitle", "关闭后只在更多按钮留红点")

    /** aboutDownloadChannelSectionTitle */
    val downloadChannelSectionTitle: String get() = AppLocaleRuntime.text("aboutDownloadChannelSectionTitle", "下载渠道")

    /** aboutDownloadPackageMethodTitle */
    val downloadPackageMethodTitle: String get() = AppLocaleRuntime.text("aboutDownloadPackageMethodTitle", "下载安装包方式")

    /** aboutInAppDownloadTitle */
    val inAppDownloadTitle: String get() = AppLocaleRuntime.text("aboutInAppDownloadTitle", "应用内下载")

    /** aboutInAppDownloadSubtitle */
    val inAppDownloadSubtitle: String get() = AppLocaleRuntime.text("aboutInAppDownloadSubtitle", "下载完成后直接在应用内安装")

    /** aboutSystemDownloaderTitle */
    val systemDownloaderTitle: String get() = AppLocaleRuntime.text("aboutSystemDownloaderTitle", "系统下载管理器")

    /** aboutSystemDownloaderChoiceSubtitle */
    val systemDownloaderChoiceSubtitle: String get() = AppLocaleRuntime.text("aboutSystemDownloaderChoiceSubtitle", "交给系统下载管理器处理")

    /** aboutCheckPrereleaseTitle */
    val checkPrereleaseTitle: String get() = AppLocaleRuntime.text("aboutCheckPrereleaseTitle", "检测测试版本")

    /** aboutCheckPrereleaseSubtitle */
    val checkPrereleaseSubtitle: String get() = AppLocaleRuntime.text("aboutCheckPrereleaseSubtitle", "会收到可能不稳定的测试版")

    /** aboutMirrorSectionTitle */
    val mirrorSectionTitle: String get() = AppLocaleRuntime.text("aboutMirrorSectionTitle", "下载线路与镜像")

    /** aboutRecommended */
    val recommended: String get() = AppLocaleRuntime.text("aboutRecommended", "推荐")

    /** aboutProbingMirrors */
    val probingMirrors: String get() = AppLocaleRuntime.text("aboutProbingMirrors", "测速中……")

    /** aboutProbeMirrorsAction */
    val probeMirrorsAction: String get() = AppLocaleRuntime.text("aboutProbeMirrorsAction", "测速并推荐")

    /** aboutEditCustomMirrorAction */
    val editCustomMirrorAction: String get() = AppLocaleRuntime.text("aboutEditCustomMirrorAction", "修改自定义地址")

    /** aboutSetCustomMirrorAction */
    val setCustomMirrorAction: String get() = AppLocaleRuntime.text("aboutSetCustomMirrorAction", "填写自定义地址")

    /** aboutFillCustomMirrorFirst */
    val fillCustomMirrorFirst: String get() = AppLocaleRuntime.text("aboutFillCustomMirrorFirst", "先填写自定义下载地址")

    /** aboutMirrorProbeFailedLabel */
    val mirrorProbeFailedLabel: String get() = AppLocaleRuntime.text("aboutMirrorProbeFailedLabel", "失败")

    /** aboutDiagnosticsTitle */
    val diagnosticsTitle: String get() = AppLocaleRuntime.text("aboutDiagnosticsTitle", "测试与诊断")

    /** aboutViewPhoneLogsAction */
    val viewPhoneLogsAction: String get() = AppLocaleRuntime.text("aboutViewPhoneLogsAction", "打开日志页")

    /** aboutSetMirrorSourceTitle */
    val setMirrorSourceTitle: String get() = AppLocaleRuntime.text("aboutSetMirrorSourceTitle", "设置镜像源")

    /** aboutMirrorPrefixLabel */
    val mirrorPrefixLabel: String get() = AppLocaleRuntime.text("aboutMirrorPrefixLabel", "镜像前缀")

    /** appUpdateMirrorPresetCustomDescription */
    val mirrorPresetCustomDescription: String get() = AppLocaleRuntime.text("appUpdateMirrorPresetCustomDescription", "填写自定义镜像地址前缀")

    // ---------- 下载渠道 label / description（enum_localizations.dart:246-266） ----------

    /** appUpdateDownloadChannelPgyer */
    val channelPgyer: String get() = AppLocaleRuntime.text("appUpdateDownloadChannelPgyer", "蒲公英下载")

    /** appUpdateDownloadChannelGithub */
    val channelGithub: String get() = AppLocaleRuntime.text("appUpdateDownloadChannelGithub", "GitHub 下载")

    /** appUpdateDownloadChannelGitcode */
    val channelGitcode: String get() = AppLocaleRuntime.text("appUpdateDownloadChannelGitcode", "GitCode 直连")

    /** appUpdateDownloadChannelPgyerDescription */
    val channelPgyerDescription: String get() = AppLocaleRuntime.text("appUpdateDownloadChannelPgyerDescription", "国内高速下载，推荐使用")

    /** appUpdateDownloadChannelGithubDescription */
    val channelGithubDescription: String get() = AppLocaleRuntime.text("appUpdateDownloadChannelGithubDescription", "GitHub 原生 + 国内镜像")

    /** appUpdateDownloadChannelGitcodeDescription */
    val channelGitcodeDescription: String get() = AppLocaleRuntime.text("appUpdateDownloadChannelGitcodeDescription", "GitCode 发行版直连下载，国内速度快")

    fun channelLabel(channel: AppUpdateDownloadChannel): String = when (channel) {
        AppUpdateDownloadChannel.PGYER -> channelPgyer
        AppUpdateDownloadChannel.GITHUB -> channelGithub
        AppUpdateDownloadChannel.GITCODE -> channelGitcode
    }

    fun channelDescription(channel: AppUpdateDownloadChannel): String = when (channel) {
        AppUpdateDownloadChannel.PGYER -> channelPgyerDescription
        AppUpdateDownloadChannel.GITHUB -> channelGithubDescription
        AppUpdateDownloadChannel.GITCODE -> channelGitcodeDescription
    }

    // ---------- 镜像预设 label（enum_localizations.dart:267-289） ----------

    /** appUpdateMirrorPresetGhfast */
    val presetGhfast: String get() = AppLocaleRuntime.text("appUpdateMirrorPresetGhfast", "默认镜像")

    /** appUpdateMirrorPresetGhLlkk */
    val presetGhLlkk: String get() = AppLocaleRuntime.text("appUpdateMirrorPresetGhLlkk", "备用镜像 2")

    /** appUpdateMirrorPresetGhProxyCom */
    val presetGhProxyCom: String get() = AppLocaleRuntime.text("appUpdateMirrorPresetGhProxyCom", "备用镜像 3")

    /** appUpdateMirrorPresetGhproxyNet */
    val presetGhproxyNet: String get() = AppLocaleRuntime.text("appUpdateMirrorPresetGhproxyNet", "备用镜像 4")

    /** appUpdateMirrorPresetCustom */
    val presetCustom: String get() = AppLocaleRuntime.text("appUpdateMirrorPresetCustom", "自定义")

    fun presetLabel(preset: MirrorPreset): String = when (preset) {
        MirrorPreset.GHFAST -> presetGhfast
        MirrorPreset.GH_LLKK -> presetGhLlkk
        MirrorPreset.GH_PROXY_COM -> presetGhProxyCom
        MirrorPreset.GH_PROXY_NET -> presetGhproxyNet
        MirrorPreset.CUSTOM -> presetCustom
    }

    // ---------- 下载进度 / 提示 ----------

    /** aboutDownloadCancelling */
    val downloadCancelling: String get() = AppLocaleRuntime.text("aboutDownloadCancelling", "正在取消下载……")

    /** aboutDownloadingBytes = `正在下载更新 {value}` */
    val downloadingBytesTemplate: String get() = AppLocaleRuntime.text("aboutDownloadingBytes", "正在下载更新 {value}")
    fun downloadingBytes(value: String): String = downloadingBytesTemplate.replace("{value}", value)

    /** aboutDownloadingPercent = `正在下载更新 {value}%` */
    val downloadingPercentTemplate: String get() = AppLocaleRuntime.text("aboutDownloadingPercent", "正在下载更新 {value}%")
    fun downloadingPercent(value: String): String = downloadingPercentTemplate.replace("{value}", value)

    /** aboutMirrorUnknownSizeHint */
    val mirrorUnknownSizeHint: String get() = AppLocaleRuntime.text("aboutMirrorUnknownSizeHint", "镜像源未返回文件总大小，先显示已下载体积")

    /** aboutCancelDownloadAction */
    val cancelDownloadAction: String get() = AppLocaleRuntime.text("aboutCancelDownloadAction", "取消下载")

    /** aboutInstallReady */
    val installReady: String get() = AppLocaleRuntime.text("aboutInstallReady", "安装包已准备好，已尝试打开安装界面；如果系统没有弹出，请稍后从通知或文件管理器手动安装")

    /** aboutSystemDownloaderQueued */
    val systemDownloaderQueued: String get() = AppLocaleRuntime.text("aboutSystemDownloaderQueued", "已交给系统下载管理器，请在系统通知或下载列表里查看进度")

    /** aboutSystemDownloaderFailed */
    val systemDownloaderFailed: String get() = AppLocaleRuntime.text("aboutSystemDownloaderFailed", "调用系统下载管理器失败")

    /** aboutMirrorSaved */
    val mirrorSaved: String get() = AppLocaleRuntime.text("aboutMirrorSaved", "镜像源已保存")

    /** aboutMirrorPrefixInvalid */
    val mirrorPrefixInvalid: String get() = AppLocaleRuntime.text("aboutMirrorPrefixInvalid", "镜像源格式不正确，请输入完整的 http 或 https 地址")

    /**
     * `cancelAction`（`app_zh.arb:492`）：镜像地址编辑弹窗的「取消」。
     * 与全站同一个键，不新造文案。
     */
    val cancelAction: String get() = AppLocaleRuntime.text("cancelAction", "取消")

    /** `confirmAction`（`app_zh.arb:493`）：镜像地址编辑弹窗的「确认」。 */
    val confirmAction: String get() = AppLocaleRuntime.text("confirmAction", "确认")

    /**
     * `serviceMsgUpdateDownloadHashMismatch`（`app_zh.arb:4920`）。
     *
     * 摘要不一致时**拒绝安装**的提示（Dart 错误码 `update_download_hash_mismatch`）。
     * 这条属于 Dart 的 service message 表，Kotlin 侧还没有那张表，所以先按原键名
     * 抄进本族 strings；等 `ServiceMessageStrings` 移植过来后改成查表。
     */
    val hashMismatch: String get() = AppLocaleRuntime.text("serviceMsgUpdateDownloadHashMismatch", "安装包校验失败，为防止安装被篡改的文件已取消本次更新")

    /**
     * `serviceMsgUpdateSha256UnverifiedRefused`（`app_zh.arb:4921`）。
     *
     * 元数据声明了摘要、本地却算不出来（读不到文件）时的提示：同样拒绝安装，
     * **不**降级成「没摘要就当没要求」。
     */
    val sha256Unverified: String get() = AppLocaleRuntime.text("serviceMsgUpdateSha256UnverifiedRefused", "安装包完整性校验失败，已取消更新，请前往发布页下载")

    /**
     * `serviceMsgUpdateOpenInstallerFailed`（`app_zh.arb:4931`），占位符 `{detail}`。
     *
     * 安装器拉不起来时告诉用户为什么（Dart 错误码 `update_open_installer_failed`）。
     */
    val openInstallerFailedTemplate: String get() = AppLocaleRuntime.text("serviceMsgUpdateOpenInstallerFailed", "打开安装包失败：{detail}")

    /** 填充 [openInstallerFailedTemplate] 的 `{detail}`。 */
    fun openInstallerFailed(detail: String): String =
        openInstallerFailedTemplate.replace("{detail}", detail)
}
