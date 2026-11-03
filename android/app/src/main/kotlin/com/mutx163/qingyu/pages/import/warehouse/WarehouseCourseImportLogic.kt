package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseNature
import com.mutx163.qingyu.transfer.MAX_ALLOWED_SEMESTER_WEEK_COUNT

/**
 * 教务适配脚本回传课程数组的**纯解析层**（F32，逐条移植 Dart
 * `lib/domain/warehouse_course_import_logic.dart` 的 `WarehouseCourseImportLogic`）。
 *
 * ## 为什么要有这一层
 *
 * 适配脚本发的是 `saveImportedCourses(json)`，`json` 里每条记录的字段形状由各学校脚本
 * 决定：数字可能是 `1` / `"1"` / `1.0`，布尔可能是 `1` / `"true"`，早读课可能只有
 * `customStartTime` / `customEndTime` 而没有节次。Dart 侧已经踩过两轮坑：
 * 一条脏记录曾让整批导入作废，早读课曾因为缺节次被静默丢掉。本层原样保留这些判据，
 * 保证 Compose 侧接回课程时不会把同样的坑再踩一遍。
 *
 * ## 边界
 *
 * - 只解析，不落盘；写回由 [WarehouseCourseWriteBack] 走仓储原子入口。
 * - 不产文案：`unknownTeacher` / `unknownLocation` 由宿主从 `WarehouseStrings` 传入。
 * - 不生成 id：id 由调用方注入，方便测试钉死。
 */
object WarehouseCourseImportLogic {

    /** 一条记录没能进来的原因（Dart `WarehouseCourseSkipReason`）。 */
    enum class SkipReason {
        /** 既没有可用节次、也没有可用钟点，没法排进课表。 */
        UNUSABLE,

        /** 读取时抛错：字段类型异常、或 map 的键不是字符串。同批其他记录不受影响。 */
        MALFORMED,

        /** 课程进来了，但周次里有非法/越界值被剔除，显示的周次少于实际。 */
        PARTIAL_WEEKS,
    }

    /**
     * 把脚本给的整数收成 [Int]，容忍 JS 实际会产出的形状（`1` / `"1"` / `1.0`）。
     * 一条记录坏掉不许连坐整批（Dart 同名函数的理由）。
     */
    fun coerceInt(raw: Any?): Int? = when (raw) {
        is Int -> raw
        is Long -> raw.toInt()
        is Double -> raw.toInt()
        is Float -> raw.toInt()
        is Number -> raw.toInt()
        is String -> raw.trim().toIntOrNull()
        else -> null
    }

    /** 把脚本给的布尔收成 [Boolean]，容忍 `1` / `"true"`（Dart 同口径）。 */
    fun coerceBool(raw: Any?): Boolean? = when (raw) {
        is Boolean -> raw
        is Number -> raw.toDouble() != 0.0
        is String -> when (raw.trim().lowercase()) {
            "true", "1" -> true
            "false", "0" -> false
            else -> null
        }

        else -> null
    }

    /** 读字符串字段，遇到非字符串不抛错（Dart `coerceText`）。 */
    fun coerceText(raw: Any?): String = raw?.toString()?.trim().orEmpty()

    /**
     * 规范化脚本给的 `HH:mm`，不可用回 null（Dart `normalizeClock`）。
     *
     * 容忍 `H:mm` / `H:m` 与首尾空白，以及 adapter 序列化 `DateTime` 时带的 `:ss`；
     * 越界值直接拒绝——错误钟点比拒绝更危险：拒绝还能回落模板时间，错了会写进课表。
     * 整串锚定，`8:555` / `8:5:30` 不会被悄悄截成别的时刻。
     */
    fun normalizeClock(raw: Any?): String? {
        val text = raw?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return null
        val match = CLOCK_PATTERN.matchEntire(text) ?: return null
        val hour = match.groupValues[1].toIntOrNull() ?: return null
        val minute = match.groupValues[2].toIntOrNull() ?: return null
        if (hour > 23 || minute > 59) return null
        return "${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"
    }

    /** 规范化后的 `HH:mm` 距零点的分钟数；不可用回 null。 */
    fun clockMinutes(normalized: String?): Int? {
        val text = normalized?.trim().orEmpty()
        if (text.isEmpty()) return null
        val match = NORMALIZED_CLOCK_PATTERN.matchEntire(text) ?: return null
        val hour = match.groupValues[1].toIntOrNull() ?: return null
        val minute = match.groupValues[2].toIntOrNull() ?: return null
        if (hour > 23 || minute > 59) return null
        return hour * 60 + minute
    }

