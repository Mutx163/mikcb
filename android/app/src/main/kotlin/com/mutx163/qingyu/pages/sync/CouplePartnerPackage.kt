package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson

/**
 * 情侣课表的**单档包**（Dart `DataTransferService.buildBackupJson` / `parseBackupJson`
 * 里情侣这条路用到的那一半）。
 *
 * ## 为什么单独一个文件
 *
 * 导入对方课表与「上传我的课表到坚果云」用的是**同一份**单档包格式：
 * `{app, packageType, schemaVersion, packageId, scope, channel, exportedAt,
 *   profileName, currentWeek, settings, courses, tasks, scheduleItems, ...}`。
 * 它既不是「整机全量备份」（`backupType: full`），也不是情侣私有格式——
 * 所以解析/组包的判据必须和备份是**同一套**（直接复用 `buildTransferPackageJson`），
 * 只在这里补「情侣只收单档、整机备份一律拒」那两条门。
 *
 * ## 与 Dart 对齐的三条硬口径
 *
 * 1. **信封门**：`app != "mikcb"` 或 `schemaVersion != 1` → `unrecognized_mikcb_data_file`；
 * 2. **整机备份门**：`backupType == "full"`，或 `packageType`/`scope == all_data` 且带
 *    `profiles` 列表 → `partner_import_requires_single_profile`；
 * 3. **全丢守卫**：`courses` 键缺失 → 整份拒收；某个列表**非空但一条都解析不出来** →
 *    整份拒收（Dart `_parseListWithTotalLossGuard`）。部分坏 → 计数，不拒收。
 */
data class CouplePartnerPackage(
    /** 包里的课表名（可能为 null/空白 → 调用方回落「TA的课表」）。 */
    val profileName: String?,
    val courses: List<Course>,
    val settings: TimetableSettings,
    val currentWeek: Long,
    /** 坏条目总数（Dart `AppDataBackup.droppedTotal`）。 */
    val droppedTotal: Int,
)

sealed class CouplePartnerParseResult {
    data class Ok(val pkg: CouplePartnerPackage) : CouplePartnerParseResult()
    data class Failed(val errorCode: String) : CouplePartnerParseResult()
}

object CouplePartnerPackageCodec {

    const val ERR_UNRECOGNIZED = "unrecognized_mikcb_data_file"
    const val ERR_MISSING_SETTINGS = "missing_settings_data"
    const val ERR_REQUIRES_SINGLE_PROFILE = "partner_import_requires_single_profile"

    /** 整机全量备份判定（Dart `DataTransferService.isFullBackupJson` 原样）。 */
    fun isFullBackupJson(json: Map<String, Any?>): Boolean {
        if (json["backupType"] == "full") return true
        return json["packageType"] == TransferEnvelope.PACKAGE_TYPE &&
            json["scope"] == TransferScope.ALL_DATA.value &&
            json["profiles"] is List<*>
    }

    fun parse(content: String): CouplePartnerParseResult {
        val decoded = MiniJson.tryParse(content) ?: return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)
        if (decoded !is Map<*, *>) return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)
        val json = LinkedHashMap<String, Any?>()
        for ((key, value) in decoded) {
            if (key is String) json[key] = value
        }

        val app = json["app"] as? String
        val version = (json["schemaVersion"] as? Number)?.toInt() ?: 0
        if (app != TransferEnvelope.APP_ID || version != TransferEnvelope.SCHEMA_VERSION) {
            return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)
        }
        if (isFullBackupJson(json)) {
            return CouplePartnerParseResult.Failed(ERR_REQUIRES_SINGLE_PROFILE)
        }

        // courses 是唯一「缺失即视为文件不可用」的键（Dart :251-258 的 required=true）。
        if (json["courses"] == null) {
            return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)
        }
        val (courses, droppedCourses) = parseGuarded(json["courses"]) { Course.fromJson(it) }
            ?: return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)
        val (_, droppedTasks) = parseGuarded(json["tasks"]) { CourseTask.fromJson(it) }
            ?: return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)
        val (_, droppedScheduleItems) = parseGuarded(json["scheduleItems"]) { ScheduleItem.fromJson(it) }
            ?: return CouplePartnerParseResult.Failed(ERR_UNRECOGNIZED)

        val rawSettings = json["settings"]
        if (rawSettings !is Map<*, *>) {
            return CouplePartnerParseResult.Failed(ERR_MISSING_SETTINGS)
        }
        val settingsMap = LinkedHashMap<String, Any?>()
        for ((key, value) in rawSettings) {
            if (key is String) settingsMap[key] = value
        }
        val settings = try {
            TimetableSettings.fromJson(settingsMap)
        } catch (_: Exception) {
            // Dart 侧 settings 解析内部逐键容错；真的整份读不出来时按「缺少设置数据」处理，
            // 不把一份没有设置的课表塞给对方。
            return CouplePartnerParseResult.Failed(ERR_MISSING_SETTINGS)
        }

        val currentWeek = (json["currentWeek"] as? Number)?.toLong() ?: 1L
        val profileName = (json["profileName"] as? String)?.trim()?.takeIf { it.isNotEmpty() }

        return CouplePartnerParseResult.Ok(
            CouplePartnerPackage(
                profileName = profileName,
                courses = courses,
                settings = settings,
                currentWeek = currentWeek,
                droppedTotal = droppedCourses + droppedTasks + droppedScheduleItems,
            ),
        )
    }

    /**
     * 组「我的课表」单档包。
     *
     * 判据只在这里一份：**直接调 `buildTransferPackageJson`**，不自己拼键
     * （自己拼 = 给同一件事造第二个来源，迟早和备份格式漂开）。
     */
    fun buildMine(
        profileName: String?,
        courses: List<Course>,
        tasks: List<CourseTask>,
        scheduleItems: List<ScheduleItem>,
        settings: TimetableSettings,
        currentWeek: Int,
        exportedAtIso: String,
        packageId: String,
    ): String {
        val json = buildTransferPackageJson(
            packageId = packageId,
            scope = TransferScope.CURRENT_TIMETABLE,
            exportedAtIso = exportedAtIso,
            profileName = profileName,
            currentWeek = currentWeek,
            settingsJson = settings.toJson(),
            coursesJson = courses.map { it.toJson() },
            tasksJson = tasks.map { it.toJson() },
            scheduleItemsJson = scheduleItems.map { it.toJson() },
        )
        return MiniJson.encode(json)
    }

    /**
     * 列表解析 + 全丢守卫（Dart `_parseListWithTotalLossGuard`）：
     * 非列表 → 空；非空列表但一条都没解析出来 → null（调用方按整份拒收）。
     */
    private fun <T> parseGuarded(
        raw: Any?,
        parse: (Map<String, Any?>) -> T,
    ): Pair<List<T>, Int>? {
        val items = TimetableProfile.parseListLenient(raw) { parse(it) }
        if (raw is List<*> && raw.isNotEmpty()) {
            val dropped = raw.size - items.size
            if (dropped > 0) {
                if (items.isEmpty()) return null
                return items to dropped
            }
        }
        return items to 0
    }
}

/**
 * 组包用的 packageId（Dart `TransferPackage.newPackageId` 同形：
 * `transfer-<微秒时间戳>-<32 位随机数>`）。
 *
 * 随机段不是装饰：同一微秒内连点两次导出会撞号（Dart 那条注释记的就是这个坑）。
 */
fun newCouplePackageId(epochMicros: Long, random32: Int): String =
    "transfer-$epochMicros-${(random32.toLong() and 0xFFFFFFFFL)}"
