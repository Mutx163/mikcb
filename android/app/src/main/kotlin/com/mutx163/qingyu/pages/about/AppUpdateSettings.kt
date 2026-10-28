package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.LenientJson
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.AppUpdateDownloadSource
import com.mutx163.qingyu.infra.defaultMirrorUrlPrefix

/**
 * 更新相关设置的**纯快照**（7 个键），对齐 Dart `TimetableSettings` 的 `appUpdate*` 字段
 * （`lib/models/timetable_settings.dart:598-606`，读侧 `:1730-1744`）。
 *
 * ## 为什么不并进 core.TimetableSettings
 *
 * `core/TimetableSettings.kt` 只搬了时间/周次 4 键，且明确写着「Compose 侧不得用它整体覆盖
 * 设置存档」。本类是**只读快照 + 合并补丁**：读走 `fromJson(loadSettingsJson())`，
 * 写走 `toPatch()` 交给 `TimetableStore.saveSettingsPatch`（读-合并-写，不碰别的键）。
 *
 * ## 默认值（Dart 构造默认 `:903-909` 与读侧回落 `:1730-1744` 一致）
 *
 * - 下载来源 `mirror`、下载渠道 `gitcode`、镜像预设 `ghfast`、镜像前缀 `https://ghfast.top/`；
 * - 用系统下载器 `false`、检测测试版 `false`、更新弹窗提示 `true`。
 */
data class AppUpdateSettings(
    val downloadSource: AppUpdateDownloadSource = AppUpdateDownloadSource.MIRROR,
    val downloadChannel: AppUpdateDownloadChannel = AppUpdateDownloadChannel.GITCODE,
    val useSystemDownloader: Boolean = false,
    val mirrorPreset: MirrorPreset = MirrorPreset.GHFAST,
    val includePrerelease: Boolean = false,
    val mirrorUrlPrefix: String = defaultMirrorUrlPrefix,
    val promptEnabled: Boolean = true,
) {

    /** 合并补丁（键名与 Dart `toJson` 逐字一致，`:1236-1242`）。 */
    fun toPatch(): Map<String, Any?> = linkedMapOf(
        "appUpdateDownloadSource" to downloadSourceValue(downloadSource),
        "appUpdateDownloadChannel" to downloadChannelValue(downloadChannel),
        "appUpdateUseSystemDownloader" to useSystemDownloader,
        "appUpdateMirrorPreset" to mirrorPresetValue(mirrorPreset),
        "appUpdateIncludePrerelease" to includePrerelease,
        "appUpdateMirrorUrlPrefix" to mirrorUrlPrefix,
        "appUpdatePromptEnabled" to promptEnabled,
    )

    companion object {
        /** 读侧口径逐键抄 Dart `fromJson`（`:1730-1744`），缺键/非法值按默认回落。 */
        fun fromJson(json: Map<String, Any?>): AppUpdateSettings = AppUpdateSettings(
            downloadSource = downloadSourceFromValue(LenientJson.string(json["appUpdateDownloadSource"])),
            downloadChannel = downloadChannelFromValue(LenientJson.string(json["appUpdateDownloadChannel"])),
            useSystemDownloader = LenientJson.bool(json["appUpdateUseSystemDownloader"]) ?: false,
            mirrorPreset = mirrorPresetFromValue(LenientJson.string(json["appUpdateMirrorPreset"])),
            includePrerelease = LenientJson.bool(json["appUpdateIncludePrerelease"]) ?: false,
            mirrorUrlPrefix = LenientJson.string(json["appUpdateMirrorUrlPrefix"]) ?: defaultMirrorUrlPrefix,
            promptEnabled = LenientJson.bool(json["appUpdatePromptEnabled"]) ?: true,
        )
    }
}

// ---------- 枚举 ↔ 存档字符串（Dart `timetable_settings_extensions.dart:419-509`） ----------

