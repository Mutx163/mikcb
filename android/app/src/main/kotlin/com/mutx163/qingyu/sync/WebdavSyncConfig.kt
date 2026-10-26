package com.mutx163.qingyu.sync

/**
 * WebDAV 同步配置纯逻辑（源：lib/services/webdav_sync_config.dart）。
 *
 * 只含 URI/路径构造、scheme 分级、JSON 往返、copyWith。
 * 不含 SharedPreferences 读写（落盘由 Lead 在 golden 样本到位后统一接）。
 *
 * Dart 对拍锚点（test/services/webdav_sync_config_test.dart、
 * test/services/webdav_sync_service_test.dart）：
 * - normalizedRemoteFolder 缺省/补斜杠；
 * - snapshot/meta/history 路径拼接；
 * - sanitizeHistoryBackupFileName 只留 basename，`..`/空抛错；
 * - inspect scheme：https 放行、http 单列、其余 invalid。
 */

enum class WebdavSyncProvider(val value: String) {
    JIANGUOYUN("jianguoyun"),
    CUSTOM("custom");

    companion object {
        fun fromValue(raw: Any?): WebdavSyncProvider =
            entries.firstOrNull { it.value == raw?.toString() } ?: JIANGUOYUN
    }
}

enum class WebdavSyncMode(val value: String) {
    MANUAL("manual"),
    AUTO("auto");

    companion object {
        fun fromValue(raw: Any?): WebdavSyncMode =
            entries.firstOrNull { it.value == raw?.toString() } ?: AUTO
    }
}

/** baseUrl 的 scheme 分级（2026-10-19 安全清单 #4，Dart 原样）。 */
enum class WebdavBaseUrlScheme {
    HTTPS,
    INSECURE_HTTP,
    INVALID,
}

/**
 * 检查 WebDAV baseUrl 的 scheme。
 * Dart：`Uri.tryParse(raw.trim())?.scheme.toLowerCase()`。
 */
fun inspectWebdavBaseUrlScheme(raw: String): WebdavBaseUrlScheme {
    val trimmed = raw.trim()
    val scheme = try {
        java.net.URI(trimmed).scheme?.lowercase() ?: ""
    } catch (_: Exception) {
        // Dart Uri.tryParse 失败返回 null → invalid；java.net.URI 抛异常同样归 invalid。
        // 形如 "http://a b/" 的非法字符两种实现都判 invalid，口径一致。
        return WebdavBaseUrlScheme.INVALID
    }
    // 无 scheme（相对路径）Dart scheme 为 "" → invalid。
    if (scheme.isEmpty()) return WebdavBaseUrlScheme.INVALID
    return when (scheme) {
        "https" -> WebdavBaseUrlScheme.HTTPS
        "http" -> WebdavBaseUrlScheme.INSECURE_HTTP
        else -> WebdavBaseUrlScheme.INVALID
    }
}

