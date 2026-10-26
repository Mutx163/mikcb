package com.mutx163.qingyu.core

import java.time.LocalDateTime

/**
 * 时间模板查询与课程钟点同步（移植自 lib/domain/time_scheme_logic.dart，
 * 纯函数，无 Provider 状态）。
 *
 * resolveCourseTimeScheme 的优先级（time_scheme_logic.dart:97-133）：
 * 1. 课程手动覆盖 [Course.timeSchemeIdOverride]
 * 2. 地点关键词匹配 → group.timeSchemeId（作息存在时）
 * 3. 档案默认 [TimetableSettings.activeTimeSchemeId]
 *
 * 季节日期规则**不**在这里做软覆盖：它们只在规则生效日的首次打开批量套用
 * 默认作息（provider 侧职责），所以 [ScheduleDateRule] 参数在此仅保持签名兼容、
 * 参与删除阻塞收集（collectDeleteBlockers）而不参与 resolve。
 */

/** 课程对某个作息的引用（time_scheme_logic.dart:13-28）。 */
data class TimeSchemeCourseUsageReference(
    val profileName: String,
    val course: Course,
    val usesOverride: Boolean,
    /** 无手动覆盖、经地点关键词组路由到该作息时为 true。 */
    val usesLocationMatch: Boolean = false,
)

/** 阻止删除某作息的全部引用（time_scheme_logic.dart:38-72）。 */
data class TimeSchemeDeleteBlockers(
    /** 以该作息为档案默认（主作息）的档案名。 */
    val profileNames: List<String> = emptyList(),
    /** 手动覆盖绑定该作息的课程数。 */
    val overrideCourseCount: Int = 0,
    /** 经地点分组路由到该作息的课程数。 */
    val locationCourseCount: Int = 0,
    /** 绑定该作息的地点分组名（停用的也算——重新启用会复活该作息）。 */
    val locationGroupNames: List<String> = emptyList(),
    /** 切换档案默认作息到该作息的日期规则名。 */
    val dateRuleNames: List<String> = emptyList(),
) {
    val totalCourseCount: Int get() = overrideCourseCount + locationCourseCount

    val isEmpty: Boolean
        get() = profileNames.isEmpty() && totalCourseCount == 0 &&
            locationGroupNames.isEmpty() && dateRuleNames.isEmpty()

    val isNotEmpty: Boolean get() = !isEmpty
}

/** 日期规则模型（移植自 lib/models/schedule_date_rule.dart；本族只需要字段）。 */
data class ScheduleDateRule(
    val id: String,
    val name: String,
    val timeSchemeId: String,
    /** 含头含尾，`yyyy-MM-dd`（本地日历日）。 */
    val startDate: String,
    val endDate: String,
    val enabled: Boolean = true,
) {
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "id" to id,
        "name" to name,
        "timeSchemeId" to timeSchemeId,
        "enabled" to enabled,
        "startDate" to startDate,
        "endDate" to endDate,
    )

    companion object {
        fun fromJson(json: Map<String, Any?>): ScheduleDateRule {
            val rawStartDate = json["startDate"]
            val rawEndDate = json["endDate"]
            if (rawStartDate !is String || rawStartDate.trim().isEmpty()) {
                throw DartFormatException("missing schedule date rule start date")
            }
            if (rawEndDate !is String || rawEndDate.trim().isEmpty()) {
                throw DartFormatException("missing schedule date rule end date")
            }
            return ScheduleDateRule(
                id = json["id"] as? String ?: "",
                name = (json["name"] as? String ?: "").trim(),
                timeSchemeId = json["timeSchemeId"] as? String ?: "",
                enabled = json["enabled"] as? Boolean ?: true,
                startDate = rawStartDate.trim(),
                endDate = rawEndDate.trim(),
            )
        }
    }
}

/** 节次表规范签名：判断「设置已等于该模板」时按值比较用（:90-95）。 */
fun sectionsSignature(sections: List<SectionTime>): String =
    MiniJson.encode(sections.map { it.toJson() })

object TimeSchemeLogic {

    /** 按 id 找作息；null id 或找不到 → null（:78-88）。 */
    fun getSchemeById(schemes: List<TimeScheme>, schemeId: String?): TimeScheme? {
        if (schemeId == null) return null
        for (scheme in schemes) {
            if (scheme.id == schemeId) return scheme
        }
        return null
    }

    /** 见文件头注释的优先级（:106-133）。settingsOverride 优先于 settings。 */
    fun resolveCourseTimeScheme(
        schemes: List<TimeScheme>,
        settings: TimetableSettings,
        course: Course,
        settingsOverride: TimetableSettings? = null,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
        onDate: LocalDateTime? = null,
    ): TimeScheme? {
        val effectiveSettings = settingsOverride ?: settings
        val overrideScheme = getSchemeById(schemes, course.timeSchemeIdOverride)
        if (overrideScheme != null) return overrideScheme

        val locationMatch = LocationTimeMatchLogic.match(course.location, locationTimeGroups)
        if (locationMatch != null) {
            val locationScheme = getSchemeById(schemes, locationMatch.timeSchemeId)
            if (locationScheme != null) return locationScheme
        }

        return getSchemeById(schemes, effectiveSettings.activeTimeSchemeId)
    }

