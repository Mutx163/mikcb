package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimeSchemeLogic
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.ScheduleDateRule as CoreScheduleDateRule
import java.time.LocalDateTime

/**
 * 日期规则自动套用作息需要的最小宿主面（纯逻辑端口，无 IO / Android 依赖）。
 *
 * 与 Dart `TimetableScheduleDateRulePort`（`lib/services/timetable_schedule_date_rule_service.dart:16-27`）
 * 对应。Dart 那份继承 `TimetableTimeSchemePort` 是为了复用「套用作息」那棵状态树；
 * Kotlin 侧把需要的状态与副作用显式列出来，端口更小、更好给假实现。
 */
interface ScheduleDateRuleAutoApplyPort {

    /** 规则列表（落盘真源是 `core/` 那份，由宿主转交）。 */
    val scheduleDateRules: List<CoreScheduleDateRule>

    val timeSchemes: List<TimeScheme>

    /** 全部档案；批量套用会改**每一个**档案的默认作息与未锁课程钟点。 */
    val profiles: List<TimetableProfile>

    val activeProfileId: String?

    /** 活动档案当前课程（Dart 侧与 profiles 里那份分开维护，这里照抄用于越界判定）。 */
    val courses: List<Course>

    val settings: TimetableSettings

    val locationTimeGroups: List<LocationTimeGroup>

    /** 上次成功套用的签名；读写由宿主落盘，签名计算统一走 [ScheduleDateRuleLogic.appliedSignature]。 */
    var scheduleDateRuleLastAppliedSignature: String?

    /**
     * 一次落盘**全部档案 + 全局设置**。
     *
     * **契约**：失败必须抛错，且抛错时内存保持套用前的样子（先落盘、成功才改内存）。
     * 与 Dart 的 `saveProfiles` + 失败整体回滚等价；调用方 [ScheduleDateRuleAutoApply.applyDue]
     * 在它抛错时不再写签名、不再通知。
     */
    fun persistTimetableState(profiles: List<TimetableProfile>, settings: TimetableSettings)

    /** 课表已成功落盘后写「已套用签名」；失败抛错，内存标记不得先行更新。 */
    fun saveScheduleDateRuleLastAppliedSignature(signature: String)

    /** 课表数据变化，通知云同步。 */
    fun notifySyncDataChanged()

    fun notifyStateChanged()

    fun clearCurrentLiveCourseId()
}

/**
 * 日期规则「到点自动套用作息」的**唯一一份实现**。
 *
 * 逐条移植 Dart `TimetableScheduleDateRuleService.applyDue`
 *（`lib/services/timetable_schedule_date_rule_service.dart:45-213`），包括：
 *
 * 1. 今天命中某条启用规则、且签名与上次成功套用的不同 → 才动手（同一档期只套一次，
 *    之后用户手改课程不会被每日打开再次覆盖）；
 * 2. 模板不存在 → [ScheduleDateRuleApplyOutcome.SchemeMissing]，不动任何状态；
 * 3. 任何档案/活动课表里最靠后的节次超过模板节数 → [ScheduleDateRuleApplyOutcome.SectionOverflow]，
 *    带上两边的数，不动任何状态；
 * 4. 全部档案换默认作息并重写未锁课程钟点；活动档案的全局设置跟着它那份镜像走；
 * 5. **先落盘、后通知、最后写签名**；签名必须自己落盘成功后才进内存
 *   （内存记了盘上没记，重启后会再套一次；盘上记了内存没记，本次会话会重复套）。
 *
 * ## Dart 触发点（宿主接线时照这个跑）
 *
 * - 冷启动首帧渲染后：`timetable_provider.dart:927`
 * - 新增 / 修改 / 删除规则后：`:1624` / `:1667` / `:1729`
 * - 导入或云恢复替换规则后：`replaceScheduleDateRules`（`:1746` 附近）
 * - 日切 / 时间上下文刷新：`syncTemporalContext`（`:3278`）
 *
 * 本类只提供入口；真正在哪个生命周期点调用由壳决定（`app/` 与壳文件不在本批写作用域）。
 */
object ScheduleDateRuleAutoApply {

