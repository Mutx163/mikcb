package com.mutx163.qingyu.pages.timetable

/**
 * 节次时间槽模型（对应时间轴的一格）。
 */
data class SectionTimeSlot(
    val section: Int,
    val startTime: String,
    val endTime: String,
) {
    val formattedRange: String
        get() = "$startTime - $endTime"
}

/**
 * 课表周网格几何与度量配置。
 */
data class TimetableGridConfig(
    val totalSections: Int = 12,
    val sectionHeightDp: Float = 64f,
    val timeColumnWidthDp: Float = 32f,
    val headerHeightDp: Float = 48f,
    val visibleDaysCount: Int = 7,
    val showWeekend: Boolean = true,
    val cardHorizontalInsetDp: Float = 2f,
    val cardVerticalInsetDp: Float = 2f,
    val sectionTimeSlots: List<SectionTimeSlot> = TimetableGridMetrics.defaultSectionTimeSlots(totalSections),
)

object TimetableGridMetrics {

    /**
     * 生成默认 12 节次时间配置。
     */
    fun defaultSectionTimeSlots(count: Int = 12): List<SectionTimeSlot> {
        val standardTimes = listOf(
            "08:00" to "08:45",
            "08:55" to "09:40",
            "10:00" to "10:45",
            "10:55" to "11:40",
            "14:00" to "14:45",
            "14:55" to "15:40",
            "16:00" to "16:45",
            "16:55" to "17:40",
            "19:00" to "19:45",
            "19:55" to "20:40",
            "20:50" to "21:35",
            "21:45" to "22:30",
        )

        return (1..count).map { section ->
            val pair = if (section <= standardTimes.size) {
                standardTimes[section - 1]
            } else {
                // 超出预设范围时兜底生成递增时间
                val startHour = (8 + (section - 1)).coerceAtMost(23)
                String.format("%02d:00", startHour) to String.format("%02d:45", startHour)
            }
            SectionTimeSlot(
                section = section,
                startTime = pair.first,
                endTime = pair.second,
            )
        }
    }

    /**
     * 计算网格总高度（表头 + 所有节次总高）。
     */
    fun calculateTotalHeight(config: TimetableGridConfig): Float {
        return config.headerHeightDp + (config.totalSections * config.sectionHeightDp)
    }

    /**
     * 计算日列单列宽度。
     */
    fun calculateDayColumnWidth(availableWidthDp: Float, config: TimetableGridConfig): Float {
        val usableWidth = (availableWidthDp - config.timeColumnWidthDp).coerceAtLeast(0f)
        return usableWidth / config.visibleDaysCount.coerceAtLeast(1)
    }

    /**
     * 计算指定节次距离网格内容区顶部的 Y 轴偏移（不含表头）。
     */
    fun calculateSectionTop(section: Int, config: TimetableGridConfig): Float {
        return (section - 1).coerceAtLeast(0) * config.sectionHeightDp
    }

    /**
     * 计算指定跨度节次的理论总高度。
     */
    fun calculateSectionHeight(startSection: Int, endSection: Int, config: TimetableGridConfig): Float {
        val span = (endSection - startSection + 1).coerceAtLeast(1)
        return span * config.sectionHeightDp
    }

    /**
     * 计算重叠分列卡片在日列内部的 X 轴相对偏移（含内边距）。
     */
    fun calculateCardX(
        colIndex: Int,
        totalCols: Int,
        dayColumnWidth: Float,
        config: TimetableGridConfig,
    ): Float {
        val usableWidth = (dayColumnWidth - 2 * config.cardHorizontalInsetDp).coerceAtLeast(0f)
        val trackWidth = usableWidth / totalCols.coerceAtLeast(1)
        return config.cardHorizontalInsetDp + (colIndex.coerceIn(0, totalCols - 1) * trackWidth)
    }

    /**
     * 计算重叠分列卡片的宽度（扣除内边距与轨道切分）。
     */
    fun calculateCardWidth(
        totalCols: Int,
        dayColumnWidth: Float,
        config: TimetableGridConfig,
    ): Float {
        val usableWidth = (dayColumnWidth - 2 * config.cardHorizontalInsetDp).coerceAtLeast(0f)
        return usableWidth / totalCols.coerceAtLeast(1)
    }

    /**
     * 计算卡片实际放置的顶部 Y 轴坐标（含垂直内边距）。
     */
    fun calculateCardTop(startSection: Int, config: TimetableGridConfig): Float {
        return calculateSectionTop(startSection, config) + config.cardVerticalInsetDp
    }

    /**
     * 计算卡片实际放置的高度（扣除垂直内边距）。
     */
    fun calculateCardHeight(
        startSection: Int,
        endSection: Int,
        config: TimetableGridConfig,
    ): Float {
        val rawHeight = calculateSectionHeight(startSection, endSection, config)
        return (rawHeight - 2 * config.cardVerticalInsetDp).coerceAtLeast(1f)
    }

    /**
     * 将点击/手势的 Y 坐标反解为节次（1-based）。
     */
    fun sectionAtOffset(offsetYDp: Float, config: TimetableGridConfig): Int {
        val clampedY = offsetYDp.coerceAtLeast(0f)
        val section = (clampedY / config.sectionHeightDp).toInt() + 1
        return section.coerceIn(1, config.totalSections)
    }

    /**
     * 将点击/手势的 X 坐标反解为星期几（1-based，1..visibleDaysCount；若落在时间轴返回 -1）。
     */
    fun dayOfWeekAtOffset(
        offsetXDp: Float,
        availableWidthDp: Float,
        config: TimetableGridConfig,
    ): Int {
        if (offsetXDp < config.timeColumnWidthDp) return -1
        val xInDays = offsetXDp - config.timeColumnWidthDp
        val dayWidth = calculateDayColumnWidth(availableWidthDp, config)
        if (dayWidth <= 0f) return 1
        val day = (xInDays / dayWidth).toInt() + 1
        return day.coerceIn(1, config.visibleDaysCount)
    }
}