    /** 收集课程对某作息的引用（:135-197）。 */
    fun getCourseUsages(
        profiles: List<TimetableProfile>,
        schemeId: String,
        profilesOverride: List<TimetableProfile>? = null,
        schemes: List<TimeScheme> = emptyList(),
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
    ): List<TimeSchemeCourseUsageReference> {
        val sourceProfiles = profilesOverride ?: profiles
        val usages = mutableListOf<TimeSchemeCourseUsageReference>()

        for (profile in sourceProfiles) {
            for (course in profile.courses) {
                if (course.timeSchemeIdOverride != null) {
                    if (course.timeSchemeIdOverride == schemeId) {
                        usages.add(
                            TimeSchemeCourseUsageReference(
                                profileName = profile.name,
                                course = course,
                                usesOverride = true,
                            ),
                        )
                    }
                    continue
                }

                val locationMatch = LocationTimeMatchLogic.match(course.location, locationTimeGroups)
                if (locationMatch != null) {
                    val locationScheme = getSchemeById(schemes, locationMatch.timeSchemeId)
                    if (locationScheme != null) {
                        if (locationMatch.timeSchemeId == schemeId) {
                            usages.add(
                                TimeSchemeCourseUsageReference(
                                    profileName = profile.name,
                                    course = course,
                                    usesOverride = false,
                                    usesLocationMatch = true,
                                ),
                            )
                        }
                        continue
                    }
                }

                if (profile.settings.activeTimeSchemeId == schemeId) {
                    usages.add(
                        TimeSchemeCourseUsageReference(
                            profileName = profile.name,
                            course = course,
                            usesOverride = false,
                        ),
                    )
                }
            }
        }
        return usages
    }

    /** 引用课程里的最大 endSection；无引用 → 0（:199-219）。 */
    fun maxUsedSection(
        profiles: List<TimetableProfile>,
        schemeId: String,
        profilesOverride: List<TimetableProfile>? = null,
        schemes: List<TimeScheme> = emptyList(),
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
    ): Int {
        val usages = getCourseUsages(profiles, schemeId, profilesOverride, schemes, locationTimeGroups)
        if (usages.isEmpty()) return 0
        return usages.maxOf { it.course.endSection }
    }

    /** endSection 最大的那条引用；无引用 → null（:221-243）。 */
    fun maxSectionUsage(
        profiles: List<TimetableProfile>,
        schemeId: String,
        profilesOverride: List<TimetableProfile>? = null,
        schemes: List<TimeScheme> = emptyList(),
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
    ): TimeSchemeCourseUsageReference? {
        val usages = getCourseUsages(profiles, schemeId, profilesOverride, schemes, locationTimeGroups)
        if (usages.isEmpty()) return null
        // Dart 先稳定排序取 first：按 endSection 降序。Kotlin maxByOrNull 返回
        // **第一个**最大元素，与「降序排后取 first」一致。
        return usages.maxByOrNull { it.course.endSection }
    }

    /** 课程节的校验（:245-293）。返回 null 表示合法，否则为错误码 payload。 */
    fun validateCourseTimeSchemeOverride(
        schemes: List<TimeScheme>,
        settings: TimetableSettings,
        timeSchemeId: String? = null,
        startSection: Int = 0,
        endSection: Int = 0,
        location: String? = null,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
        onDate: LocalDateTime? = null,
    ): String? {
        val scheme: TimeScheme? = if (timeSchemeId != null) {
            getSchemeById(schemes, timeSchemeId)
        } else {
            resolveCourseTimeScheme(
                schemes,
                settings,
                Course(
                    id = "_validate",
                    name = "_",
                    teacher = "",
                    location = location ?: "",
                    dayOfWeek = 1,
                    startSection = startSection,
                    endSection = endSection,
                    startTime = "08:00",
                    endTime = "09:00",
                ),
                locationTimeGroups = locationTimeGroups,
                scheduleDateRules = scheduleDateRules,
                onDate = onDate,
            )
        }

        val sectionCount = scheme?.sections?.size ?: settings.sections.size
        if (sectionCount <= 0) {
            return if (timeSchemeId == null) {
                "time_scheme_config_unavailable"
            } else {
                "time_scheme_not_found_selected"
            }
        }
        if (startSection < 1 || endSection > sectionCount) {
            return ServiceMessage.encode(
                "time_scheme_sections_insufficient",
                linkedMapOf("startSection" to startSection, "endSection" to endSection),
            )
        }
        return null
    }