data class WebdavSyncConfig(
    val enabled: Boolean = false,
    val provider: WebdavSyncProvider = WebdavSyncProvider.JIANGUOYUN,
    val syncMode: WebdavSyncMode = WebdavSyncMode.AUTO,
    val baseUrl: String = DEFAULT_JIANGUOYUN_BASE_URL,
    val remoteFolder: String = DEFAULT_REMOTE_FOLDER,
    val username: String = "",
    /** ISO-8601（Dart DateTime.toIso8601String），null 表未同步过。 */
    val lastSyncedAtIso: String? = null,
    val lastAppliedRemoteHash: String? = null,
    val lastUploadedLocalHash: String? = null,
    val maxBackupCount: Int = DEFAULT_MAX_BACKUP_COUNT,
    val maxBackupAgeDays: Int = DEFAULT_MAX_BACKUP_AGE_DAYS,
    val manualBackupProtected: Boolean = true,
    /**
     * 最近一次同步数据里是否含用户数据；null=未知（旧版/从未同步），按「不能拦」处理。
     * Dart 注释见 webdav_sync_config.dart:62-80。
     */
    val lastUploadedHadUserData: Boolean? = null,
) {
    companion object {
        const val PREFS_KEY = "webdav_sync_config_v1"
        const val DEFAULT_JIANGUOYUN_BASE_URL = "https://dav.jianguoyun.com/dav/"
        const val DEFAULT_REMOTE_FOLDER = "/Apps/qingyu-sync/"
        const val SNAPSHOT_FILE_NAME = "snapshot.mikcb"
        const val META_FILE_NAME = "snapshot.meta.json"
        const val HISTORY_FOLDER_NAME = "history"
        const val HISTORY_INDEX_FILE_NAME = "index.json"
        const val DEFAULT_MAX_BACKUP_COUNT = 15
        const val DEFAULT_MAX_BACKUP_AGE_DAYS = 30

        /**
         * 历史备份安全单段文件名（Dart `sanitizeHistoryBackupFileName` 原样）。
         * @throws IllegalArgumentException 空名 → backup_file_name_required；
         * `..`/`.`/含 `..` → backup_file_name_invalid。
         */
        fun sanitizeHistoryBackupFileName(fileName: String): String {
            val trimmed = fileName.trim()
            if (trimmed.isEmpty()) {
                throw IllegalArgumentException("backup_file_name_required")
            }
            val withoutSlashes = trimmed.replace('\\', '/')
                .split('/')
                .filter { it.isNotEmpty() }
                .lastOrNull()
                ?: throw IllegalArgumentException("backup_file_name_required")
            if (withoutSlashes.isEmpty() ||
                withoutSlashes == "." ||
                withoutSlashes == ".." ||
                withoutSlashes.contains("..")
            ) {
                throw IllegalArgumentException("backup_file_name_invalid")
            }
            return withoutSlashes
        }

        fun fromJson(json: Map<String, Any?>): WebdavSyncConfig {
            return WebdavSyncConfig(
                enabled = json["enabled"] as? Boolean ?: false,
                provider = WebdavSyncProvider.fromValue(json["provider"]),
                syncMode = WebdavSyncMode.fromValue(json["syncMode"]),
                baseUrl = json["baseUrl"] as? String ?: DEFAULT_JIANGUOYUN_BASE_URL,
                remoteFolder = json["remoteFolder"] as? String ?: DEFAULT_REMOTE_FOLDER,
                username = json["username"] as? String ?: "",
                lastSyncedAtIso = json["lastSyncedAt"] as? String,
                lastAppliedRemoteHash = json["lastAppliedRemoteHash"] as? String,
                lastUploadedLocalHash = json["lastUploadedLocalHash"] as? String,
                maxBackupCount = (json["maxBackupCount"] as? Number)?.toInt()
                    ?: DEFAULT_MAX_BACKUP_COUNT,
                maxBackupAgeDays = (json["maxBackupAgeDays"] as? Number)?.toInt()
                    ?: DEFAULT_MAX_BACKUP_AGE_DAYS,
                manualBackupProtected = json["manualBackupProtected"] as? Boolean ?: true,
                // 类型不符按未知处理（Dart 原文：手改坏了也不能变成误拦开关）。
                lastUploadedHadUserData = json["lastUploadedHadUserData"] as? Boolean,
            )
        }
    }

    val normalizedRemoteFolder: String
        get() {
            var folder = remoteFolder.trim()
            if (folder.isEmpty()) folder = DEFAULT_REMOTE_FOLDER
            if (!folder.startsWith("/")) folder = "/$folder"
            if (!folder.endsWith("/")) folder = "$folder/"
            return folder
        }

    val snapshotRemotePath: String get() = "$normalizedRemoteFolder$SNAPSHOT_FILE_NAME"
    val metaRemotePath: String get() = "$normalizedRemoteFolder$META_FILE_NAME"
    val historyRemoteFolder: String get() = "$normalizedRemoteFolder$HISTORY_FOLDER_NAME/"
    val historyIndexRemotePath: String get() = "$historyRemoteFolder$HISTORY_INDEX_FILE_NAME"

    /** 远端历史备份路径（只留 basename，防 `..` 穿越，Dart 原样）。 */
    fun historyBackupRemotePath(fileName: String): String {
        val sanitized = sanitizeHistoryBackupFileName(fileName)
        return "$historyRemoteFolder$sanitized"
    }

    @Suppress("LongParameterList")
    fun copyWith(
        enabled: Boolean? = null,
        provider: WebdavSyncProvider? = null,
        syncMode: WebdavSyncMode? = null,
        baseUrl: String? = null,
        remoteFolder: String? = null,
        username: String? = null,
        lastSyncedAtIso: String? = null,
        lastAppliedRemoteHash: String? = null,
        lastUploadedLocalHash: String? = null,
        maxBackupCount: Int? = null,
        maxBackupAgeDays: Int? = null,
        manualBackupProtected: Boolean? = null,
        lastUploadedHadUserData: Boolean? = null,
        clearLastSyncedAt: Boolean = false,
        clearLastAppliedRemoteHash: Boolean = false,
        clearLastUploadedLocalHash: Boolean = false,
        clearLastUploadedHadUserData: Boolean = false,
    ): WebdavSyncConfig {
        return WebdavSyncConfig(
            enabled = enabled ?: this.enabled,
            provider = provider ?: this.provider,
            syncMode = syncMode ?: this.syncMode,
            baseUrl = baseUrl ?: this.baseUrl,
            remoteFolder = remoteFolder ?: this.remoteFolder,
            username = username ?: this.username,
            lastSyncedAtIso = if (clearLastSyncedAt) null else (lastSyncedAtIso ?: this.lastSyncedAtIso),
            lastAppliedRemoteHash = if (clearLastAppliedRemoteHash) null
            else (lastAppliedRemoteHash ?: this.lastAppliedRemoteHash),
            lastUploadedLocalHash = if (clearLastUploadedLocalHash) null
            else (lastUploadedLocalHash ?: this.lastUploadedLocalHash),
            maxBackupCount = maxBackupCount ?: this.maxBackupCount,
            maxBackupAgeDays = maxBackupAgeDays ?: this.maxBackupAgeDays,
            manualBackupProtected = manualBackupProtected ?: this.manualBackupProtected,
            lastUploadedHadUserData = if (clearLastUploadedHadUserData) null
            else (lastUploadedHadUserData ?: this.lastUploadedHadUserData),
        )
    }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "enabled" to enabled,
        "provider" to provider.value,
        "syncMode" to syncMode.value,
        "baseUrl" to baseUrl,
        "remoteFolder" to remoteFolder,
        "username" to username,
        "lastSyncedAt" to lastSyncedAtIso,
        "lastAppliedRemoteHash" to lastAppliedRemoteHash,
        "lastUploadedLocalHash" to lastUploadedLocalHash,
        "maxBackupCount" to maxBackupCount,
        "maxBackupAgeDays" to maxBackupAgeDays,
        "manualBackupProtected" to manualBackupProtected,
        "lastUploadedHadUserData" to lastUploadedHadUserData,
    )
}
