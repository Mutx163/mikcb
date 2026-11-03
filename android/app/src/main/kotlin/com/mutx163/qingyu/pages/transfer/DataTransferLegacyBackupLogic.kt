package com.mutx163.qingyu.pages.transfer

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
 * `.mikcb` 文件 / 二维码文本的**兼容解析**（Dart `DataTransferService.parseCompatible`）。
 *
 * ## 为什么需要这一层
 *
 * Dart 的文件导入不是「一律走当前的 `TransferPackage` 信封」，而是三段：
 * 1. 文本是信封（`app == 'mikcb' && packageType == 'transfer'`）→ 只走
 *    `TransferPackage.decode`，坏了就**整份拒收**（fail closed，绝不回退）；
 * 2. 不是信封 → `parseFullBackupJson`（老的全量备份，`backupType: 'full'`）；
 * 3. 还不是 → `parseBackupJson`（老的 `.mikcb` 单课表单档备份：只有 `app` +
 *    `schemaVersion` + `courses` + `settings`，其余键可缺）。
 *
 * Kotlin 侧只实现了第 1 段（[DataTransferImportLogic.parse] 先跑
 * `validateTransferPackageJson`），于是库里已经注册好的
 * `unrecognized_mikcb_data_file` / `missing_settings_data` /
 * `unrecognized_mikcb_full_backup` / `missing_full_backup_data`
 * （见 [TransferServiceMessages]）从来没有被产出过——老文件导入一律报
 * `transfer_app_invalid` / `transfer_package_type_required`，用户手里的旧备份
 * 升级后直接报废。这不是文案问题，是**整条旧格式通道缺失**。
 *
 * ## 逐条对拍后的语义（与 Dart `data_transfer_service.dart:228-409` 同）
 *
 * - **信封 fail closed**：`isTransferEnvelopeJson` 为真时原样返回严格解析的错码，
 *   绝不回退到旧格式——防止「信封里 `courses` 坏了」被旧通道当成单课表包救回。
 * - **`courses` 是唯一必需列表**：键缺失 / null → `unrecognized_mikcb_data_file`；
 *   **原始非空但一条都解析不出来** → 同码（否则整份替换会把用户课表清空）；
 *   部分坏 → 逐条跳过并计入 `droppedCounts`（成功提示里如实报「跳过了 N 条」）。
 * - 其余列表（tasks / scheduleItems / exams / timeSchemes / scheduleDateRules /
 *   locationTimeGroups）：键缺失 = 不导入该类数据（历史宽容），但**整表全坏**
 *   依旧拒收（Dart 同用 `_parseListWithTotalLossGuard`）。
 * - **`settings` 必须是对象** → 否则 `missing_settings_data`（Dart :269-272）。
 * - **`currentWeek`**：先 `clamp(1, 30)` 再按设置里的周次上限收敛（Dart :305-308）。
 * - **全量旧备份**：`app`/`schemaVersion`/`backupType == 'full'` 三者齐；
 *   `profiles` 与 `timeSchemes` 必须是数组且**容器不许静默变少**（一条坏 = 整份拒收
 *   `missing_full_backup_data`）；日期规则 / 地点分组仍是条目级 salvage。
 *
 * 特意**不**做的：LAN 旧版 5 键导出包兼容层（裁决已定，LAN 保持 Dart 的整份替换语义），
 * 以及云备份合并恢复（`canMerge` 恒 false）。这两项都不在本文件里。
 */
object DataTransferLegacyBackupLogic {

    private const val APP_ID = "mikcb"

    /**
     * 兼容解析入口。
     *
     * @param channel 传输通道覆盖（二维码 / 文件）。旧格式包里 `channel` 键可能缺失或
     *   写着 `file`，但用户是从二维码扫进来的，预览与落盘都该按实际通道记。
     */
    fun parseCompatible(
        content: String,
        channel: TransferChannel? = null,
    ): TransferImportParseResult {
        val strict = DataTransferImportLogic.parse(content)
        if (strict is TransferImportParseResult.Valid) {
            return if (channel == null) strict else withChannel(strict, channel)
        }
        // 信封坏 = 整份拒收（Dart `parseCompatible` 的 fail closed）。
        if (TransferEnvelope.isTransferEnvelopeJson(content)) return strict
        val root = decodeRoot(content) ?: return strict
        val result = if (isFullBackupJson(root)) {
            parseFullBackup(root, channel)
        } else {
            parseBackup(root, channel)
        }
        return result
    }

    /** Dart `isFullBackupJson`（:321-327）：`backupType == 'full'` 或「信封形状的全量包」。 */
    private fun isFullBackupJson(root: Map<String, Any?>): Boolean {
        if (root["backupType"] == "full") return true
        return root["packageType"] == TransferEnvelope.PACKAGE_TYPE &&
            root["scope"] == TransferScope.ALL_DATA.value &&
            root["profiles"] is List<*>
    }