    /**
     * 到了规则的生效日就批量套用作息；不满足条件时如实返回 [outcome]。
     *
     * @param now 参考时刻，测试注入；生产不传。
     */
    fun applyDue(
        port: ScheduleDateRuleAutoApplyPort,
        now: LocalDateTime = LocalDateTime.now(),
    ): ScheduleDateRuleApplyResult {
        val today = ScheduleDateRuleLogic.dateOnly(now)
        val calendarRules = port.scheduleDateRules.map { it.toCalendarDateRule() }
        val matched = ScheduleDateRuleLogic.match(today, calendarRules)
        if (!ScheduleDateRuleLogic.shouldBulkApply(
                matchedRule = matched,
                lastAppliedSignature = port.scheduleDateRuleLastAppliedSignature,
            )
        ) {
            return ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.NotDue)
        }

        // shouldBulkApply 为真 ⇒ matched 非空。
        val rule = requireNotNull(matched)
        val scheme = port.timeSchemes.firstOrNull { it.id == rule.timeSchemeId }
            ?: return ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.SchemeMissing)

        // 先把「每一个档案」的课程都算进来：只看活动档案会留下指向装不下的模板的非活动档。
        var requiredMaxSection = 0
        for (profile in port.profiles) {
            for (course in profile.courses) {
                if (course.endSection > requiredMaxSection) {
                    requiredMaxSection = course.endSection
                }
            }
        }
        for (course in port.courses) {
            if (course.endSection > requiredMaxSection) {
                requiredMaxSection = course.endSection
            }
        }
        if (requiredMaxSection > scheme.sections.size) {
            return ScheduleDateRuleApplyResult(
                outcome = ScheduleDateRuleApplyOutcome.SectionOverflow,
                requiredMaxSection = requiredMaxSection,
                schemeSectionCount = scheme.sections.size,
            )
        }

        val nextProfiles = port.profiles.map { profile ->
            val profileSettings = profile.settings.copy(
                activeTimeSchemeId = scheme.id,
                sections = scheme.sections,
            )
            profile.copy(
                settings = profileSettings,
                courses = TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(
                    source = profile.courses,
                    schemes = port.timeSchemes,
                    settings = profileSettings,
                    locationTimeGroups = port.locationTimeGroups,
                    scheduleDateRules = port.scheduleDateRules,
                ),
            )
        }
        val activeIndex = nextProfiles.indexOfFirst { it.id == port.activeProfileId }
        val nextSettings = if (activeIndex >= 0) {
            // 全局设置跟随活动档案的镜像（Dart `settingsFromProfile`）。
            nextProfiles[activeIndex].settings
        } else {
            port.settings.copy(activeTimeSchemeId = scheme.id, sections = scheme.sections)
        }

        // 失败时按端口契约内存不动，因此这里不需要再抓一份快照回滚。
        port.persistTimetableState(nextProfiles, nextSettings)

        // 课表已经落成功，内存就是它该有的样子——先通知，别让后面签名写失败把 UI 留在旧值。
        port.notifySyncDataChanged()
        port.clearCurrentLiveCourseId()
        port.notifyStateChanged()

        val signature = ScheduleDateRuleLogic.appliedSignature(rule)
        port.saveScheduleDateRuleLastAppliedSignature(signature)
        port.scheduleDateRuleLastAppliedSignature = signature

        return ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.Applied)
    }
}

/**
 * `core.ScheduleDateRule`（落盘真源）→ [ScheduleDateRule]（规则逻辑入参）。
 *
 * 两份同形模型一直靠各宿主手抄转换（`TimeSchemeHost.kt:626` 有一份私有副本）；
 * 这里给出唯一入口，避免再多一份会漂的实现。
 */
fun CoreScheduleDateRule.toCalendarDateRule(): ScheduleDateRule = ScheduleDateRule(
    id = id,
    name = name,
    timeSchemeId = timeSchemeId,
    enabled = enabled,
    startDate = startDate,
    endDate = endDate,
)

/** [ScheduleDateRule] → `core.ScheduleDateRule`（与 [toCalendarDateRule] 互逆，字段逐字保留）。 */
fun ScheduleDateRule.toCoreDateRule(): CoreScheduleDateRule = CoreScheduleDateRule(
    id = id,
    name = name,
    timeSchemeId = timeSchemeId,
    enabled = enabled,
    startDate = startDate,
    endDate = endDate,
)
