package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope

/**
 * 旧格式 `.mikcb` 备份的**纯解析层**（Dart `DataTransferService.parseBackupJson` /
 * `parseFullBackupJson`，`lib/services/data_transfer_service.dart:228-409`）。
 *
 * ## 为什么放在 `transfer/`
 *
 * 文件导入（`pages/transfer`）与局域网导入（`transfer/lan`）都要吃老包；把解析放这里，
 * 两侧都**向下**依赖，避免 `transfer/` 反向依赖 `pages/`。`pages/transfer` 的
 * `DataTransferLegacyBackupLogic` 只负责把 [LegacyBackupPayload] 映射成页面自己的
 * `TransferImportParseResult`，解析语义留在这一个文件里。
 *
 * ## 语义（与 Dart 逐条对齐）
 *
 * - 单课表旧包（只有 `app` + `schemaVersion` + `courses` + `settings`，其余键可缺）；
 * - 全量旧备份（`backupType == 'full'`，`profiles` / `timeSchemes` 严格）；
 * - `courses` 是唯一必需列表：缺失 / 原始非空但一条都救不回 → 整份拒收；
 * - 其余列表缺失 = 不导入该类数据，整表全坏仍拒收（`_parseListWithTotalLossGuard`）；
 * - `settings` 必须是对象；`currentWeek` 先 clamp(1,30) 再按设置收敛；
 * - 信封形状（`app=mikcb && packageType=transfer`）**绝不**回退到这里（调用方 fail closed）。
 */
sealed interface LegacyBackupParseResult {
    data class Valid(val payload: LegacyBackupPayload) : LegacyBackupParseResult

    data class Invalid(val code: String) : LegacyBackupParseResult
}

/** 旧包解析后的中性载荷（字段含义与 Dart `AppDataBackup` 同）。 */
data class LegacyBackupPayload(
    val scope: TransferScope,
    val channel: TransferChannel,
    val packageId: String,
    val isFullBackup: Boolean,
    val profileName: String?,
    val currentWeek: Int?,
    val activeProfileId: String?,
    val profiles: List<TimetableProfile> = emptyList(),
    val courses: List<Course> = emptyList(),
    val settings: TimetableSettings? = null,
    val timeSchemes: List<TimeScheme> = emptyList(),
    val tasks: List<CourseTask> = emptyList(),
    val exams: List<Exam> = emptyList(),
    val scheduleItems: List<ScheduleItem> = emptyList(),
    val scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    val locationTimeGroups: List<LocationTimeGroup> = emptyList(),
    /** 整份设置的原始 map（Dart 250+ 键），局域网落盘要用。 */
    val settingsJson: Map<String, Any?>? = null,
    /** 逐条跳过的坏条目（键 → 条数）。 */
    val droppedCounts: Map<String, Int> = emptyMap(),
)

object LegacyBackupPackage {

    private const val APP_ID = "mikcb"

    /**
     * 解析一棵已经 `MiniJson` 解码过的根对象。
     *
     * @param channel 通道覆盖（二维码 / 文件 / 局域网）；包里的 `channel` 只是元信息。
     */
    fun parse(
        root: Map<String, Any?>,
        channel: TransferChannel? = null,
    ): LegacyBackupParseResult =
        if (isFullBackupJson(root)) {
            parseFullBackup(root, channel)
        } else {
            parseBackup(root, channel)
        }

    /** Dart `isFullBackupJson`（:321-327）：`backupType == 'full'` 或「信封形状的全量包」。 */
    fun isFullBackupJson(root: Map<String, Any?>): Boolean {
        if (root["backupType"] == "full") return true
        return root["packageType"] == TransferEnvelope.PACKAGE_TYPE &&
            root["scope"] == TransferScope.ALL_DATA.value &&
            root["profiles"] is List<*>
    }

    /** JSON 文本 → 根对象；不是 JSON 对象时返回 null。 */
    fun decodeRoot(content: String): Map<String, Any?>? {
        val decoded = try {
            MiniJson.parse(content)
        } catch (_: Exception) {
            return null
        }
        @Suppress("UNCHECKED_CAST")
        return decoded as? Map<String, Any?>
    }

