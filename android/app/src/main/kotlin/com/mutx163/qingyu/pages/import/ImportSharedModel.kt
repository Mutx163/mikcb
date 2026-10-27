package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.WeekCalculator
import java.time.LocalDateTime
import kotlin.random.Random

/**
 * 导入共享逻辑纯函数（P3-G1 · 移植 `lib/screens/import/import_shared.dart` 里
 * **不依赖 BuildContext/Provider 的那部分**；配色、周次对齐、节次解码、
 * 结果文案与格式化）。
 *
 * 偏好读取（随机配色开关）、对话框、Toast、Overlay 属应用/渲染层职责，
 * 不在本层——模型只收已经读好的布尔值/参数。
 */
object ImportSharedModel {

    // ------------------------------------------------------------------
    // 随机配色：覆盖还是保留本地颜色
    // ------------------------------------------------------------------

    /**
     * 颜色更新只在**覆盖导入**时生效：覆盖 + 随机色开启才让导入色盖掉本地色。
     * 更新/下拉快捷导入一律保留本地颜色——随机色此时只落到本地没有的新课上。
     */
    fun shouldOverrideLocalColorsOnImport(replaceExisting: Boolean, randomColorsEnabled: Boolean): Boolean =
        replaceExisting && randomColorsEnabled

    /** 是否保留与本地已有行匹配课程的颜色（与 override 互为补集）。 */
    fun shouldPreserveLocalColorsOnImport(replaceExisting: Boolean, randomColorsEnabled: Boolean): Boolean =
        !shouldOverrideLocalColorsOnImport(replaceExisting, randomColorsEnabled)

    // ------------------------------------------------------------------
    // 格式化
    // ------------------------------------------------------------------

    /** `yyyy-MM-dd`（补零），用于学期开始日期等展示。 */
    fun importFormatDate(date: LocalDateTime): String =
        "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)

    /** 星期短名（一~日）；越界回数字（Dart switch default 语义）。 */
    fun importWeekdayLabel(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> ImportStrings.weekdayShortMonday.zh
        2 -> ImportStrings.weekdayShortTuesday.zh
        3 -> ImportStrings.weekdayShortWednesday.zh
        4 -> ImportStrings.weekdayShortThursday.zh
        5 -> ImportStrings.weekdayShortFriday.zh
        6 -> ImportStrings.weekdayShortSaturday.zh
        7 -> ImportStrings.weekdayShortSunday.zh
        else -> dayOfWeek.toString()
    }

    /** 字节预算的可读形态：`20 MB` / `2 KB` / `512 B`（四舍五入到整数）。 */
    fun formatByteBudget(bytes: Long): String {
        if (bytes >= 1024 * 1024) {
            return "${Math.round(bytes.toDouble() / (1024 * 1024))} MB"
        }
        if (bytes >= 1024) {
            return "${Math.round(bytes.toDouble() / 1024)} KB"
        }
        return "$bytes B"
    }

    /**
     * 导入预览里一门课的周次摘要：空周次回「未提供」；≤6 周逐个列出；
     * 超长折成 `first-last · 总数`（周次列表在 Course.normalizeWeekList 里已升序，
     * first/last 就是范围两端）。
     */
    fun importPreviewWeekSummary(
        weeks: List<Int>,
        weekListSeparator: String,
        weekNotProvidedLabel: String,
        weeksCountLabel: (Int) -> String,
    ): String {
        if (weeks.isEmpty()) {
            return weekNotProvidedLabel
        }
        if (weeks.size <= 6) {
            return weeks.joinToString(weekListSeparator)
        }
        return "${weeks.first()}-${weeks.last()} · ${weeksCountLabel(weeks.size)}"
    }

    // ------------------------------------------------------------------
    // 节次 JSON 按位对齐解码
    // ------------------------------------------------------------------

    /**
     * 教务页下发的节次 JSON → **按位对齐**的节次表；`null` 表示没有可用节次。
     *
     * 坏位留空（作息页渲染成 `-`）而不是跳过——跳过会让一条坏记录把它之后
     * 每一节的时间整体前移一档（`Course.startSection` 是这张表的位置下标）。
     * 整表皆坏（healedCount == size）也返回 null。
     */
    fun decodeAlignedImportedSections(decoded: Any?): List<SectionTime>? {
        if (decoded !is List<*>) {
            return null
        }
        val (sections, healedCount) = SectionTime.parseListAligned(decoded) { emptyList() }
        if (sections.isEmpty() || healedCount == sections.size) {
            return null
        }
        return sections
    }