/** `AppUpdateDownloadSource.value`（`:419-431`）。 */
fun downloadSourceValue(source: AppUpdateDownloadSource): String = when (source) {
    AppUpdateDownloadSource.ORIGINAL -> "original"
    AppUpdateDownloadSource.MIRROR -> "mirror"
}

/** `AppUpdateDownloadSourceX.fromValue`：未知值回落 `mirror`（Dart 同口径）。 */
fun downloadSourceFromValue(value: String?): AppUpdateDownloadSource = when (value) {
    "original" -> AppUpdateDownloadSource.ORIGINAL
    else -> AppUpdateDownloadSource.MIRROR
}

/** `AppUpdateDownloadChannel.value`（`:433-441`）。 */
fun downloadChannelValue(channel: AppUpdateDownloadChannel): String = when (channel) {
    AppUpdateDownloadChannel.PGYER -> "pgyer"
    AppUpdateDownloadChannel.GITHUB -> "github"
    AppUpdateDownloadChannel.GITCODE -> "gitcode"
}

/** `AppUpdateDownloadChannelX.fromValue`：未知值回落 `gitcode`（Dart 同口径）。 */
fun downloadChannelFromValue(value: String?): AppUpdateDownloadChannel = when (value) {
    "pgyer" -> AppUpdateDownloadChannel.PGYER
    "github" -> AppUpdateDownloadChannel.GITHUB
    else -> AppUpdateDownloadChannel.GITCODE
}

/** `AppUpdateMirrorPreset.value`（`:455-463`）。注意 `gh_llkk` 等不是驼峰名。 */
fun mirrorPresetValue(preset: MirrorPreset): String = when (preset) {
    MirrorPreset.GHFAST -> "ghfast"
    MirrorPreset.GH_LLKK -> "gh_llkk"
    MirrorPreset.GH_PROXY_COM -> "gh_proxy_com"
    MirrorPreset.GH_PROXY_NET -> "ghproxy_net"
    MirrorPreset.CUSTOM -> "custom"
}

/** `AppUpdateMirrorPresetX.fromValue`：未知值回落 `ghfast`（Dart 同口径）。 */
fun mirrorPresetFromValue(value: String?): MirrorPreset = when (value) {
    "gh_llkk" -> MirrorPreset.GH_LLKK
    "gh_proxy_com" -> MirrorPreset.GH_PROXY_COM
    "ghproxy_net" -> MirrorPreset.GH_PROXY_NET
    "custom" -> MirrorPreset.CUSTOM
    else -> MirrorPreset.GHFAST
}

/** Dart `ghLlkkMirrorUrlPrefix` / `ghProxyCom...` / `ghproxyNet...`（`enums.dart:283-285`）。 */
const val ghLlkkMirrorUrlPrefix = "https://gh.llkk.cc/"
const val ghProxyComMirrorUrlPrefix = "https://gh-proxy.com/"
const val ghproxyNetMirrorUrlPrefix = "https://ghproxy.net/"

/**
 * Dart `resolveAppUpdateMirrorUrlPrefix`（`timetable_settings_extensions.dart:495-509`）：
 * 内置预设返回内置前缀；`custom` 用去空白后的自定义前缀，空则回落内置默认。
 */
fun resolveMirrorUrlPrefix(preset: MirrorPreset, customUrlPrefix: String): String {
    val normalizedCustom = customUrlPrefix.trim()
    return when (preset) {
        MirrorPreset.GHFAST -> defaultMirrorUrlPrefix
        MirrorPreset.GH_LLKK -> ghLlkkMirrorUrlPrefix
        MirrorPreset.GH_PROXY_COM -> ghProxyComMirrorUrlPrefix
        MirrorPreset.GH_PROXY_NET -> ghproxyNetMirrorUrlPrefix
        MirrorPreset.CUSTOM -> if (normalizedCustom.isEmpty()) defaultMirrorUrlPrefix else normalizedCustom
    }
}