    /**
     * 这批课里，在当前作息的课表上**拿不到格子**的节数（:303-318）。
     * 周视图只画 sectionCount 行，节次落在行外的课存得下来、就是不显示。
     */
    fun countCoursesWithoutVisibleRow(
        courses: List<Course>,
        sectionCount: Int,
    ): Int {
        if (sectionCount <= 0) return 0
        return courses.count { course ->
            course.startSection < 1 ||
                course.endSection < course.startSection ||
                course.endSection > sectionCount
        }
    }

    /** 是否有任一引用阻止删除（:320-332）。 */
    fun isSchemeInUse(
        profiles: List<TimetableProfile>,
        schemeId: String,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        schemes: List<TimeScheme> = emptyList(),
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    ): Boolean = collectDeleteBlockers(
        profiles,
        schemeId,
        locationTimeGroups = locationTimeGroups,
        schemes = schemes,
        scheduleDateRules = scheduleDateRules,
    ).isNotEmpty

    /** 删除阻塞的全部引用——provider 守卫与管理页提示共用的唯一真源（:339-393）。 */
    fun collectDeleteBlockers(
        profiles: List<TimetableProfile>,
        schemeId: String,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        schemes: List<TimeScheme> = emptyList(),
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    ): TimeSchemeDeleteBlockers {
        // 任何引用该作息的地点组都阻塞删除（停用的也算：重新启用会复活它）。
        val locationGroupNames = locationTimeGroups
            .filter { it.timeSchemeId == schemeId }
            .map { it.name }
        val dateRuleNames = scheduleDateRules
            .filter { it.timeSchemeId == schemeId }
            .map { it.name }

        val profileNames = mutableListOf<String>()
        var overrideCourseCount = 0
        var locationCourseCount = 0

        for (profile in profiles) {
            if (profile.settings.activeTimeSchemeId == schemeId) {
                profileNames.add(profile.name)
            }
            for (course in profile.courses) {
                if (course.timeSchemeIdOverride == schemeId) {
                    overrideCourseCount++
                    continue
                }
                if (course.timeSchemeIdOverride != null) continue
                val locationMatch = LocationTimeMatchLogic.match(course.location, locationTimeGroups)
                if (locationMatch != null &&
                    locationMatch.timeSchemeId == schemeId &&
                    getSchemeById(schemes, schemeId) != null
                ) {
                    locationCourseCount++
                }
            }
        }

        return TimeSchemeDeleteBlockers(
            profileNames = profileNames,
            overrideCourseCount = overrideCourseCount,
            locationCourseCount = locationCourseCount,
            locationGroupNames = locationGroupNames,
            dateRuleNames = dateRuleNames,
        )
    }

    /** 按课程生效作息改写全部课程钟点（:398-418）。 */
    fun syncCoursesWithEffectiveTimeSchemes(
        source: List<Course>,
        schemes: List<TimeScheme>,
        settings: TimetableSettings,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
        settingsOverride: TimetableSettings? = null,
    ): List<Course> = source.map { course ->
        syncCourseWithEffectiveTimeScheme(
            course,
            schemes = schemes,
            settings = settings,
            locationTimeGroups = locationTimeGroups,
            scheduleDateRules = scheduleDateRules,
            settingsOverride = settingsOverride,
        )
    }

    /**
     * 单节课钟点同步（:429-507）。
     *
     * - 课程无生效模板或节次越界 → 原样返回（引用语义：返回同一实例）；
     * - [Course.hasCustomTime] → **不改写钟点**（脚本下发的真实时间是权威值，
     *   「有自定义时间」的标记必须与它描述的时间一起存活——9 个调用点都走这里，
     *   漏一处就产出「标记说有自定义时间、时间却是模板的」自相矛盾课程）；
     * - 钟点已一致 → 原样返回；
     * - 否则改写 startTime/endTime。
     */
    fun syncCourseWithEffectiveTimeScheme(
        course: Course,
        schemes: List<TimeScheme>,
        settings: TimetableSettings,
        locationTimeGroups: List<LocationTimeGroup> = emptyList(),
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
        settingsOverride: TimetableSettings? = null,
        onDate: LocalDateTime? = null,
    ): Course {
        val resolvedScheme = resolveCourseTimeScheme(
            schemes,
            settings,
            course,
            settingsOverride = settingsOverride,
            locationTimeGroups = locationTimeGroups,
            scheduleDateRules = scheduleDateRules,
            onDate = onDate,
        )
        val sections = resolvedScheme?.sections ?: (settingsOverride ?: settings).sections
        val startIndex = course.startSection - 1
        val endIndex = course.endSection - 1
        if (sections.isEmpty() || startIndex < 0 || endIndex >= sections.size) {
            // 越界/无 sections：不改写（Dart 返回 copyWith 原值的等价物）。
            return course
        }

        if (course.hasCustomTime) {
            // 权威时间来自适配脚本，模板不得覆盖。
            return course
        }

        val startTime = sections[startIndex].startTime
        val endTime = sections[endIndex].endTime
        if (course.startTime == startTime && course.endTime == endTime) {
            return course
        }

        return course.copy(startTime = startTime, endTime = endTime)
    }
}
