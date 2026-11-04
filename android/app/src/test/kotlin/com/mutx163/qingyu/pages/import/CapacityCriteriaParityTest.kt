package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.pages.import.warehouse.AiImageImportApply
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「节次配额判据」的**防漂移守卫**（Lead 2026-11-03 裁决）。
 *
 * ## 为什么需要它
 *
 * 同一套判据有两份实现：
 * - [ImportFlowModel]（`pages/import` 根目录，通用导入路径）；
 * - [AiImageImportApply]（`pages/import/warehouse`，教务脚本回写路径）。
 *
 * warehouse 模块的 L0 编译范围是模块子目录，**收不到** `pages/import` 根目录的
 * `ImportFlowModel.kt`（`test-kotlin-module.ps1` 的 mainDir 就是模块子目录），
 * 所以生产代码里没法只留一份、让另一份直接引用；Lead 裁决「不改脚本、不挪文件」，
 * 改为在**这个测试**里同时看两边，用表驱动的对拍把两份实现钉住。
 *
 * 谁改了一边的判据（阈值、边界、补节锚点），这里立刻红：
 * - 够用：`required < current.size`
 * - 恰好够：`required == current.size`
 * - 不够：`required > current.size`（含只差一节与差很多节）
 *
 * 本测试位于 `pages/import` 根目录，跑
 * `test-kotlin-module.ps1 -Module pages/import` 时两侧源码都在 classpath 里。
 */
class CapacityCriteriaParityTest {

    /** 按 08:00 起、每节 45 分钟 + 10 分钟课间造 [count] 节。 */
    private fun sections(count: Int): List<SectionTime> = (1..count).map { index ->
        val start = 8 * 60 + (index - 1) * 55
        SectionTime(formatHm(start), formatHm(start + 45))
    }

    private fun formatHm(minutes: Int): String =
        String.format(Locale.ROOT, "%02d:%02d", minutes / 60, minutes % 60)

    /** 覆盖「空节次表 / 常规 6 节 / 12 节」三种现状。 */
    private val currentSectionSets: List<List<SectionTime>> = listOf(
        emptyList(),
        sections(6),
        sections(12),
    )

    /** 覆盖「没有课 / 远小于 / 差一节 / 恰好 / 多一节 / 多很多」。 */
    private val requiredCounts: List<Int> = listOf(0, 1, 5, 6, 7, 12, 13, 20)

    private fun course(endSection: Int): Course = Course(
        id = "c-$endSection",
        name = "测试课",
        teacher = "老师",
        location = "A101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = endSection,
        startTime = "08:00",
        endTime = "08:45",
    )

    @Test
    fun `配额判据与 ImportFlowModel 同输入同结果`() {
        for (current in currentSectionSets) {
            for (required in requiredCounts) {
                val expected = ImportFlowModel.needsSectionExpansion(current, required)
                val actual = AiImageImportApply.needsExpansion(current, required)
                assertEquals(
                    "节次 ${current.size} 节、需要第 $required 节时判据不一致",
                    expected,
                    actual,
                )
            }
        }
    }

    @Test
    fun `补节结果与 ImportFlowModel 同输入同结果`() {
        for (current in currentSectionSets) {
            for (required in requiredCounts) {
                assertEquals(
                    "节次 ${current.size} 节、需要第 $required 节时补节结果不一致",
                    ImportFlowModel.sectionsForImport(current, required),
                    AiImageImportApply.expandedSections(current, required),
                )
            }
        }
    }

    @Test
    fun `所需节次与 ImportFlowModel 同输入同结果`() {
        val courseLists: List<List<Course>> = listOf(
            emptyList(),
            listOf(course(2)),
            listOf(course(2), course(9)),
            listOf(course(12), course(3)),
        )
        for (courses in courseLists) {
            assertEquals(
                "课程 ${courses.map { it.endSection }} 的最大节次不一致",
                ImportFlowModel.requiredSectionCount(courses),
                AiImageImportApply.requiredSectionCount(courses),
            )
        }
    }

    @Test
    fun `守卫确实覆盖三种配额情形`() {
        // 反过来验证这张表本身没被改成「永远只测一侧」：
        // 6 节现状下，required = 5/6 不该扩、7/12 要扩。
        val six = sections(6)
        assertEquals(false, AiImageImportApply.needsExpansion(six, 5))
        assertEquals(false, AiImageImportApply.needsExpansion(six, 6))
        assertEquals(true, AiImageImportApply.needsExpansion(six, 7))
        assertEquals(true, AiImageImportApply.needsExpansion(six, 12))
    }
}
