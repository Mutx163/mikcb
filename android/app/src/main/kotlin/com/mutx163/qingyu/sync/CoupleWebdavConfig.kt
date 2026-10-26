package com.mutx163.qingyu.sync

/**
 * 情侣 WebDAV 配置纯逻辑（源：lib/services/couple_webdav_config.dart）。
 *
 * 双槽位：本机写 mySlot、对端读 partnerSlot；旧单文件路径仅拉取回落。
 * baseUrl 校验与云同步同源（inspectWebdavBaseUrlScheme），但情侣页无二次确认
 * 入口，http 明文一律拒绝（Dart `validatedCoupleWebdavBaseUrl` 原样）。
 */

data class CoupleWebdavConfig(
    val baseUrl: String = DEFAULT_JIANGUOYUN_BASE_URL,
    val remoteFolder: String = DEFAULT_REMOTE_FOLDER,
    val username: String = "",
    val mySlot: Int = 1,
    /** ISO-8601，null 表从未拉取。 */
    val lastPulledAtIso: String? = null,
    val lastRemoteContentHash: String? = null,
) {
    companion object {
        const val PREFS_KEY = "couple_webdav_config_v1"
        const val DEFAULT_JIANGUOYUN_BASE_URL = "https://dav.jianguoyun.com/dav/"
        const val DEFAULT_REMOTE_FOLDER = "/Apps/qingyu-couple/"
        const val PARTNER_TIMETABLE_FILE_NAME = "partner-timetable.mikcb"
        const val MINE_TIMETABLE_FILE_NAME = "mine-timetable.mikcb"
        const val COUPLE_SLOT_1_FILE_NAME = "couple-slot-1.mikcb"
        const val COUPLE_SLOT_2_FILE_NAME = "couple-slot-2.mikcb"

        fun fromJson(json: Map<String, Any?>): CoupleWebdavConfig {
            val rawSlot = (json["mySlot"] as? Number)?.toInt() ?: 1
            return CoupleWebdavConfig(
                baseUrl = json["baseUrl"] as? String ?: DEFAULT_JIANGUOYUN_BASE_URL,
                remoteFolder = json["remoteFolder"] as? String ?: DEFAULT_REMOTE_FOLDER,
                username = json["username"] as? String ?: "",
                mySlot = if (rawSlot == 2) 2 else 1,
                lastPulledAtIso = json["lastPulledAt"] as? String,
                lastRemoteContentHash = json["lastRemoteContentHash"] as? String,
            )
        }
    }

    val normalizedMySlot: Int get() = if (mySlot == 2) 2 else 1
    val partnerSlot: Int get() = if (normalizedMySlot == 1) 2 else 1

    val normalizedRemoteFolder: String
        get() {
            var folder = remoteFolder.trim()
            if (folder.isEmpty()) folder = DEFAULT_REMOTE_FOLDER
            if (!folder.startsWith("/")) folder = "/$folder"
            if (!folder.endsWith("/")) folder = "$folder/"
            return folder
        }

    private fun slotFileName(slot: Int): String =
        if (slot == 2) COUPLE_SLOT_2_FILE_NAME else COUPLE_SLOT_1_FILE_NAME

    /** 本机读对端课表的远端文件。 */
    val partnerTimetableRemotePath: String
        get() = "$normalizedRemoteFolder${slotFileName(partnerSlot)}"

    /** 本机写给对端拉的远端文件。 */
    val mineTimetableRemotePath: String
        get() = "$normalizedRemoteFolder${slotFileName(normalizedMySlot)}"

    /** 旧单路径（双槽前）；拉取回落用，不再写入。 */
    val legacyPartnerTimetableRemotePath: String
        get() = "$normalizedRemoteFolder$PARTNER_TIMETABLE_FILE_NAME"

    fun copyWith(
        baseUrl: String? = null,
        remoteFolder: String? = null,
        username: String? = null,
        mySlot: Int? = null,
        lastPulledAtIso: String? = null,
        lastRemoteContentHash: String? = null,
        clearLastPulledAt: Boolean = false,
        clearLastRemoteContentHash: Boolean = false,
    ): CoupleWebdavConfig {
        return CoupleWebdavConfig(
            baseUrl = baseUrl ?: this.baseUrl,
            remoteFolder = remoteFolder ?: this.remoteFolder,
            username = username ?: this.username,
            mySlot = mySlot ?: this.mySlot,
            lastPulledAtIso = if (clearLastPulledAt) null else (lastPulledAtIso ?: this.lastPulledAtIso),
            lastRemoteContentHash = if (clearLastRemoteContentHash) null
            else (lastRemoteContentHash ?: this.lastRemoteContentHash),
        )
    }

    fun toJson(): Map<String, Any?> = linkedMapOf(
        "baseUrl" to baseUrl,
        "remoteFolder" to remoteFolder,
        "username" to username,
        "mySlot" to normalizedMySlot,
        "lastPulledAt" to lastPulledAtIso,
        "lastRemoteContentHash" to lastRemoteContentHash,
    )
}

/**
 * 解析并校验情侣同步 baseUrl（Dart `validatedCoupleWebdavBaseUrl` 原样）。
 * @return 可直接交给 WebDAV 客户端的地址；不可用返回 null。
 */
fun validatedCoupleWebdavBaseUrl(raw: String): String? {
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) {
        return CoupleWebdavConfig.DEFAULT_JIANGUOYUN_BASE_URL
    }
    return if (inspectWebdavBaseUrlScheme(trimmed) == WebdavBaseUrlScheme.HTTPS) {
        trimmed
    } else {
        null
    }
}
