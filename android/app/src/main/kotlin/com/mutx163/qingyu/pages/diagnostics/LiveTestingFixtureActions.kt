package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.widgetdata.LiveTestingFixtureData
import com.mutx163.qingyu.widgetdata.SectionTimeData
import java.time.LocalDateTime

/**
 * 临时测试课程页的**四个交互**（纯 Kotlin，源：`lib/services/live_testing_fixture_service.dart` 481 行）。
 *
 * ## 为什么是「端口 + 纯逻辑」而不是直接摸仓储
 *
 * Dart 侧同一套写法：服务自己声明窄端口 [LiveTestingFixtureHost]，宿主适配器
 * （`lib/providers/live_testing_fixture_access.dart`）在 providers 层实现它。
 * Kotlin 侧照搬——`pages/` 是纯 Kotlin 目录（L0 单测的 classpath 里没有 android.jar），
 * 不能 import 仓储，于是这里只声明自己需要的那几件事，由 `app/LiveTestingFixtureHost.kt`
 * 用 [com.mutx163.qingyu.app.TimetableRepository] 实现。
 *
 * ## 已移植 / 未移植（诚实清单）
 *
 * | Dart | 本文件 | 说明 |
 * |---|---|---|
 * | `removeAllFixtureCourses`（:398-410） | [clear] | 只删 `live_test_` 前缀的课；**用户真课原样留下** |
 * | `installSectionGrid`（:414-442） | [installGrid] | 24 段整点节次 + 每节一门夹具课 |
 * | `upsertTimedFixtureCourse`（:444-480） | [upsertTimed] | 只挪钟点、节次下标不动（周网格位置稳定） |
 * | `ensureHourlyTimeScheme`（:142-178） | **未移植** | Kotlin 仓储没有 `createTimeScheme` / `updateTimeScheme`，见 [LiveTestingFixtureHost.applySections] 的说明 |
 * | `triggerLiveUpdateTestForSectionSlot`（`live_testing_trigger.dart`） | **写课半步在本文件** | 生产刷新半步（快照同步 + reschedule）在 `app/LiveTestTriggerNative.kt` 的 [LiveTestTrigger.productionRefresh]，宿主按 Dart 顺序（写课 → 刷新）串接 |
 */
object LiveFixtureActions {

    /** 24 时段测试方案的固定名字（Dart `LiveTestingFixtureService.timeSchemeName`）。 */
    const val TIME_SCHEME_NAME: String = "超级岛测试24时段"

    /** 导入来源标记（Dart `installSectionGrid` 的 `source: 'live_testing_fixture'`）。 */
    const val IMPORT_SOURCE: String = "live_testing_fixture"

    /** 装课时的空节次表错误（Dart `StateError('测试时间方案没有节次，无法安装测试课表')`）。 */
    const val EMPTY_SECTIONS_FOR_INSTALL: String = "测试时间方案没有节次，无法安装测试课表"

    /** 写测试课时的空节次表错误（Dart `StateError('当前课表没有节次时间，无法写入测试课')`）。 */
    const val EMPTY_SECTIONS_FOR_TIMED: String = "当前课表没有节次时间，无法写入测试课"

    /**
     * 清空夹具课（Dart `removeAllFixtureCourses`，:398-410）。
     *
     * **硬要求：只删 `live_test_` 前缀的课，用户真实课程一门都不能少。**
     * 实现方式是「按真快照重算整份课程列表再一次性替换」——不是逐条 `deleteCourse`，
     * 因为逐条删会每删一门落一次盘、通知一次，24 门就是 24 次闪屏；更重要的是
     * 那样必须依赖「删的 id 确实来自快照」这件事在调用点成立，而这里把它变成
     * 纯函数的一部分（[splitCourses]），单测能直接钉住。
     *
     * @return 删掉的夹具课门数（0 表示本来就没有）
     */
    fun clear(host: LiveTestingFixtureHost): Int {
        val courses = host.courses()
        val fixtureIds = courses.filter { LiveTestingFixtureData.isFixtureCourse(it) }.map { it.id }
        if (fixtureIds.isEmpty()) return 0
        val (_, userCourses) = splitCourses(courses)
        host.replaceCourses(userCourses)
        return fixtureIds.size
    }

    /**
     * 安装 24 时段测试课表（Dart `installSectionGrid`，:414-442）。
     *
     * 顺序与 Dart 一致：先清旧夹具课 → 套用 24 段整点节次 → 每节装一门夹具课。
     *
     * 与 Dart 的一处差异：Dart 先建（或更新）一个名叫 [TIME_SCHEME_NAME] 的时间方案再
     * **套用**它（`activeTimeSchemeId` 也指向它）；Kotlin 仓储没有方案写入口，
     * 所以这里只把**节次表**套进当前设置（见 [LiveTestingFixtureHost.applySections]）。
     * 效果上「左栏时间与课程对得上」这条目的达成，但方案列表里不会多出那一条——
     * 已登记在 `.agents/compose-phase3/claims/_DIAG-settings-fixture-gaps.md`。
     *
     * @return 装入的测试课门数
     */
    fun installGrid(
        host: LiveTestingFixtureHost,
        now: LocalDateTime,
        semesterWeekCount: Int,
    ): Int {
        // 1. 先清旧夹具（Dart :416；装两次不会翻倍）。
        clear(host)
        // 2. 24 段整点节次（Dart buildHourlySections，:116-126）。
        val sections = LiveTestingFixtureData.buildHourlySections()
        if (sections.isEmpty()) throw IllegalStateException(EMPTY_SECTIONS_FOR_INSTALL)
        // 3. 套用节次表，让左栏时间与课程一致（Dart applyTimeScheme）。
        host.applySections(sections)
        // 4. 每节一门夹具课（Dart buildSectionGrid，:226-242），今天周几就排周几。
        val dayOfWeek = now.dayOfWeek.value
        val grid = sections.mapIndexed { index, section ->
            LiveTestingFixtureData.buildSlotTemplate(
                sectionNumber = index + 1,
                section = section,
                dayOfWeek = dayOfWeek,
                semesterWeekCount = semesterWeekCount,
            )
        }
        // 5. 一次落盘：用户原有的课一门不动，只把夹具课追加在后面（Dart replaceExisting:false）。
        val (_, userCourses) = splitCourses(host.courses())
        host.replaceCourses(userCourses + grid)
        return grid.size
    }