    private fun parseFullBackup(
        root: Map<String, Any?>,
        channel: TransferChannel?,
    ): TransferImportParseResult {
        val app = root["app"] as? String
        val version = (root["schemaVersion"] as? Number)?.toInt() ?: 0
        if (app != APP_ID || version != TransferEnvelope.SCHEMA_VERSION ||
            root["backupType"] != "full"
        ) {
            return TransferImportParseResult.Invalid("unrecognized_mikcb_full_backup")
        }
        val rawProfiles = root["profiles"]
        val rawTimeSchemes = root["timeSchemes"]
        if (rawProfiles !is List<*> || rawTimeSchemes !is List<*>) {
            return TransferImportParseResult.Invalid("missing_full_backup_data")
        }
        val profiles = try {
            mapStrict(rawProfiles) { TimetableProfile.fromJson(it) }
        } catch (_: Exception) {
            return TransferImportParseResult.Invalid("missing_full_backup_data")
        }
        val timeSchemes = try {
            mapStrict(rawTimeSchemes) { TimeScheme.fromJson(it) }
        } catch (_: Exception) {
            return TransferImportParseResult.Invalid("missing_full_backup_data")
        }
        if (rawProfiles.size != profiles.size || rawTimeSchemes.size != timeSchemes.size) {
            return TransferImportParseResult.Invalid("missing_full_backup_data")
        }
        val dropped = LinkedHashMap<String, Int>()
        val rules = try {
            salvageList(root["scheduleDateRules"], "scheduleDateRules", dropped) {
                ScheduleDateRule.fromJson(it)
            }
        } catch (_: Exception) {
            return TransferImportParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        val groups = try {
            salvageList(root["locationTimeGroups"], "locationTimeGroups", dropped) {
                LocationTimeGroup.fromJson(it)
            }
        } catch (_: Exception) {
            return TransferImportParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        val plan = TransferImportPlan(
            profiles = profiles,
            activeProfileId = root["activeProfileId"] as? String,
            courses = emptyList(),
            settings = null,
            currentWeek = null,
            timeSchemes = timeSchemes,
            tasks = emptyList(),
            exams = emptyList(),
            scheduleItems = emptyList(),
            scheduleDateRules = rules,
            locationTimeGroups = groups,
        )
        val info = TransferImportPackageInfo(
            scope = TransferScope.ALL_DATA,
            channel = channel ?: TransferChannel.fromValue(root["channel"]),
            packageId = (root["packageId"] as? String).orEmpty(),
            isFullBackup = true,
            profileName = null,
            currentWeek = null,
            courseCount = profiles.sumOf { it.courses.size },
            profileCount = profiles.size,
            droppedCounts = dropped,
        )
        return TransferImportParseResult.Valid(info, plan)
    }

    private fun parseBackup(
        root: Map<String, Any?>,
        channel: TransferChannel?,
    ): TransferImportParseResult {
        val app = root["app"] as? String
        val version = (root["schemaVersion"] as? Number)?.toInt() ?: 0
        if (app != APP_ID || version != TransferEnvelope.SCHEMA_VERSION) {
            return TransferImportParseResult.Invalid("unrecognized_mikcb_data_file")
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
            return TransferImportParseResult.Invalid(
                error.message ?: "unrecognized_mikcb_data_file",
            )
        } catch (_: Exception) {
            return TransferImportParseResult.Invalid("unrecognized_mikcb_data_file")
        }
        val rawSettings = root["settings"]
        if (rawSettings !is Map<*, *>) {
            return TransferImportParseResult.Invalid("missing_settings_data")
        }
        val settings = try {
            @Suppress("UNCHECKED_CAST")
            TimetableSettings.fromJson(rawSettings as Map<String, Any?>)
        } catch (_: Exception) {
            return TransferImportParseResult.Invalid("missing_settings_data")
        }
        val currentWeek = clampCurrentWeekToSettings(
            (((root["currentWeek"] as? Number)?.toInt() ?: 1).coerceIn(1, 30)).toLong(),
            settings,
        ).toInt()
        val scope = if (root["packageType"] == TransferEnvelope.PACKAGE_TYPE) {
            try {
                TransferScope.fromValue(root["scope"])
            } catch (_: Exception) {
                return TransferImportParseResult.Invalid("transfer_scope_invalid")
            }
        } else {
            TransferScope.CURRENT_TIMETABLE
        }
        val plan = TransferImportPlan(
            profiles = emptyList(),
            activeProfileId = null,
            courses = courses,
            settings = settings,
            currentWeek = currentWeek,
            timeSchemes = timeSchemes,
            tasks = tasks,
            exams = exams,
            scheduleItems = scheduleItems,
            scheduleDateRules = rules,
            locationTimeGroups = groups,
        )
        val info = TransferImportPackageInfo(
            scope = scope,
            channel = channel ?: TransferChannel.fromValue(root["channel"]),
            packageId = (root["packageId"] as? String).orEmpty(),
            isFullBackup = false,
            profileName = (root["profileName"] as? String)?.trim()?.ifEmpty { null },
            currentWeek = currentWeek,
            courseCount = courses.size,
            profileCount = 0,
            droppedCounts = dropped,
        )
        return TransferImportParseResult.Valid(info, plan)
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

    private fun withChannel(
        valid: TransferImportParseResult.Valid,
        channel: TransferChannel,
    ): TransferImportParseResult.Valid =
        valid.copy(info = valid.info.copy(channel = channel))

    private fun decodeRoot(content: String): Map<String, Any?>? {
        val decoded = try {
            MiniJson.parse(content)
        } catch (_: Exception) {
            return null
        }
        @Suppress("UNCHECKED_CAST")
        return decoded as? Map<String, Any?>
    }
}
