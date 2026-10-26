package com.mutx163.qingyu.share

import com.mutx163.qingyu.core.MiniJson
import java.time.DayOfWeek
import java.time.LocalDate
import kotlin.random.Random

/**
 * 传输包用户可见边界（移植自 lib/services/transfer_package.dart 的
 * `TransferScope` / `TransferChannel` / `TransferApplyMode` 与
 * lib/services/unified_transfer_service.dart 的纯逻辑部分）。
 *
 * 传输实现必须携带 scope，而不是从载荷内容推断（Dart 原文）。
 * 完整包体编解码（各模型 fromJson/toJson + 唯一 id 校验）归数据传输服务，
 * 不在本泳道（只做协议/拼包/校验中的信封层）。
 */
enum class TransferScope(val value: String) {
    CURRENT_TIMETABLE("current_timetable"),
    SELECTED_COURSES("selected_courses"),
    ALL_DATA("all_data"),
    WEEK_TIMETABLE("week_timetable"),
    SELECTED_COURSE("selected_course"),
    TIME_TEMPLATE("time_template");

    companion object {
        /** 未知 scope 直接拒（Dart `transfer_scope_invalid`）。 */
        fun fromValue(raw: Any?): TransferScope {
            val value = raw?.toString()?.trim()
            return entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("transfer_scope_invalid")
        }
    }
}

/** scope 语义（Dart `TransferScopeSemantics` 原样移植）。 */
val TransferScope.overwriteUsesMergeSemantics: Boolean
    get() = when (this) {
        TransferScope.SELECTED_COURSES,
        TransferScope.SELECTED_COURSE,
        TransferScope.WEEK_TIMETABLE,
        TransferScope.TIME_TEMPLATE,
        -> true
        TransferScope.CURRENT_TIMETABLE, TransferScope.ALL_DATA -> false
    }

/** 只有整表传输允许携带设置；局部课程/周传输不得静默改设备级偏好。 */
val TransferScope.carriesSettings: Boolean
    get() = this == TransferScope.CURRENT_TIMETABLE || this == TransferScope.ALL_DATA

/**
 * 产生/消费包的路径标识：只是元信息，不是授权边界，
 * 所有路径仍需同样的预览确认（Dart 原文）。
 */
enum class TransferChannel(val value: String) {
    FILE("file"),
    QR("qr"),
    LAN("lan"),
    CLOUD("cloud");

    companion object {
        /**
         * 未知 channel 回落到 file（Dart `TransferChannelX.fromValue` 原样：
         * 大小写不敏感，trim 后匹配）。
         */
        fun fromValue(raw: Any?): TransferChannel {
            val value = raw?.toString()?.trim()?.lowercase()
            return entries.firstOrNull { it.value == value } ?: FILE
        }
    }
}

enum class TransferApplyMode { MERGE, OVERWRITE }

/** 传输包信封常量（Dart `TransferPackage.appId/packageType/schemaVersion`）。 */
object TransferEnvelope {
    const val APP_ID = "mikcb"
    const val PACKAGE_TYPE = "transfer"
    const val SCHEMA_VERSION = 1

    /**
     * 当前信封探测（Dart `UnifiedTransferService._isTransferEnvelope` 原样）。
     * 失败闭合：信封成立但版本/结构非法时，调用方不得退回 legacy 读取。
     */
    fun isTransferEnvelopeJson(content: String): Boolean {
        return try {
            val decoded = MiniJson.tryParse(content)
            decoded is Map<*, *> &&
                decoded["app"] == APP_ID &&
                decoded["packageType"] == PACKAGE_TYPE
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 新包 id（Dart `TransferPackage.newPackageId` 原样）：
     * 纯微秒时间戳会撞号（同微秒连发/测试传固定 now/部分平台时钟粒度粗），
     * 撤销槽按 id 消费，撞号会拿错撤销点，故补一段随机后缀。
     * Dart 盐为 `nextInt(1 << 32)`（0 ~ 2^32-1），此处同口径。
     */
    fun newPackageId(
        nowMicros: Long = System.currentTimeMillis() * 1000L,
        salt: Long = Random.nextLong(1L shl 32),
    ): String = "transfer-$nowMicros-$salt"
}

/**
 * 局部传输的时间窗口（移植自 unified_transfer_service.dart 的
 * `_TransferScopeWindow`，日期用 [LocalDate] 表达 Dart 的"日历日"语义）。
 *
 * 学期起点按周一归一（与 WeekCalculator.startOfWeek 同口径：周一为周起始）；
 * 学期未配置时退回 [fallbackWeekStart] 所在自然周。
 */
class TransferScopeWindow(
    val weeks: Set<Int>,
    val semesterStartWeek: LocalDate?,
    val fallbackWeekStart: LocalDate,
) {
    val isEmpty: Boolean get() = weeks.isEmpty()

    fun startDate(): LocalDate {
        if (semesterStartWeek == null || weeks.isEmpty()) return fallbackWeekStart
        return semesterStartWeek.plusDays(((weeks.min() - 1) * 7).toLong())
    }

    fun endDate(): LocalDate {
        if (semesterStartWeek == null || weeks.isEmpty()) {
            return fallbackWeekStart.plusDays(6)
        }
        return semesterStartWeek.plusDays((weeks.max() * 7 - 1).toLong())
    }

    fun containsDate(value: LocalDate): Boolean {
        if (isEmpty) return false
        val semesterWeek = semesterStartWeek
        if (semesterWeek == null) {
            val lastDate = fallbackWeekStart.plusDays(6)
            return !value.isBefore(fallbackWeekStart) && !value.isAfter(lastDate)
        }
        val aligned = value.with(DayOfWeek.MONDAY)
        val diffDays = java.time.temporal.ChronoUnit.DAYS.between(semesterWeek, aligned)
        if (diffDays < 0) return false
        return weeks.contains((diffDays / 7 + 1).toInt())
    }

    fun overlapsDateRange(start: LocalDate, end: LocalDate): Boolean {
        if (isEmpty) return false
        if (end.isBefore(start)) return false
        val semesterWeek = semesterStartWeek
        if (semesterWeek == null) {
            val windowEnd = fallbackWeekStart.plusDays(6)
            return !end.isBefore(fallbackWeekStart) && !start.isAfter(windowEnd)
        }
        for (week in weeks) {
            val weekStart = semesterWeek.plusDays(((week - 1) * 7).toLong())
            val weekEnd = weekStart.plusDays(6)
            if (!end.isBefore(weekStart) && !start.isAfter(weekEnd)) return true
        }
        return false
    }

    companion object {
        fun empty(fallbackWeekStart: LocalDate): TransferScopeWindow =
            TransferScopeWindow(emptySet(), null, fallbackWeekStart)
    }
}