    // ------------------------------------------------------------------
    // 导入结果 Toast 文案
    // ------------------------------------------------------------------

    /** 构建导入完成后的提示文案（含警告后缀）。 */
    fun buildImportResultMessage(
        importedCount: Int,
        replaceExisting: Boolean,
        warningCount: Int = 0,
    ): String {
        val warningSuffix = if (warningCount == 0) {
            ""
        } else {
            ImportStrings.aiWarningExtraSuffix.filled("count", warningCount.toString())
        }
        if (importedCount > 0) {
            return (if (replaceExisting) {
                ImportStrings.importOverwriteCount.filled("count", importedCount.toString())
            } else {
                ImportStrings.importUpdatedCount.filled("count", importedCount.toString())
            }) + warningSuffix
        }
        return ImportStrings.importNoCourseChanges.zh + warningSuffix
    }

    // ------------------------------------------------------------------
    // 随机取色
    // ------------------------------------------------------------------

    /** 预设课程色板（与 Dart `kPresetCourseColorHexes` 逐字一致）。 */
    val PRESET_COURSE_COLOR_HEXES: List<String> = listOf(
        // 红 red
        "#FCA5A5", "#F87171", "#EF4444", "#DC2626", "#B91C1C",
        // 橙红（含原深橙）orange
        "#FF5722", "#FDBA74", "#FB923C", "#F97316", "#EA580C", "#C2410C",
        // 琥珀（含原橙）amber
        "#FCD34D", "#FBBF24", "#F59E0B", "#FF9800", "#D97706", "#B45309",
        // 黄 yellow
        "#FDE047", "#FACC15", "#EAB308", "#CA8A04", "#A16207",
        // 青柠 lime
        "#BEF264", "#A3E635", "#84CC16", "#65A30D", "#4D7C0F",
        // 绿（含原绿）green
        "#86EFAC", "#4ADE80", "#4CAF50", "#22C55E", "#16A34A", "#15803D",
        // 翠绿 emerald
        "#6EE7B7", "#34D399", "#10B981", "#059669", "#047857",
        // 青绿 teal
        "#5EEAD4", "#2DD4BF", "#14B8A6", "#0D9488", "#0F766E",
        // 青（含原青）cyan
        "#67E8F9", "#22D3EE", "#06B6D4", "#00BCD4", "#0891B2", "#0E7490",
        // 天蓝 sky
        "#7DD3FC", "#38BDF8", "#0EA5E9", "#0284C7", "#0369A1",
        // 蓝（含原默认蓝）blue
        "#93C5FD", "#60A5FA", "#2196F3", "#3B82F6", "#2563EB", "#1D4ED8",
        // 靛蓝 indigo
        "#A5B4FC", "#818CF8", "#6366F1", "#4F46E5", "#4338CA",
        // 紫罗兰 violet
        "#C4B5FD", "#A78BFA", "#8B5CF6", "#7C3AED", "#6D28D9",
        // 紫（含原紫）purple
        "#D8B4FE", "#C084FC", "#A855F7", "#9333EA", "#9C27B0", "#7E22CE",
        // 品红 fuchsia
        "#F0ABFC", "#E879F9", "#D946EF", "#C026D3", "#A21CAF",
        // 粉（含原粉）pink
        "#F9A8D4", "#F472B6", "#EC4899", "#E91E63", "#DB2777", "#BE185D",
        // 玫红 rose
        "#FDA4AF", "#FB7185", "#F43F5E", "#E11D48", "#BE123C",
        // 蓝灰（含原蓝灰）slate
        "#CBD5E1", "#94A3B8", "#607D8B", "#64748B", "#475569", "#334155",
        // 棕灰（含原棕）stone
        "#D6D3D1", "#A8A29E", "#78716C", "#795548", "#57534E", "#44403C",
    )

    /** 选色行的横向快选色（与 Dart `kCourseColorQuickPickHexes` 逐字一致）。 */
    val COURSE_COLOR_QUICK_PICK_HEXES: List<String> = listOf(
        "#2196F3", "#EF4444", "#F97316", "#F59E0B", "#FACC15",
        "#84CC16", "#22C55E", "#10B981", "#14B8A6", "#06B6D4",
        "#0EA5E9", "#6366F1", "#8B5CF6", "#A855F7", "#D946EF",
        "#EC4899", "#F43F5E", "#64748B", "#78716C",
    )

