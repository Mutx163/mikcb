package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.LocationTimeMatchLogic
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableSettings

/**
 * 「重新匹配当前课表」的**纯逻辑层**（对齐 Dart
 * `lib/services/timetable_location_rule_service.dart:286-585` 的
 * `TimetableLocationRuleService.applyToActiveProfile`）。
 *
 * ## 它做什么（Dart 逐条照搬，一行不省）
 *
 * 对活动档案里的**每一门课**：
 *
 * | 情形 | 处理 | 计入 |
 * |---|---|---|
 * | `hasCustomTime`（适配脚本下发的真实钟点） | **原样不动**——地点规则不得冲掉早读/连堂 | — |
 * | 地点没命中任何启用的组 | 原样不动 | `noMatch` |
 * | 命中了组，但组绑的模板不存在 | 原样不动 | `missingScheme` |
 * | 命中且模板存在，但节次坐不进模板（`endSection > 模板节数`） | 原样不动（**HARD RULE**：宁可不同步，也不要写出荒谬钟点） | `sectionOverflow` + 课程名（最多 5 个） |
 * | 其余 | **释放手动模板绑定**（`timeSchemeIdOverride = null`）+ 按地点规则重算钟点 | `matched`；有变化再计 `updated` |
 *
 * 「释放手动绑定」是这条路的关键语义：Dart 注释写着「Return the course to automatic
 * mode, then resolve it through the current location rule. This keeps future rule edits
 * automatic instead of turning a rematch into another permanent manual override.」
 * 只有 `hasCustomTime` 那类课程例外（那是脚本的真实时刻，不是手动绑的模板）。
 *
 * ## 为什么单独一层
 *
 * 壳里那段执行入口要读写仓储，而「哪些课会被改、改成什么、算不算更新」全是纯函数。
 * 分出来之后 L0 能直接钉住 Dart 的四类计数口径，不必准备一份真存储。
 *
 * ## 与 Dart 的已知差异（刻意的）
 *
 * - Dart 在每个分支里写 `AppLogService` 审计日志（`location_time_apply`，含课程名/地点/
 *   前后钟点的 changeSamples）。Kotlin 侧审计走 `SilentFailureCatchGuardTest` 豁免的
 *   另一套设施，本层保持纯函数、不打日志；统计值全部经 [LocationTimeApplyStats] 回给宿主。
 * - Dart 落盘失败时会先把内存状态回滚再上抛（`:553-562`）。Kotlin 仓储的写入入口本身
 *   是「先落盘、成功才改内存」，不需要这层手工回滚，所以本层只算不写。
 */
object LocationTimeApplyLogic {

    /** 一次「重新匹配」的统计（Dart `LocationTimeApplyStats` 的用户可见子集）。 */
    data class Stats(
        /** 参与重算的课程总数（不含 `hasCustomTime` 跳过的）。 */
        val examined: Int = 0,
        /** 命中地点规则、且节次坐得进模板的课程数（Dart `matchedCount`）。 */
        val matched: Int = 0,
        /** 其中真正发生变化的课程数（钟点变了 **或** 手动绑定被释放）。 */
        val updated: Int = 0,
        /** 命中了、节次也坐得进，但钟点本来就一致。 */
        val sameClock: Int = 0,
        /** 节次越界、被按 HARD RULE 跳过。 */
        val sectionOverflow: Int = 0,
        /** 越界课程名（最多 5 个，供附加提示）。 */
        val sectionOverflowCourseNames: List<String> = emptyList(),
        /** 地点没命中任何启用组。 */
        val noMatch: Int = 0,
        /** 命中但组绑的模板不存在。 */
        val missingScheme: Int = 0,
        /** 被释放的手动模板绑定条数（Dart `autoReleasedCount`）。 */
        val releasedOverrides: Int = 0,
    ) {
        /** 有没有东西需要落盘（Dart `if (updatedCount > 0)`）。 */
        val hasChanges: Boolean get() = updated > 0
    }

