package com.mutx163.qingyu.pages.about

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
    const val screenTitle = "版本更新"

    /** aboutCheckingForUpdate */
    const val checkingForUpdate = "正在检查更新……"

    /** aboutUnreleasedLabel */
    const val unreleasedLabel = "未发布"

    /** aboutReleaseNotesTitle */
    const val releaseNotesTitle = "更新说明"

    /** aboutAdvancedOptionsTitle */
    const val advancedOptionsTitle = "高级选项"

    /** aboutUpdateNoUpdateHint */
    const val noUpdateHint = "当前版本已经可正常使用；如果你要体验测试版，可以在后面的高级选项里打开测试版检测"

    /** aboutUpdatedAt = `更新于 {time}` */
    const val updatedAtTemplate = "更新于 {time}"
    fun updatedAt(time: String): String = updatedAtTemplate.replace("{time}", time)

    // ---------- 高级选项 ----------

    /** aboutUpdatePromptTitle */
    const val updatePromptTitle = "弹窗提醒"

    /** aboutUpdatePromptSubtitle */
    const val updatePromptSubtitle = "关闭后只在更多按钮留红点"

    /** aboutDownloadChannelSectionTitle */
    const val downloadChannelSectionTitle = "下载渠道"

    /** aboutDownloadPackageMethodTitle */
    const val downloadPackageMethodTitle = "下载安装包方式"

    /** aboutInAppDownloadTitle */
    const val inAppDownloadTitle = "应用内下载"

    /** aboutInAppDownloadSubtitle */
    const val inAppDownloadSubtitle = "下载完成后直接在应用内安装"

    /** aboutSystemDownloaderTitle */
    const val systemDownloaderTitle = "系统下载管理器"

    /** aboutSystemDownloaderChoiceSubtitle */
    const val systemDownloaderChoiceSubtitle = "交给系统下载管理器处理"

    /** aboutCheckPrereleaseTitle */
    const val checkPrereleaseTitle = "检测测试版本"

    /** aboutCheckPrereleaseSubtitle */
    const val checkPrereleaseSubtitle = "会收到可能不稳定的测试版"

    /** aboutMirrorSectionTitle */
    const val mirrorSectionTitle = "下载线路与镜像"

    /** aboutRecommended */
    const val recommended = "推荐"

    /** aboutProbingMirrors */
    const val probingMirrors = "测速中……"

    /** aboutProbeMirrorsAction */
    const val probeMirrorsAction = "测速并推荐"

    /** aboutEditCustomMirrorAction */
    const val editCustomMirrorAction = "修改自定义地址"

    /** aboutSetCustomMirrorAction */
    const val setCustomMirrorAction = "填写自定义地址"

    /** aboutFillCustomMirrorFirst */
    const val fillCustomMirrorFirst = "先填写自定义下载地址"

    /** aboutMirrorProbeFailedLabel */
    const val mirrorProbeFailedLabel = "失败"

    /** aboutDiagnosticsTitle */
    const val diagnosticsTitle = "测试与诊断"

    /** aboutViewPhoneLogsAction */
    const val viewPhoneLogsAction = "打开日志页"

    /** aboutSetMirrorSourceTitle */
    const val setMirrorSourceTitle = "设置镜像源"

    /** aboutMirrorPrefixLabel */
    const val mirrorPrefixLabel = "镜像前缀"

    /** appUpdateMirrorPresetCustomDescription */
    const val mirrorPresetCustomDescription = "填写自定义镜像地址前缀"

    // ---------- 下载渠道 label / description（enum_localizations.dart:246-266） ----------

    /** appUpdateDownloadChannelPgyer */
    const val channelPgyer = "蒲公英下载"

    /** appUpdateDownloadChannelGithub */
    const val channelGithub = "GitHub 下载"

    /** appUpdateDownloadChannelGitcode */
    const val channelGitcode = "GitCode 直连"

    /** appUpdateDownloadChannelPgyerDescription */
    const val channelPgyerDescription = "国内高速下载，推荐使用"

    /** appUpdateDownloadChannelGithubDescription */
    const val channelGithubDescription = "GitHub 原生 + 国内镜像"

    /** appUpdateDownloadChannelGitcodeDescription */
    const val channelGitcodeDescription = "GitCode 发行版直连下载，国内速度快"

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
    const val presetGhfast = "默认镜像"

    /** appUpdateMirrorPresetGhLlkk */
    const val presetGhLlkk = "备用镜像 2"

    /** appUpdateMirrorPresetGhProxyCom */
    const val presetGhProxyCom = "备用镜像 3"

    /** appUpdateMirrorPresetGhproxyNet */
    const val presetGhproxyNet = "备用镜像 4"

    /** appUpdateMirrorPresetCustom */
    const val presetCustom = "自定义"

    fun presetLabel(preset: MirrorPreset): String = when (preset) {
        MirrorPreset.GHFAST -> presetGhfast
        MirrorPreset.GH_LLKK -> presetGhLlkk
        MirrorPreset.GH_PROXY_COM -> presetGhProxyCom
        MirrorPreset.GH_PROXY_NET -> presetGhproxyNet
        MirrorPreset.CUSTOM -> presetCustom
    }

    // ---------- 下载进度 / 提示 ----------

    /** aboutDownloadCancelling */
    const val downloadCancelling = "正在取消下载……"

    /** aboutDownloadingBytes = `正在下载更新 {value}` */
    const val downloadingBytesTemplate = "正在下载更新 {value}"
    fun downloadingBytes(value: String): String = downloadingBytesTemplate.replace("{value}", value)

    /** aboutDownloadingPercent = `正在下载更新 {value}%` */
    const val downloadingPercentTemplate = "正在下载更新 {value}%"
    fun downloadingPercent(value: String): String = downloadingPercentTemplate.replace("{value}", value)

    /** aboutMirrorUnknownSizeHint */
    const val mirrorUnknownSizeHint = "镜像源未返回文件总大小，先显示已下载体积"

    /** aboutCancelDownloadAction */
    const val cancelDownloadAction = "取消下载"

    /** aboutInstallReady */
    const val installReady = "安装包已准备好，已尝试打开安装界面；如果系统没有弹出，请稍后从通知或文件管理器手动安装"

    /** aboutSystemDownloaderQueued */
    const val systemDownloaderQueued = "已交给系统下载管理器，请在系统通知或下载列表里查看进度"

    /** aboutSystemDownloaderFailed */
    const val systemDownloaderFailed = "调用系统下载管理器失败"

    /** aboutMirrorSaved */
    const val mirrorSaved = "镜像源已保存"

    /** aboutMirrorPrefixInvalid */
    const val mirrorPrefixInvalid = "镜像源格式不正确，请输入完整的 http 或 https 地址"
}