    /** 「全部颜色」颜色组的保留 id。 */
    const val COURSE_COLOR_GROUP_ALL_ID = "all"

    /** 预设颜色组：id → 色值（显示名在 ImportStrings 的 colorGroup* 键）。 */
    val COURSE_COLOR_GROUPS: List<Pair<String, List<String>>> = listOf(
        "pastel" to listOf(
            "#FCA5A5", "#FDBA74", "#FCD34D", "#FDE047", "#BEF264",
            "#86EFAC", "#6EE7B7", "#5EEAD4", "#67E8F9", "#7DD3FC",
            "#93C5FD", "#A5B4FC", "#C4B5FD", "#D8B4FE", "#F0ABFC",
            "#F9A8D4", "#FDA4AF", "#CBD5E1", "#D6D3D1",
        ),
        "vibrant" to listOf(
            "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#84CC16",
            "#22C55E", "#10B981", "#14B8A6", "#06B6D4", "#0EA5E9",
            "#3B82F6", "#6366F1", "#8B5CF6", "#A855F7", "#D946EF",
            "#EC4899", "#F43F5E", "#64748B", "#78716C",
        ),
        "deep" to listOf(
            "#B91C1C", "#C2410C", "#B45309", "#A16207", "#4D7C0F",
            "#15803D", "#047857", "#0F766E", "#0E7490", "#0369A1",
            "#1D4ED8", "#4338CA", "#6D28D9", "#7E22CE", "#A21CAF",
            "#BE185D", "#BE123C", "#334155", "#44403C",
        ),
        "dopamine" to listOf(
            "#F87171", "#FB923C", "#FBBF24", "#FACC15", "#A3E635",
            "#4ADE80", "#34D399", "#2DD4BF", "#22D3EE", "#38BDF8",
            "#60A5FA", "#818CF8", "#A78BFA", "#A855F7", "#D946EF",
            "#EC4899", "#F43F5E",
        ),
        "sunset" to listOf(
            "#FACC15", "#FBBF24", "#F59E0B", "#FF9800", "#FB923C",
            "#F97316", "#EA580C", "#FF5722", "#F87171", "#EF4444",
            "#FB7185", "#F43F5E", "#F472B6", "#EC4899", "#E91E63",
            "#C084FC", "#A855F7",
        ),
        "ocean" to listOf(
            "#34D399", "#10B981", "#059669", "#2DD4BF", "#14B8A6",
            "#0D9488", "#22D3EE", "#06B6D4", "#0891B2", "#38BDF8",
            "#0EA5E9", "#0284C7", "#60A5FA", "#3B82F6", "#2563EB",
            "#818CF8", "#6366F1",
        ),
    )

    /** 解析随机取色色板：'all' 与未知 id（历史残留值）都兜底回全量色板。 */
    fun courseColorGroupPalette(groupId: String): List<String> {
        if (groupId != COURSE_COLOR_GROUP_ALL_ID) {
            for ((id, hexes) in COURSE_COLOR_GROUPS) {
                if (id == groupId) return hexes
            }
        }
        return PRESET_COURSE_COLOR_HEXES
    }

    /** 颜色组显示名（预设组沿用配色风格标签，「全部颜色」为全量色板）。 */
    fun colorGroupDisplayName(groupId: String): String = when (groupId) {
        "pastel" -> ImportStrings.colorGroupPastel.zh
        "vibrant" -> ImportStrings.colorGroupVibrant.zh
        "deep" -> ImportStrings.colorGroupDeep.zh
        "dopamine" -> ImportStrings.colorGroupDopamine.zh
        "sunset" -> ImportStrings.colorGroupSunset.zh
        "ocean" -> ImportStrings.colorGroupOcean.zh
        else -> ImportStrings.colorGroupAll.zh
    }