    /** 重算结果：新课程表 + 统计。 */
    data class Plan(
        val courses: List<Course>,
        val stats: Stats,
    )

    /**
     * 按**当前**地点分组重算活动档案的课程钟点。
     *
     * @param courses 活动档案的课程
     * @param schemes 全部时间模板
     * @param settings 活动档案的设置（决定「主课表模板」）
     * @param locationTimeGroups 当前地点分组（只有 `enabled` 的组参与匹配）
     * @param scheduleDateRules 日程日期规则（`syncCourseWithEffectiveTimeScheme` 的入参之一）
     */
    fun plan(
        courses: List<Course>,
        schemes: List<TimeScheme>,
        settings: TimetableSettings,
        locationTimeGroups: List<LocationTimeGroup>,
        scheduleDateRules: List<ScheduleDateRule> = emptyList(),
    ): Plan {
        val next = ArrayList<Course>(courses.size)
        var examined = 0
        var matched = 0
        var updated = 0
        var sameClock = 0
        var sectionOverflow = 0
        var noMatch = 0
        var missingScheme = 0
        var releasedOverrides = 0
        val overflowNames = ArrayList<String>(OVERFLOW_NAME_LIMIT)

        for (course in courses) {
            // 脚本下发的真实钟点是权威值，地点规则不得覆盖（Dart :386-389）。
            if (course.hasCustomTime) {
                next.add(course)
                continue
            }
            examined++

            val match = LocationTimeMatchLogic.match(course.location, locationTimeGroups)
            if (match == null) {
                noMatch++
                next.add(course)
                continue
            }
            val matchedScheme = TimeSchemeLogic.getSchemeById(schemes, match.timeSchemeId)
            if (matchedScheme == null) {
                missingScheme++
                next.add(course)
                continue
            }

            val startIndex = course.startSection - 1
            val endIndex = course.endSection - 1
            // HARD RULE（Dart :435-472）：坐不进模板就整门课不动，连 override 都不释放。
            if (startIndex < 0 || endIndex < startIndex || endIndex >= matchedScheme.sections.size) {
                sectionOverflow++
                if (overflowNames.size < OVERFLOW_NAME_LIMIT) overflowNames.add(course.name)
                next.add(course)
                continue
            }

            matched++
            // 回到「自动匹配」再按地点规则解析（Dart :479）。
            val released = if (course.timeSchemeIdOverride != null) {
                releasedOverrides++
                course.copy(timeSchemeIdOverride = null)
            } else {
                course
            }
            val synced = TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(
                course = released,
                schemes = schemes,
                settings = settings,
                locationTimeGroups = locationTimeGroups,
                scheduleDateRules = scheduleDateRules,
            )

            // Dart 的 sameClock 拿「命中模板的节次」当预期值（:484-490）。
            val expectedStart = matchedScheme.sections[startIndex].startTime
            val expectedEnd = matchedScheme.sections[endIndex].endTime
            if (course.startTime == expectedStart && course.endTime == expectedEnd) {
                sameClock++
            }

            val clockChanged = synced.startTime != course.startTime || synced.endTime != course.endTime
            val overrideChanged = synced.timeSchemeIdOverride != course.timeSchemeIdOverride
            if (clockChanged || overrideChanged) updated++
            next.add(synced)
        }

        return Plan(
            courses = next,
            stats = Stats(
                examined = examined,
                matched = matched,
                updated = updated,
                sameClock = sameClock,
                sectionOverflow = sectionOverflow,
                sectionOverflowCourseNames = overflowNames,
                noMatch = noMatch,
                missingScheme = missingScheme,
                releasedOverrides = releasedOverrides,
            ),
        )
    }

    /** Dart 只收前 5 个越界课程名（`:440-442`）；多写只会让提示变成长篇。 */
    const val OVERFLOW_NAME_LIMIT = 5
}
