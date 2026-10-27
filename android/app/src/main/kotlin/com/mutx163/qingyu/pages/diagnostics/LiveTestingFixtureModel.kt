package com.mutx163.qingyu.pages.diagnostics

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.widgetdata.LiveTestingFixtureData
import com.mutx163.qingyu.widgetdata.SectionTimeData
import java.time.LocalDateTime

/**
 * 临时测试课程页（超级岛快捷测试）的纯 Kotlin 模型
 * （源：`lib/screens/live_testing_fixture_screen.dart`）。
 *
 * 这页只在诊断包（`.debug` / `.profile`）里可达，文案是硬编码中文、不走 ARB。
 * 真正「装课 / 清楚课 / 触发超级岛」的写盘与跳转是 IO 面（Dart 的
 * `installSectionGrid` / `removeAllFixtureCourses` / `triggerLiveUpdateTestForSectionSlot`），
 * 不在本层；本层只用 Phase 2 已迁的 [LiveTestingFixtureData] 纯函数算展示状态：
 * 当前/下一节次、测试课计数、每节网格单元（装了没 / 是不是当前节）、档位选择。
 */
/** 一节网格单元（Dart `_QuickFixtureSectionCell` 的入参）。 */
data class LiveFixtureSectionCell(
    val sectionNumber: Int,
    val startTime: String,
    val installed: Boolean,
    val isCurrent: Boolean,
) {
    val title: String get() = "第${sectionNumber}节"

    /** 右下角小字：当前节优先显示「现在」，装了但非当前显示「已装」，都没有则 null。 */
    val badgeLabel: String?
        get() = when {
            isCurrent -> "现在"
            installed -> "已装"
            else -> null
        }
}

/** 一键发送的一行（当前节次 / 下一节次）。 */
data class LiveFixtureSendRow(
    val sectionNumber: Int,
    val title: String,
    val details: String,
    val enabled: Boolean,
    val source: String,
)

/** 整页视图状态。 */
data class LiveFixtureViewState(
    val pageTitle: String,
    val activeSchemeName: String,
    val schemeDescription: String,
    val sectionCount: Int,
    val fixtureCount: Int,
    val hasFixtures: Boolean,
    val canTrigger: Boolean,
    val currentSection: Int,
    val nextSection: Int,
    val currentStart: String,
    val nextStart: String,
    val leadOptions: List<Int>,
    val leadMinutes: Int,
    val leadIndex: Int,
    val leadTabs: List<String>,
    val installTitle: String,
    val installDetails: String?,
    val installEnabled: Boolean,
    val clearTitle: String,
    val clearDetails: String?,
    val clearEnabled: Boolean,
    val sendRows: List<LiveFixtureSendRow>,
    val sendHint: String,
    val gridCells: List<LiveFixtureSectionCell>,
    val gridEmptyText: String,
)

/** 页内文案（Dart 里逐字硬编码，不走 ARB；照抄）。 */
internal object LiveFixtureStrings {
    const val pageTitle = "临时测试课程"
    const val quickGridSection = "快捷测试课表"
    const val installTitle = "安装 24 时段测试课表"
    const val installing = "正在安装…"
    const val notInstalled = "未安装"
    const val clearTitle = "清除测试课表"
    const val clearing = "正在清除…"
    const val notSelectedScheme = "未选择"
    const val leadSection = "课前提醒"
    const val leadSubtitle = "提前多久进入课前态"
    const val sendSection = "一键发送"
    const val currentSlotPrefix = "当前节次 · 第"
    const val nextSlotPrefix = "下一节次 · 第"
    const val sectionSuffix = "节"
    const val sendHint = "若当前日历周超过课程 endWeek、放假或未到课前窗口，会提示无课而不是硬弹出岛。"
    const val gridSection = "按节次发送"
    const val gridEmptyText = "安装后这里会列出全部节次"
    const val dashClock = "--:--"

    // 触发来源标识（会进诊断日志，用 Dart 原字符串）。
    const val sourceCurrentSlot = "quick_fixture_current_slot"
    const val sourceNextSlot = "quick_fixture_next_slot"
    const val sourceGrid = "quick_fixture_grid"
}

/** 课前提前量档位（Dart `LiveTestingFixtureService.supportedLeadMinutes`）。 */
val liveFixtureLeadOptions: List<Int> = listOf(1, 3, 5, 8)

/** 默认档位（Dart 页面 `_fixtureLeadMinutes = 1`）。 */
const val DEFAULT_FIXTURE_LEAD_MINUTES = 1

/**
 * 装课 / 清除 / 触发的结果提示文案（Dart 各个 `showAppToast` 调用）。
 *
 * 单独拆出来是为了让「星期几」这类口径能脱离 UI 直接测。
 */
object LiveFixtureMessages {
    /** `已套用 $schemeName 并添加 $count 门测试课，星期${weekday}`（weekday 是 1-7 数字，不翻译）。 */
    fun installed(schemeName: String, count: Int, weekday: Int): String =
        "已套用 $schemeName 并添加 $count 门测试课，星期$weekday"

