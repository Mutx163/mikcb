package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableProfile

/**
 * 把仓储里的原始数据装配成 [TimeSchemeUsageIndex]（纯函数、无状态）。
 *
 * ## 为什么单独一个工厂，而不是让页面自己去查
 *
 * 引用关系有三处不同来源（课表级绑定、课程级覆盖、地点关键词匹配、日期规则、地点分组），
 * 每一处的口径都不同，而且**差一条就会让删除拦截失效**。集中在这里做一次，页面与
 * 模型层就只需要一个纯数据入参；也让这些口径能在 JVM 单测里逐条钉住。
 *
 * ## 口径（逐条对 `time_scheme_management_screen.dart:981-1007` + `domain/time_scheme_logic.dart`）
 *
 * | 段 | 来源 | 说明 |
 * |---|---|---|
 * | [TimeSchemeUsageIndex.directProfiles] | `profiles.filter { settings.activeTimeSchemeId == id }` | 课表级直接绑定 |
 * | [TimeSchemeUsageIndex.overrideCourses] | `getCourseUsages` 里 `usesOverride` | 课程手动指定的副模板 |
 * | [TimeSchemeUsageIndex.locationCourses] | `getCourseUsages` 里 `usesLocationMatch` | 按上课地点自动匹配 |
 * | [TimeSchemeUsageIndex.followMainCourses] | `getCourseUsages` 里其余 | 跟着课表主模板走 |
 * | [TimeSchemeUsageIndex.locationGroups] | `locationGroups.filter { timeSchemeId == id }` | **停用的也算**（重新启用会复活该模板），与 [TimeSchemeLogic] 同口径 |
 * | [TimeSchemeUsageIndex.dateRules] | `dateRules.filter { timeSchemeId == id }` | 日期规则绑定 |
 *
 * 「键只填非空」「缺键与空表等价」：不塞大量空列表，模型层 [TimeSchemeUsageIndex]
 * 的取用一律走 `orEmpty()`。
 */
object TimeSchemeUsageIndexFactory {

    fun build(
        schemes: List<TimeScheme>,
        profiles: List<TimetableProfile>,
        locationGroups: List<LocationTimeGroup>,
        dateRules: List<ScheduleDateRule>,
    ): TimeSchemeUsageIndex {
        val directProfiles = LinkedHashMap<String, List<TimeSchemeProfileRef>>()
        for (profile in profiles) {
            val schemeId = profile.settings.activeTimeSchemeId ?: continue
            if (schemeId.isBlank()) continue
            directProfiles[schemeId] = directProfiles[schemeId].orEmpty() +
                TimeSchemeProfileRef(id = profile.id, name = profile.name)
        }

        val overrideCourses = LinkedHashMap<String, List<TimeSchemeCourseRef>>()
        val locationCourses = LinkedHashMap<String, List<TimeSchemeCourseRef>>()
        val followMainCourses = LinkedHashMap<String, List<TimeSchemeCourseRef>>()
        val ordered = LinkedHashMap<String, List<TimeSchemeCourseRef>>()

        for (scheme in schemes) {
            // getCourseUsages 内部按「档案 → 课程」的顺序遍历，因此这一遍同时给出
            // 三分类与 Dart 预览文字要用的原始顺序（见 TimeSchemeUsageIndex.courseReferences）。
            val usages = TimeSchemeLogic.getCourseUsages(
                profiles = profiles,
                schemeId = scheme.id,
                profilesOverride = null,
                schemes = schemes,
                locationTimeGroups = locationGroups,
            )
            if (usages.isEmpty()) continue
            val refs = usages.map { usage ->
                TimeSchemeCourseRef(
                    // getCourseUsages 只回过档案名，不回档案 id；按课程 id 反查所属档案
                    // （课程 id 在每个档案里唯一，比按名字匹配可靠：同名课表是合法状态）。
                    profileId = profiles.firstOrNull { profile ->
                        profile.courses.any { it.id == usage.course.id }
                    }?.id.orEmpty(),
                    profileName = usage.profileName,
                    courseId = usage.course.id,
                    courseName = usage.course.name,
                    dayOfWeek = usage.course.dayOfWeek,
                    startSection = usage.course.startSection,
                    endSection = usage.course.endSection,
                )
            }
            ordered[scheme.id] = refs
            val overrideRefs = mutableListOf<TimeSchemeCourseRef>()
            val locationRefs = mutableListOf<TimeSchemeCourseRef>()
            val followRefs = mutableListOf<TimeSchemeCourseRef>()
            for ((index, usage) in usages.withIndex()) {
                when {
                    usage.usesOverride -> overrideRefs.add(refs[index])
                    usage.usesLocationMatch -> locationRefs.add(refs[index])
                    else -> followRefs.add(refs[index])
                }
            }
            if (overrideRefs.isNotEmpty()) overrideCourses[scheme.id] = overrideRefs
            if (locationRefs.isNotEmpty()) locationCourses[scheme.id] = locationRefs
            if (followRefs.isNotEmpty()) followMainCourses[scheme.id] = followRefs
        }

        val locationGroupRefs = LinkedHashMap<String, List<TimeSchemeNameRef>>()
        for (group in locationGroups) {
            if (group.timeSchemeId.isBlank()) continue
            locationGroupRefs[group.timeSchemeId] = locationGroupRefs[group.timeSchemeId].orEmpty() +
                TimeSchemeNameRef(id = group.id, name = group.name)
        }

        val dateRuleRefs = LinkedHashMap<String, List<TimeSchemeNameRef>>()
        for (rule in dateRules) {
            if (rule.timeSchemeId.isBlank()) continue
            dateRuleRefs[rule.timeSchemeId] = dateRuleRefs[rule.timeSchemeId].orEmpty() +
                TimeSchemeNameRef(id = rule.id, name = rule.name)
        }

        return TimeSchemeUsageIndex(
            directProfiles = directProfiles,
            followMainCourses = followMainCourses,
            overrideCourses = overrideCourses,
            locationCourses = locationCourses,
            locationGroups = locationGroupRefs,
            dateRules = dateRuleRefs,
            orderedCourseRefs = ordered,
        )
    }
}