    /**
     * 解析脚本回传的课程数组。
     *
     * @param rawCourses JSON 解析后的数组；调用方负责把非数组判成格式错误。
     * @param idFactory 课程 id 生成器（宿主注入 UUID）。
     * @param unknownTeacher / @param unknownLocation 空字段的占位文案（宿主从 ARB 传）。
     * @param onSkip 每条没进来 / 部分丢周次的记录回调。**不许静默丢**：
     *   用户看不到的删减等于数据消失（Dart 同函数的理由）。
     */
    fun parse(
        rawCourses: List<Any?>,
        idFactory: () -> String,
        unknownTeacher: String,
        unknownLocation: String,
        maxWeek: Int = MAX_ALLOWED_SEMESTER_WEEK_COUNT,
        onSkip: ((SkipReason, String?, Throwable?) -> Unit)? = null,
    ): List<Course> {
        val courses = mutableListOf<Course>()
        for (item in rawCourses) {
            if (item !is Map<*, *>) {
                onSkip?.invoke(SkipReason.MALFORMED, null, null)
                continue
            }
            var weeksTrimmed = false
            val parsed = try {
                parseOne(
                    item = item,
                    idFactory = idFactory,
                    unknownTeacher = unknownTeacher,
                    unknownLocation = unknownLocation,
                    maxWeek = maxWeek,
                    onWeeksTrimmed = { weeksTrimmed = true },
                )
            } catch (error: Exception) {
                // 一条坏记录不许让整批导入作废。错误回传出去是为了能记日志：
                // 这个 catch 故意兜住一切，不把 error 传出去的话，真 bug 与脏数据无法区分。
                onSkip?.invoke(SkipReason.MALFORMED, bestEffortName(item), error)
                continue
            }
            if (parsed != null) {
                courses.add(parsed)
                // 只有课真的进来了，「周次被削」才成立；否则会同时报「丢了一门」
                // 与「一门导入成功但少了周次」，后一句是假的。
                if (weeksTrimmed) {
                    onSkip?.invoke(SkipReason.PARTIAL_WEEKS, parsed.name, null)
                }
            } else {
                onSkip?.invoke(SkipReason.UNUSABLE, bestEffortName(item), null)
            }
        }
        return courses
    }

    /** 读记录的 `name`，不依赖强类型 cast——那个 cast 本身就可能抛（Dart 同口径）。 */
    private fun bestEffortName(item: Map<*, *>): String? {
        for ((key, value) in item) {
            if (key == "name") {
                val name = coerceText(value)
                return name.ifEmpty { null }
            }
        }
        return null
    }

    private fun parseOne(
        item: Map<*, *>,
        idFactory: () -> String,
        unknownTeacher: String,
        unknownLocation: String,
        maxWeek: Int,
        onWeeksTrimmed: () -> Unit,
    ): Course? {
        // 对齐 Dart `Map<String, dynamic>.from(item.cast<String, dynamic>())`：
        // 键不是字符串就抛，交给外层报 MALFORMED。
        val map = LinkedHashMap<String, Any?>()
        for ((key, value) in item) {
            if (key !is String) throw IllegalArgumentException("course record has non-string key")
            map[key] = value
        }

        val name = coerceText(map["name"])
        val teacher = coerceText(map["teacher"])
        val location = coerceText(map["position"] ?: map["location"])
        val day = coerceInt(map["day"])
        val startSection = coerceInt(map["startSection"])
        val endSection = coerceInt(map["endSection"])

        val rawWeekList = map["weeks"] as? List<*>
        val inRangeWeeks = rawWeekList
            ?.mapNotNull { coerceInt(it) }
            ?.filter { it > 0 && it <= maxWeek }
        if (rawWeekList != null && inRangeWeeks != null && inRangeWeeks.size < rawWeekList.size) {
            onWeeksTrimmed()
        }
        val weeks = inRangeWeeks?.toSortedSet()?.toList()

        val customStart = normalizeClock(map["customStartTime"])
        val customEnd = normalizeClock(map["customEndTime"])
        val startMinutes = clockMinutes(customStart) ?: 0
        val endMinutes = clockMinutes(customEnd) ?: 0
        val clockRangeUsable = endMinutes > startMinutes
        // `isCustomTime` 缺省时按「是否给出可用钟点对」推断，只有时间的 adapter 也能工作。
        val hasCustomTime =
            (coerceBool(map["isCustomTime"]) ?: (customStart != null && customEnd != null)) &&
                customStart != null &&
                customEnd != null &&
                clockRangeUsable

        // 没有节次但有真实钟点（早读等）：排进第 1 节让记录活下来，显示与提醒靠钟点。
        val effectiveStartSection = startSection ?: if (hasCustomTime) 1 else null
        val effectiveEndSection = endSection ?: effectiveStartSection

        if (name.isEmpty() ||
            day == null ||
            // 越界星期不许夹到相邻一天：JS `Date#getDay()` 周日是 0，夹成周一会让周日
            // 的课从此消失。与 Dart 三处导入口径一致，越界即拒收。
            day < 1 ||
            day > 7 ||
            effectiveStartSection == null ||
            effectiveEndSection == null ||
            weeks.isNullOrEmpty()
        ) {
            return null
        }

        val (start, end) = Course.normalizeSections(effectiveStartSection, effectiveEndSection)
        return Course(
            id = idFactory(),
            name = name,
            teacher = teacher.ifEmpty { unknownTeacher },
            location = location.ifEmpty { unknownLocation },
            dayOfWeek = Course.normalizeDayOfWeek(day),
            startSection = start,
            endSection = end,
            startWeek = weeks.first(),
            endWeek = weeks.last(),
            startTime = if (hasCustomTime) customStart.orEmpty() else "",
            endTime = if (hasCustomTime) customEnd.orEmpty() else "",
            hasCustomTime = hasCustomTime,
            customWeeks = weeks,
            courseNature = CourseNature.fromValue(coerceText(map["courseNature"])),
        )
    }

