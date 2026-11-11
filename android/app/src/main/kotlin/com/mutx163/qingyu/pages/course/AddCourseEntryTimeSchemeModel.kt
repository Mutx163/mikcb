package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.course.CourseDomain
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.LocationTimeMatchLogic
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableSettings

/**
 * 单条排课记录「时间模板」行的生效解析（发布版 `add_course_screen.dart:1300-1360`
 * 的 `_resolveEntryTimeScheme` + `clockHint` + 三分支文案）。
 *
 * 发布版口径：
 * - 生效模板按运行期的同一优先级解析：**覆盖 > 地点匹配 > 课表默认**；
 * - 行里显示「保存后真正会用的钟点」——适配脚本钉过时间的课（`hasCustomTime` 且节次未变）
 *   用的是那份权威时间，不是模板铃点，必须经 [CourseDomain.editCourseClock] 算出来；
 * - 「跟随自动」是模式不是模板：行内始终显示**生效模板名**，弹层副题再说明来源
 *   （地点组 / 课表默认）。
 *
 * 这里只做纯计算，不碰 Compose；页面负责把三个 ARB 键拼成最终文案。
 */
enum class AddCourseEntryTimeSchemeSource {
    /** 该条显式指定了模板。 */
    OVERRIDE,

    /** 跟随自动，且被地点分组命中。 */
    LOCATION_GROUP,

    /** 跟随自动，回落课表默认模板。 */
    TIMETABLE,

    /** 跟随自动且解析不到任何模板。 */
    NONE,
}

data class AddCourseEntryTimeSchemeInfo(
    /** 生效模板名（覆盖或解析出的那一个；null = 没解析到）。 */
    val effectiveSchemeName: String?,
    /** 生效模板的节数（0 = 未知 / 解析不到）——节次候选的上界靠它。 */
    val sectionCount: Int,
    /** 「保存后真正会用的钟点」`HH:mm-HH:mm`（节次越界 / 解析不到模板时为 null）。 */
    val clockHint: String?,
    /** 自动模式下生效来源（显式覆盖时为 [AddCourseEntryTimeSchemeSource.OVERRIDE]）。 */
    val autoSource: AddCourseEntryTimeSchemeSource,
    /** 地点分组名（仅 [AddCourseEntryTimeSchemeSource.LOCATION_GROUP]）。 */
    val autoGroupName: String?,
    /** 自动解析出的模板名（副题拼 `地点组 {group} → {scheme}` 用）。 */
    val autoSchemeName: String?,
)

object AddCourseEntryTimeSchemeLogic {

    fun resolve(
        schemes: List<TimeScheme>,
        settings: TimetableSettings,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        timeSchemeIdOverride: String?,
        location: String,
        startSection: Int,
        endSection: Int,
        originalCourse: Course? = null,
    ): AddCourseEntryTimeSchemeInfo {
        val effective = TimeSchemeLogic.resolveCourseTimeScheme(
            schemes = schemes,
            settings = settings,
            course = syntheticCourse(
                location = location,
                startSection = startSection,
                endSection = endSection,
                timeSchemeIdOverride = timeSchemeIdOverride,
            ),
            locationTimeGroups = locationTimeGroups,
        )
        // 自动模式那一路单独解析一次（忽略覆盖），供弹层副题说明来源。
        val autoScheme = if (timeSchemeIdOverride == null) {
            effective
        } else {
            TimeSchemeLogic.resolveCourseTimeScheme(
                schemes = schemes,
                settings = settings,
                course = syntheticCourse(
                    location = location,
                    startSection = startSection,
                    endSection = endSection,
                    timeSchemeIdOverride = null,
                ),
                locationTimeGroups = locationTimeGroups,
            )
        }
        val locationMatch = if (timeSchemeIdOverride == null) {
            LocationTimeMatchLogic.match(location, locationTimeGroups)
        } else {
            null
        }
        val matchedScheme = locationMatch?.let { TimeSchemeLogic.getSchemeById(schemes, it.timeSchemeId) }
        val source = when {
            timeSchemeIdOverride != null -> AddCourseEntryTimeSchemeSource.OVERRIDE
            matchedScheme != null -> AddCourseEntryTimeSchemeSource.LOCATION_GROUP
            autoScheme != null -> AddCourseEntryTimeSchemeSource.TIMETABLE
            else -> AddCourseEntryTimeSchemeSource.NONE
        }
        val sectionCount = effective?.sections?.size ?: 0
        return AddCourseEntryTimeSchemeInfo(
            effectiveSchemeName = effective?.name,
            sectionCount = sectionCount,
            clockHint = clockHintOf(
                scheme = effective,
                startSection = startSection,
                endSection = endSection,
                originalCourse = originalCourse,
            ),
            autoSource = source,
            autoGroupName = locationMatch?.groupName,
            autoSchemeName = autoScheme?.name,
        )
    }

    /** 发布版 `clockHint`：节次在模板范围内才算，越界不给（避免下标崩）。 */
    private fun clockHintOf(
        scheme: TimeScheme?,
        startSection: Int,
        endSection: Int,
        originalCourse: Course?,
    ): String? {
        if (scheme == null) return null
        if (startSection < 1 || endSection > scheme.sections.size) return null
        val clock = CourseDomain.editCourseClock(
            original = originalCourse,
            startSection = startSection,
            endSection = endSection,
            templateStartTime = scheme.sections[startSection - 1].startTime,
            templateEndTime = scheme.sections[endSection - 1].endTime,
        )
        return "${clock.startTime}-${clock.endTime}"
    }

    /** 只为解析构造的临时课（字段与发布版 `_resolveEntryTimeScheme` 的匿名 Course 同口径）。 */
    private fun syntheticCourse(
        location: String,
        startSection: Int,
        endSection: Int,
        timeSchemeIdOverride: String?,
    ): Course = Course(
        id = "entry-probe",
        name = "_",
        teacher = "",
        location = location,
        dayOfWeek = 1,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:00",
        timeSchemeIdOverride = timeSchemeIdOverride,
    )
}