    /**
     * 给导入课程分配预设色：同名同教师共享一色，不同组轮转打乱后的色板。
     * [groupKeyBuilder] 覆盖分组键（如导入后重配色的「同名同色」不变式）。
     */
    fun applyRandomImportCourseColors(
        courses: List<Course>,
        palette: List<String> = PRESET_COURSE_COLOR_HEXES,
        assignMatchingTextColor: Boolean = false,
        random: Random = Random.Default,
        groupKeyBuilder: ((Course) -> String)? = null,
    ): List<Course> {
        if (courses.isEmpty() || palette.isEmpty()) {
            return courses.toList()
        }

        val resolveGroupKey = groupKeyBuilder ?: { course ->
            buildImportCourseColorGroupKey(name = course.name, teacher = course.teacher)
        }
        val shuffledPalette = palette.shuffled(random)

        val groupColorByKey = HashMap<String, String>()
        var nextGroupIndex = 0

        return courses.map { course ->
            val groupKey = resolveGroupKey(course)
            val assignedColor = groupColorByKey.getOrPut(groupKey) {
                val colorHex = shuffledPalette[nextGroupIndex % shuffledPalette.size]
                nextGroupIndex += 1
                colorHex
            }
            course.copy(
                color = assignedColor,
                textColor = if (assignMatchingTextColor) {
                    matchingCourseTextColorHex(assignedColor)
                } else {
                    null
                },
            )
        }
    }

    /** 分组键：名字 + `\u0000` + 教师（各段做空白归一）。 */
    fun buildImportCourseColorGroupKey(name: String, teacher: String): String =
        "${normalizeImportColorKeyPart(name)}\u0000${normalizeImportColorKeyPart(teacher)}"

    private fun normalizeImportColorKeyPart(value: String): String =
        value.trim().replace(Regex("""\s+"""), " ")

    /**
     * 按感知亮度（ITU-R BT.601）为背景色挑可读墨色：亮底深墨、暗底白墨。
     */
    fun matchingCourseTextColorHex(backgroundHex: String): String {
        val hex = backgroundHex.replace("#", "").trim()
        if (hex.length < 6) {
            return "#FFFFFF"
        }
        val r = hex.substring(0, 2).toIntOrNull(16) ?: 0
        val g = hex.substring(2, 4).toIntOrNull(16) ?: 0
        val b = hex.substring(4, 6).toIntOrNull(16) ?: 0
        val luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return if (luminance > 0.6) "#1F1F1F" else "#FFFFFF"
    }
}

/**
 * 学期周次对齐（移植 `lib/services/import_week_alignment_service.dart`）：
 * ICS 导入把「文件里最早的上课日期」对齐到用户确认的校历第 N 周。
 */
object ImportWeekAlignment {

    /**
     * 按日历日推算首课所在的校历周次；早于开学日回 1。
     * 用日历日而不是绝对经过时间：夏令时那一周本地时差会让 7 天算成 6 天。
     */
    fun inferFirstCourseWeek(semesterStartDate: LocalDateTime, firstCourseDate: LocalDateTime): Int {
        val days = WeekCalculator.daysBetween(
            WeekCalculator.startOfWeek(semesterStartDate),
            WeekCalculator.startOfWeek(firstCourseDate),
        )
        if (days <= 0) {
            return 1
        }
        return (days / 7).toInt() + 1
    }

    /** 把课程周次整体顺延 [firstCourseWeek] - 1 周；0 偏移原样返回。 */
    fun shiftCoursesToSemesterWeeks(courses: List<Course>, firstCourseWeek: Int): List<Course> {
        val weekOffset = firstCourseWeek - 1
        if (weekOffset == 0) {
            return courses.toList()
        }
        return courses.map { shiftCourse(it, weekOffset) }
    }

    private fun shiftCourse(course: Course, weekOffset: Int): Course {
        val customWeeks = course.normalizedCustomWeeks
        if (customWeeks != null) {
            val shiftedWeeks = customWeeks.map { it + weekOffset }.sorted()
            return course.copy(
                startWeek = shiftedWeeks.first(),
                endWeek = shiftedWeeks.last(),
                customWeeks = shiftedWeeks,
                isOddWeek = false,
                isEvenWeek = false,
            )
        }

        // 奇数偏移翻转单双周标志
        val flipParity = weekOffset % 2 != 0
        return course.copy(
            startWeek = course.startWeek + weekOffset,
            endWeek = course.endWeek + weekOffset,
            isOddWeek = if (flipParity) course.isEvenWeek else course.isOddWeek,
            isEvenWeek = if (flipParity) course.isOddWeek else course.isEvenWeek,
        )
    }
}