    fun installFailed(detail: String): String = "安装测试课表失败：$detail"

    fun cleared(count: Int): String = "已清除 $count 门测试课"

    fun clearFailed(error: String): String = "清除测试课表失败：$error"
}

/**
 * 组装整页视图状态。
 *
 * @param sections 当前时间方案的节次表（`settings.sections`）
 * @param courses 课表全部课程（用来数测试课）
 * @param activeSchemeName 当前时间方案名；null 时显示「未选择」
 * @param now 当前时间（注入以便测试；Dart 用 `DateTime.now()`）
 * @param leadMinutes 当前选的提前量档位
 * @param isInstalling / isClearing 两个长操作进行中（按钮标题与可用性跟着变）
 */
@Suppress("LongParameterList")
fun buildLiveFixtureViewState(
    sections: List<SectionTimeData>,
    courses: List<Course>,
    activeSchemeName: String?,
    now: LocalDateTime,
    leadMinutes: Int = DEFAULT_FIXTURE_LEAD_MINUTES,
    isInstalling: Boolean = false,
    isClearing: Boolean = false,
): LiveFixtureViewState {
    val sectionCount = sections.size
    val canTrigger = sectionCount > 0
    val currentSection = LiveTestingFixtureData.sectionNumberForTime(now, sections)
    val nextSection = LiveTestingFixtureData.nextSectionNumberForTime(now, sections)

    val fixtureCount = courses.count { LiveTestingFixtureData.isFixtureCourse(it) }
    val hasFixtures = fixtureCount > 0
    val schemeName = activeSchemeName ?: LiveFixtureStrings.notSelectedScheme

    // 当前/下一节的钟点：没有节次表时给占位符而不是越界。
    val currentStart = if (canTrigger) sections[currentSection - 1].startTime else LiveFixtureStrings.dashClock
    val nextStart = if (canTrigger) sections[nextSection - 1].startTime else LiveFixtureStrings.dashClock

    // 档位下标：不在表里时回落到 0（Dart `indexOf(...).clamp(0, len - 1)`）。
    val leadOptions = liveFixtureLeadOptions
    val rawIndex = leadOptions.indexOf(leadMinutes)
    val leadIndex = if (rawIndex < 0) 0 else rawIndex.coerceAtMost(leadOptions.lastIndex)

    val installDetails = when {
        isInstalling -> null
        canTrigger -> "$fixtureCount/$sectionCount"
        else -> LiveFixtureStrings.notInstalled
    }

    val sendRows = listOf(
        LiveFixtureSendRow(
            sectionNumber = currentSection,
            title = "${LiveFixtureStrings.currentSlotPrefix}$currentSection${LiveFixtureStrings.sectionSuffix}",
            details = currentStart,
            enabled = canTrigger,
            source = LiveFixtureStrings.sourceCurrentSlot,
        ),
        LiveFixtureSendRow(
            sectionNumber = nextSection,
            title = "${LiveFixtureStrings.nextSlotPrefix}$nextSection${LiveFixtureStrings.sectionSuffix}",
            details = nextStart,
            enabled = canTrigger,
            source = LiveFixtureStrings.sourceNextSlot,
        ),
    )

    val cells = (1..sectionCount).map { sectionNumber ->
        LiveFixtureSectionCell(
            sectionNumber = sectionNumber,
            startTime = sections[sectionNumber - 1].startTime,
            // Dart：`findFixtureForSection(...) != null`；等价于这条 fixture id 是否还在课表里。
            installed = courses.any {
                LiveTestingFixtureData.isFixtureCourse(it) &&
                    it.id == LiveTestingFixtureData.fixtureIdForSection(sectionNumber)
            },
            isCurrent = sectionNumber == currentSection,
        )
    }

    return LiveFixtureViewState(
        pageTitle = LiveFixtureStrings.pageTitle,
        activeSchemeName = schemeName,
        schemeDescription = "当前方案：$schemeName。测试完成后请先清除测试课表，再切换回原时间方案。",
        sectionCount = sectionCount,
        fixtureCount = fixtureCount,
        hasFixtures = hasFixtures,
        canTrigger = canTrigger,
        currentSection = currentSection,
        nextSection = nextSection,
        currentStart = currentStart,
        nextStart = nextStart,
        leadOptions = leadOptions,
        leadMinutes = leadOptions[leadIndex],
        leadIndex = leadIndex,
        leadTabs = leadOptions.map { "$it 分钟" },
        installTitle = if (isInstalling) LiveFixtureStrings.installing else LiveFixtureStrings.installTitle,
        installDetails = installDetails,
        installEnabled = !isInstalling,
        clearTitle = if (isClearing) LiveFixtureStrings.clearing else LiveFixtureStrings.clearTitle,
        clearDetails = if (hasFixtures) "$fixtureCount 门" else null,
        clearEnabled = !isClearing && hasFixtures,
        sendRows = sendRows,
        sendHint = LiveFixtureStrings.sendHint,
        gridCells = cells,
        gridEmptyText = LiveFixtureStrings.gridEmptyText,
    )
}