    /**
     * 是不是「真正的旧备份」——单档：`app == 'mikcb'` 且不在传输信封形状里；
     * 全量：`backupType == 'full'`（即使 `app` 写错也要让全量分支自己报
     * `unrecognized_mikcb_full_backup`，保持既有错误码）。
     *
     * 外来形状（`app != 'mikcb'` 且非 full、或已经在信封里）绝不能借旧通道兜底，
     * 否则严格的 `transfer_package_type_invalid` 会被旧错误码覆盖（调用方行为变化）。
     */
    fun looksLikeLegacyBackup(root: Map<String, Any?>): Boolean {
        if (root["backupType"] == "full") return true
        return root["app"] == APP_ID && root["packageType"] != TransferEnvelope.PACKAGE_TYPE
    }

    private fun parseFullBackup(
        root: Map<String, Any?>,
        channel: TransferChannel?,
    ): LegacyBackupParseResult {
        val app = root["app"] as? String
        val version = (root["schemaVersion"] as? Number)?.toInt() ?: 0
        if (app != APP_ID || version != TransferEnvelope.SCHEMA_VERSION ||
            root["backupType"] != "full"
        ) {
            return LegacyBackupParseResult.Invalid("unrecognized_mikcb_full_backup")
        }
        val rawProfiles = root["profiles"]
        val rawTimeSchemes = root["timeSchemes"]
        if (rawProfiles !is List<*> || rawTimeSchemes !is List<*>) {
            return LegacyBackupParseResult.Invalid("missing_full_backup_data")
        }
        val profiles = try {
            mapStrict(rawProfiles) { TimetableProfile.fromJson(it) }
        } catch (_: Exception) {
            return LegacyBackupParseResult.Invalid("missing_full_backup_data")
        }
        val timeSchemes = try {
            mapStrict(rawTimeSchemes) { TimeScheme.fromJson(it) }
        } catch (_: Exception) {
            return LegacyBackupParseResult.Invalid("missing_full_backup_data")
        }
        if (rawProfiles.size != profiles.size || rawTimeSchemes.size != timeSchemes.size) {
            return LegacyBackupParseResult.Invalid("missing_full_backup_data")
        }
        val dropped = LinkedHashMap<String, Int>()
        val rules = try {
            salvageList(root["scheduleDateRules"], "scheduleDateRules", dropped) {
                ScheduleDateRule.fromJson(it)
            }
        } catch (_: Exception) {
            return LegacyBackupParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        val groups = try {
            salvageList(root["locationTimeGroups"], "locationTimeGroups", dropped) {
                LocationTimeGroup.fromJson(it)
            }
        } catch (_: Exception) {
            return LegacyBackupParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        return LegacyBackupParseResult.Valid(
            LegacyBackupPayload(
                scope = TransferScope.ALL_DATA,
                channel = channel ?: TransferChannel.fromValue(root["channel"]),
                packageId = (root["packageId"] as? String).orEmpty(),
                isFullBackup = true,
                profileName = null,
                currentWeek = null,
                activeProfileId = root["activeProfileId"] as? String,
                profiles = profiles,
                timeSchemes = timeSchemes,
                scheduleDateRules = rules,
                locationTimeGroups = groups,
                droppedCounts = dropped,
            ),
        )
    }

    private fun parseBackup(
        root: Map<String, Any?>,
        channel: TransferChannel?,
    ): LegacyBackupParseResult {
        val app = root["app"] as? String
        val version = (root["schemaVersion"] as? Number)?.toInt() ?: 0
        if (app != APP_ID || version != TransferEnvelope.SCHEMA_VERSION) {
            return LegacyBackupParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        val dropped = LinkedHashMap<String, Int>()
        val courses: List<Course>
        val tasks: List<CourseTask>
        val scheduleItems: List<ScheduleItem>
        val exams: List<Exam>
        val timeSchemes: List<TimeScheme>
        val rules: List<ScheduleDateRule>
        val groups: List<LocationTimeGroup>
        try {
            courses = salvageList(root["courses"], "courses", dropped, required = true) {
                Course.fromJson(it)
            }
            tasks = salvageList(root["tasks"], "tasks", dropped) { CourseTask.fromJson(it) }
            scheduleItems = salvageList(root["scheduleItems"], "scheduleItems", dropped) {
                ScheduleItem.fromJson(it)
            }
            exams = salvageList(root["exams"], "exams", dropped) { Exam.fromJson(it) }
            timeSchemes = salvageList(root["timeSchemes"], "timeSchemes", dropped) {
                TimeScheme.fromJson(it)
            }
            rules = salvageList(root["scheduleDateRules"], "scheduleDateRules", dropped) {
                ScheduleDateRule.fromJson(it)
            }
            groups = salvageList(root["locationTimeGroups"], "locationTimeGroups", dropped) {
                LocationTimeGroup.fromJson(it)
            }
        } catch (error: DartFormatException) {
            return LegacyBackupParseResult.Invalid(error.message ?: "unrecognized_mikcb_data_file")
        } catch (_: Exception) {
            return LegacyBackupParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        val rawSettings = root["settings"]
        if (rawSettings !is Map<*, *>) {
            return LegacyBackupParseResult.Invalid("missing_settings_data")
        }
        val settings = try {
            @Suppress("UNCHECKED_CAST")
            TimetableSettings.fromJson(rawSettings as Map<String, Any?>)
        } catch (_: Exception) {
            return LegacyBackupParseResult.Invalid("missing_settings_data")
        }
        val currentWeek = clampCurrentWeekToSettings(
            (((root["currentWeek"] as? Number)?.toInt() ?: 1).coerceIn(1, 30)).toLong(),
            settings,
        ).toInt()
        val scope = if (root["packageType"] == TransferEnvelope.PACKAGE_TYPE) {
            try {
                TransferScope.fromValue(root["scope"])
            } catch (_: Exception) {
                return LegacyBackupParseResult.Invalid("transfer_scope_invalid")
            }
        } else {
            TransferScope.CURRENT_TIMETABLE
        }
        return LegacyBackupParseResult.Valid(
            LegacyBackupPayload(
                scope = scope,
                channel = channel ?: TransferChannel.fromValue(root["channel"]),
                packageId = (root["packageId"] as? String).orEmpty(),
                isFullBackup = false,
                profileName = (root["profileName"] as? String)?.trim()?.ifEmpty { null },
                currentWeek = currentWeek,
                activeProfileId = null,
                courses = courses,
                settings = settings,
                timeSchemes = timeSchemes,
                tasks = tasks,
                exams = exams,
                scheduleItems = scheduleItems,
                scheduleDateRules = rules,
                locationTimeGroups = groups,
                settingsJson = settingsJson(rawSettings),
                droppedCounts = dropped,
            ),
        )
    }

    /** 整份设置的原始 map（键统一成 String；非对象 → null）。 */
    fun settingsJson(raw: Any?): Map<String, Any?>? {
        if (raw !is Map<*, *>) return null
        val out = LinkedHashMap<String, Any?>(raw.size)
        for ((key, value) in raw) {
            if (key is String) out[key] = value
        }
        return out
    }

    /** Dart `_parseOptionalList` 的严格版：非 Map / 解析异常都让整份拒收。 */
    private inline fun <T> mapStrict(
        raw: List<*>,
        parse: (Map<String, Any?>) -> T,
    ): List<T> {
        val out = ArrayList<T>(raw.size)
        for (item in raw) {
            @Suppress("UNCHECKED_CAST")
            val map = item as? Map<String, Any?>
                ?: throw DartFormatException("missing_full_backup_data")
            out.add(parse(map))
        }
        return out
    }

    /**
     * Dart `_parseListWithTotalLossGuard`：
     * - `raw == null && required` → 拒收；
     * - 非数组 → 空列表（历史宽容）；
     * - 数组非空但**一条都没救回** → 拒收（防止「导入成功 = 清空」）；
     * - 部分坏 → 跳过并记入 [dropped]。
     */
    private inline fun <T> salvageList(
        raw: Any?,
        key: String,
        dropped: MutableMap<String, Int>,
        required: Boolean = false,
        parse: (Map<String, Any?>) -> T,
    ): List<T> {
        if (raw == null && required) throw DartFormatException("unrecognized_mikcb_data_file")
        if (raw !is List<*>) return emptyList()
        val out = ArrayList<T>(raw.size)
        for (item in raw) {
            try {
                @Suppress("UNCHECKED_CAST")
                val map = item as? Map<String, Any?> ?: continue
                out.add(parse(map))
            } catch (_: Exception) {
                continue
            }
        }
        if (raw.isNotEmpty()) {
            val lost = raw.size - out.size
            if (lost > 0) {
                if (out.isEmpty()) throw DartFormatException("unrecognized_mikcb_data_file")
                dropped[key] = (dropped[key] ?: 0) + lost
            }
        }
        return out
    }
}