    private val CLOCK_PATTERN = Regex("""^(\d{1,2}):(\d{1,2})(?::(\d{2}))?$""")
    private val NORMALIZED_CLOCK_PATTERN = Regex("""^(\d{1,2}):(\d{2})$""")
}

/**
 * 上游脚本会下发、但本 App 无处可存的 `saveCourseConfig` 键（F32 顺手项）。
 *
 * * `firstDayOfWeek` —— 周起始日在周计算/统计/考试排期三处硬编码为周一，没有可配置项；
 * * `defaultClassDuration` / `defaultBreakDuration` —— 只在生成时间模板时当入参用，
 *   模型不持久化，存下来就是死状态。
 *
 * 与 Dart `warehouse_course_import_logic.dart` 的同名清单逐字一致；宿主对
 * payload 里值非 null 的这些键记一条执行日志（不静默丢弃，也不给用户摆码）。
 */
val warehouseUnsupportedCourseConfigKeys: List<String> = listOf(
    "firstDayOfWeek",
    "defaultClassDuration",
    "defaultBreakDuration",
)

/** 编辑后的配置值树里实际出现了哪些「收不下」的键（值为 null 视为没下发）。 */
fun warehouseUnsupportedCourseConfigKeysIn(values: Map<*, *>): List<String> =
    warehouseUnsupportedCourseConfigKeys.filter { values[it] != null }

/**
 * 把整份课表的周次按「课表第 1 周 = 校历第 [firstCourseWeek] 周」平移
 * （F32 之前的导入缺这一步：脚本课表若不从校历第 1 周开始，整学期错位）。
 *
 * 逐条对齐 Dart `ImportWeekAlignmentService.shiftCoursesToSemesterWeeks`：
 * - 偏移为 0 原样返回（不复制）；
 * - 自定义周次表：每周 +offset 后重排，start/end 取首尾，单双周标志清掉
 *   （显式周次表下单双周由表自身表达）；
 * - 区间式周次：start/end +offset，**奇数偏移时单双周互换**（1,3,5 平移 1 周变 2,4,6）。
 */
fun warehouseShiftCoursesToFirstWeek(courses: List<Course>, firstCourseWeek: Int): List<Course> {
    val offset = firstCourseWeek - 1
    if (offset == 0) return courses.toList()
    return courses.map { course ->
        val custom = course.normalizedCustomWeeks
        if (custom != null) {
            val shifted = custom.map { it + offset }.sorted()
            course.copy(
                startWeek = shifted.first(),
                endWeek = shifted.last(),
                customWeeks = shifted,
                isOddWeek = false,
                isEvenWeek = false,
            )
        } else {
            course.copy(
                startWeek = course.startWeek + offset,
                endWeek = course.endWeek + offset,
                isOddWeek = if (offset % 2 != 0) course.isEvenWeek else course.isOddWeek,
                isEvenWeek = if (offset % 2 != 0) course.isOddWeek else course.isEvenWeek,
            )
        }
    }
}

/**
 * 课程需要的学期周数（Dart `ImportExportLogic.maxCourseWeek` 的对应物）：
 * 全部课程里最靠后的那一周（自定义周次表取末项，否则取 endWeek），
 * 收进合法上限。写回时现设周数比它小就扩到它（对齐旧版导入的周数自动扩容）。
 */
fun warehouseMaxCourseWeek(courses: List<Course>, fallbackWeekCount: Int): Int {
    if (courses.isEmpty()) {
        return fallbackWeekCount.coerceIn(1, MAX_ALLOWED_SEMESTER_WEEK_COUNT)
    }
    val raw = courses.maxOf { it.normalizedCustomWeeks?.last() ?: it.endWeek }
    return raw.coerceIn(1, MAX_ALLOWED_SEMESTER_WEEK_COUNT)
}