    /**
     * 把某一节的夹具课改成「[leadMinutes] 分钟后上课」（Dart `upsertTimedFixtureCourse`，:444-480）。
     *
     * 节次下标不动（`startSection/endSection` 保持模板值），只挪钟点——周网格位置稳定，
     * 超级岛按自由时钟选课。**临近午夜**会生成跨日钟点（例如 23:59 → 00:02），此时
     * `buildTimedTestCourse` 抛 `IllegalStateException`，本方法原样上抛（调用方弹错误提示）。
     *
     * @return 写进去的那门课
     */
    fun upsertTimed(
        host: LiveTestingFixtureHost,
        sectionNumber: Int,
        now: LocalDateTime,
        leadMinutes: Long,
        note: String? = null,
    ): Course {
        val settings = host.settings()
        val sections = settings.sections
        if (sections.isEmpty()) throw IllegalStateException(EMPTY_SECTIONS_FOR_TIMED)
        // Dart `sectionNumber.clamp(1, sections.length)`。
        val clampedSection = sectionNumber.coerceIn(1, sections.size)
        val section = sections[clampedSection - 1]
        val existing = host.courses().firstOrNull {
            it.id == LiveTestingFixtureData.fixtureIdForSection(clampedSection)
        }
        val template = existing ?: LiveTestingFixtureData.buildSlotTemplate(
            sectionNumber = clampedSection,
            section = toSectionTimeData(section),
            dayOfWeek = now.dayOfWeek.value,
            semesterWeekCount = settings.semesterWeekCount,
        )
        val timedCourse = LiveTestingFixtureData.buildTimedTestCourse(
            template = template,
            now = now,
            leadMinutes = leadMinutes,
        )
        if (existing == null) {
            host.addCourse(timedCourse)
        } else {
            host.updateCourse(timedCourse)
        }
        // `note` 与 Dart 同一口径：null 表示沿用模板自带的备注，不覆盖。
        return if (note == null) timedCourse else timedCourse.copy(note = note)
    }

    /**
     * 把快照里的课程分成「夹具课」与「用户真课」（Dart `isFixtureCourse` 的分组形态）。
     *
     * @return 夹具课程 + 用户课程（两者都保持原顺序）
     */
    fun splitCourses(courses: List<Course>): Pair<List<Course>, List<Course>> =
        courses.filter { LiveTestingFixtureData.isFixtureCourse(it) } to
            courses.filterNot { LiveTestingFixtureData.isFixtureCourse(it) }

    /** 节次换算：core 的 [SectionTime] → widgetdata 的 [SectionTimeData]（同字段同口径）。 */
    fun toSectionTimeData(section: SectionTime): SectionTimeData =
        SectionTimeData(startTime = section.startTime, endTime = section.endTime)
}

/**
 * 夹具安装/清理/触发需要的宿主窄面（Dart `LiveTestingFixtureHost`，:15-48）。
 *
 * 刻意只暴露这 6 个成员——比 Dart 那 11 个少，因为 Kotlin 的仓储没有作息方案写入口
 * （见 [applySections]）。宿主实现见 `app/LiveTestingFixtureHost.kt`。
 */
interface LiveTestingFixtureHost {

    /** 课表里的全部课程（活动档案的真快照）。 */
    fun courses(): List<Course>

    /** 课表设置（只读：`sections` / `semesterWeekCount`）。 */
    fun settings(): TimetableSettings

    /** 新增一门课。 */
    fun addCourse(course: Course)

    /** 覆盖已有课程（按 id）。 */
    fun updateCourse(course: Course)

    /**
     * **一次性**替换活动档案的课程列表（保留作业 / 考试 / 日程）。
     *
     * 为什么要有它：Dart 装课走 `importParsedCourses`（一次写一次通知），清空走逐条
     * `deleteCourse`。Kotlin 侧若逐条删，24 门就是 24 次落盘 + 24 次重组；而且
     * 「不得误删用户课程」这条硬要求只有在「整份重算」的形态下才能被单测直接钉住。
     */
    fun replaceCourses(courses: List<Course>)

    /**
     * 把节次表套进当前设置（Dart `applyTimeScheme` 的**节次部分**）。
     *
     * ⚠️ 与 Dart 的差异：Dart 会先把 24 时段方案创建/更新进方案列表、再把
     * `activeTimeSchemeId` 指向它。Kotlin 仓储（`TimetableRepository`）目前只有
     * `updateSettings`，没有 `createTimeScheme` / `updateTimeScheme` / `applyTimeScheme`，
     * 所以这里只能保证「节次表与课程一致」，方案列表里不会多出一条。
     *
     * 是否调用它属于**实现方的判断**：宿主实现可以只在「当前节次表与 24 段整点不一致」
     * 时真的写盘，避免每次装课都无谓落一次盘。
     */
    fun applySections(sections: List<SectionTimeData>)
}
