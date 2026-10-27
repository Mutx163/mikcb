package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入共享逻辑纯函数测试（P3-G1 · import_shared.dart）。
 *
 * 期望值全部从 Dart 源手推（不抄实现），覆盖 TEST-POLICY「纯逻辑要用
 * 独立来源的期望值」与导入域的定向反例要求。
 */
class ImportSharedModelTest {

    // ==========================================
    // 随机配色开关的覆盖/保留判定
    // ==========================================

    @Test
    fun `shouldOverrideLocalColorsOnImport 只在覆盖且随机色开着时为真`() {
        // Dart: return replaceExisting && randomColorsEnabled;
        assertTrue(ImportSharedModel.shouldOverrideLocalColorsOnImport(true, true))
        assertFalse(ImportSharedModel.shouldOverrideLocalColorsOnImport(true, false))
        assertFalse(ImportSharedModel.shouldOverrideLocalColorsOnImport(false, true))
        assertFalse(ImportSharedModel.shouldOverrideLocalColorsOnImport(false, false))
    }

    @Test
    fun `shouldPreserveLocalColorsOnImport 与 override 互为补集`() {
        // 更新/下拉快捷导入一律保留本地颜色
        assertFalse(ImportSharedModel.shouldPreserveLocalColorsOnImport(true, true))
        assertTrue(ImportSharedModel.shouldPreserveLocalColorsOnImport(true, false))
        assertTrue(ImportSharedModel.shouldPreserveLocalColorsOnImport(false, true))
        assertTrue(ImportSharedModel.shouldPreserveLocalColorsOnImport(false, false))
    }

    // ==========================================
    // 日期 / 星期 / 字节预算格式化
    // ==========================================

    @Test
    fun `importFormatDate 输出补零的 yyyy-MM-dd`() {
        assertEquals(
            "2026-03-02",
            ImportSharedModel.importFormatDate(java.time.LocalDateTime.of(2026, 3, 2, 8, 0)),
        )
        assertEquals(
            "2026-11-05",
            ImportSharedModel.importFormatDate(java.time.LocalDateTime.of(2026, 11, 5, 0, 0)),
        )
    }

    @Test
    fun `importWeekdayLabel 一到日 越界回数字`() {
        assertEquals("一", ImportSharedModel.importWeekdayLabel(1))
        assertEquals("二", ImportSharedModel.importWeekdayLabel(2))
        assertEquals("三", ImportSharedModel.importWeekdayLabel(3))
        assertEquals("四", ImportSharedModel.importWeekdayLabel(4))
        assertEquals("五", ImportSharedModel.importWeekdayLabel(5))
        assertEquals("六", ImportSharedModel.importWeekdayLabel(6))
        assertEquals("日", ImportSharedModel.importWeekdayLabel(7))
        // Dart switch 落到 default：dayOfWeek.toString()
        assertEquals("0", ImportSharedModel.importWeekdayLabel(0))
        assertEquals("9", ImportSharedModel.importWeekdayLabel(9))
    }

    @Test
    fun `formatByteBudget 按字节量折算单位`() {
        assertEquals("20 MB", ImportSharedModel.formatByteBudget(20L * 1024 * 1024))
        assertEquals("20 MB", ImportSharedModel.formatByteBudget(20L * 1024 * 1024 + 1))
        assertEquals("1 KB", ImportSharedModel.formatByteBudget(1024L))
        assertEquals("2 KB", ImportSharedModel.formatByteBudget(2047L))
        assertEquals("512 B", ImportSharedModel.formatByteBudget(512L))
        assertEquals("0 B", ImportSharedModel.formatByteBudget(0L))
    }

    // ==========================================
    // 预览周次摘要（importPreviewWeekSummary）
    // ==========================================

    @Test
    fun `importPreviewWeekSummary 空周次回未提供`() {
        assertEquals("未提供", ImportSharedModel.importPreviewWeekSummary(emptyList(), "、", "未提供") { "" })
    }

    @Test
    fun `importPreviewWeekSummary 六周以内逐个列出`() {
        assertEquals(
            "1、3、5",
            ImportSharedModel.importPreviewWeekSummary(listOf(1, 3, 5), "、", "未提供") { "" },
        )
        assertEquals(
            "1、2、3、4、5、6",
            ImportSharedModel.importPreviewWeekSummary((1..6).toList(), "、", "未提供") { "" },
        )
    }

    @Test
    fun `importPreviewWeekSummary 超长周次折成范围加总数`() {
        // Dart: '${weeks.first}-${weeks.last} · ${weeksCountLabel(weeks.length)}'
        assertEquals(
            "1-16 · 共 16 周",
            ImportSharedModel.importPreviewWeekSummary((1..16).toList(), "、", "未提供") { n -> "共 $n 周" },
        )
    }

    // ==========================================
    // 节次 JSON 按位对齐解码（decodeAlignedImportedSections）
    // ==========================================

    @Test
    fun `decodeAlignedImportedSections 非列表返回 null`() {
        assertNull(ImportSharedModel.decodeAlignedImportedSections("not a list"))
        assertNull(ImportSharedModel.decodeAlignedImportedSections(null))
    }

    @Test
    fun `decodeAlignedImportedSections 空表或全坏返回 null`() {
        assertNull(ImportSharedModel.decodeAlignedImportedSections(emptyList<Any?>()))
        // 整表皆坏（healedCount == size）→ null
        assertNull(
            ImportSharedModel.decodeAlignedImportedSections(
                listOf(mapOf<String, Any?>("startTime" to "08:00")), // 缺 endTime → 坏条目
            ),
        )
    }

    @Test
    fun `decodeAlignedImportedSections 坏位补空不前移`() {
        // 好条目 + 坏条目：坏位留空，绝不让后面的节次时间前移一档
        val decoded = listOf(
            mapOf<String, Any?>("startTime" to "08:00", "endTime" to "08:45"),
            mapOf<String, Any?>("oops" to 1),
        )
        val sections = ImportSharedModel.decodeAlignedImportedSections(decoded)
        assertTrue(sections != null)
        assertEquals(2, sections!!.size)
        assertEquals(SectionTime("08:00", "08:45"), sections[0])
        assertEquals(SectionTime("", ""), sections[1])
    }

    // ==========================================
    // 导入完成 Toast 文案（buildImportResultMessage）
    // ==========================================

    @Test
    fun `buildImportResultMessage 覆盖与更新按计数出文案`() {
        assertEquals("已覆盖导入 3 条课程", ImportSharedModel.buildImportResultMessage(3, true))
        assertEquals(
            "已更新课表：新增或更新 3 条课程",
            ImportSharedModel.buildImportResultMessage(3, false),
        )
    }

    @Test
    fun `buildImportResultMessage 无变化兜底`() {
        assertEquals("没有需要新增或更新的课程", ImportSharedModel.buildImportResultMessage(0, true))
        assertEquals("没有需要新增或更新的课程", ImportSharedModel.buildImportResultMessage(0, false))
    }

    @Test
    fun `buildImportResultMessage 警告后缀拼接`() {
        assertEquals(
            "已覆盖导入 3 条课程，另有 2 条识别提醒",
            ImportSharedModel.buildImportResultMessage(3, true, 2),
        )
        assertEquals(
            "没有需要新增或更新的课程，另有 2 条识别提醒",
            ImportSharedModel.buildImportResultMessage(0, false, 2),
        )
    }

    // ==========================================
    // 随机取色（applyRandomImportCourseColors）
    // ==========================================

    private fun course(id: String, name: String, teacher: String): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = "教学楼101",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "08:45",
        color = "#2196F3",
    )

    @Test
    fun `applyRandomImportCourseColors 空课表原样返回`() {
        val result = ImportSharedModel.applyRandomImportCourseColors(emptyList(), random = kotlin.random.Random(1))
        assertTrue(result.isEmpty())
    }

    @Test
    fun `applyRandomImportCourseColors 同名同教师共享一色`() {
        val courses = listOf(
            course("c1", "高等数学", "李老师"),
            course("c2", "高等数学", "李老师"),
            course("c3", "大学英语", "王老师"),
        )
        val result = ImportSharedModel.applyRandomImportCourseColors(courses, random = kotlin.random.Random(7))
        assertEquals(result[0].color, result[1].color)
        assertTrue(result[0].color != result[2].color)
        // 颜色必须来自预设色板
        assertTrue(ImportSharedModel.PRESET_COURSE_COLOR_HEXES.contains(result[0].color))
    }

    @Test
    fun `applyRandomImportCourseColors 分组键做空白归一`() {
        // Dart _normalizeImportColorKeyPart: trim + 连续空白折叠成单空格
        val key1 = ImportSharedModel.buildImportCourseColorGroupKey("  高等  数学 ", "李老师")
        val key2 = ImportSharedModel.buildImportCourseColorGroupKey("高等 数学", " 李老师 ")
        assertEquals(key1, key2)
    }

    @Test
    fun `applyRandomImportCourseColors 开文字色后按亮度配墨`() {
        val courses = listOf(course("c1", "高等数学", "李老师"))
        val result = ImportSharedModel.applyRandomImportCourseColors(
            courses,
            assignMatchingTextColor = true,
            random = kotlin.random.Random(3),
        )
        assertEquals(ImportSharedModel.matchingCourseTextColorHex(result[0].color), result[0].textColor)
    }

    @Test
    fun `applyRandomImportCourseColors 自定义分组键按名字共享`() {
        // groupKeyBuilder：只按名字分组（重新配色场景的「同名同色」不变式）
        val courses = listOf(
            course("c1", "高等数学", "李老师"),
            course("c2", "高等数学", "王老师"),
        )
        val result = ImportSharedModel.applyRandomImportCourseColors(
            courses,
            random = kotlin.random.Random(11),
            groupKeyBuilder = { it.name },
        )
        assertEquals(result[0].color, result[1].color)
    }

    @Test
    fun `matchingCourseTextColorHex 按 BT601 亮度取墨色`() {
        // 手推：#FCA5A5 → (0.299*252 + 0.587*165 + 0.114*181)/255 ≈ 0.756 > 0.6 → 深墨
        assertEquals("#1F1F1F", ImportSharedModel.matchingCourseTextColorHex("#FCA5A5"))
        // 手推：#B91C1C → (0.299*185 + 0.587*28 + 0.114*28)/255 ≈ 0.294 → 白
        assertEquals("#FFFFFF", ImportSharedModel.matchingCourseTextColorHex("#B91C1C"))
        // 手推：#2196F3 → (0.299*33 + 0.587*150 + 0.114*243)/255 ≈ 0.493 → 白
        assertEquals("#FFFFFF", ImportSharedModel.matchingCourseTextColorHex("#2196F3"))
        // 长度不足 6：直接白
        assertEquals("#FFFFFF", ImportSharedModel.matchingCourseTextColorHex("#FFF"))
        assertEquals("#FFFFFF", ImportSharedModel.matchingCourseTextColorHex("no"))
    }

    // ==========================================
    // 颜色组
    // ==========================================

    @Test
    fun `courseColorGroupPalette all 与未知 id 都回落全量色板`() {
        assertEquals(ImportSharedModel.PRESET_COURSE_COLOR_HEXES, ImportSharedModel.courseColorGroupPalette("all"))
        assertEquals(ImportSharedModel.PRESET_COURSE_COLOR_HEXES, ImportSharedModel.courseColorGroupPalette("legacy-gone"))
        assertTrue(
            ImportSharedModel.courseColorGroupPalette("pastel").size < ImportSharedModel.PRESET_COURSE_COLOR_HEXES.size,
        )
    }

    @Test
    fun `colorGroupDisplayName 与 ARB 组名对齐`() {
        assertEquals("全部颜色", ImportSharedModel.colorGroupDisplayName("all"))
        assertEquals("马卡龙系", ImportSharedModel.colorGroupDisplayName("pastel"))
        assertEquals("活泼系", ImportSharedModel.colorGroupDisplayName("vibrant"))
        assertEquals("深色系", ImportSharedModel.colorGroupDisplayName("deep"))
        assertEquals("多巴胺系", ImportSharedModel.colorGroupDisplayName("dopamine"))
        assertEquals("落日系", ImportSharedModel.colorGroupDisplayName("sunset"))
        assertEquals("海洋系", ImportSharedModel.colorGroupDisplayName("ocean"))
        // Dart switch 无命中回落 colorGroupAll
        assertEquals("全部颜色", ImportSharedModel.colorGroupDisplayName("nonsense"))
    }

    // ==========================================
    // 学期周次对齐（ImportWeekAlignmentService）
    // ==========================================

    private val semesterStart = java.time.LocalDateTime.of(2026, 3, 2, 0, 0) // 周一

    @Test
    fun `inferFirstCourseWeek 按日历日跨周推算`() {
        val alignment = ImportWeekAlignment
        assertEquals(1, alignment.inferFirstCourseWeek(semesterStart, semesterStart))
        // 3/8 是**周日**，其所在周的周一仍是 3/2 → 差 0 天 → 第 1 周
        // （Dart import_week_alignment_service.dart:11-23：按 startOfWeek 取周一再算整周差）
        assertEquals(1, alignment.inferFirstCourseWeek(semesterStart, java.time.LocalDateTime.of(2026, 3, 8, 8, 0)))
        // 3/9 才是下一个周一 → 差 7 天 → 第 2 周
        assertEquals(2, alignment.inferFirstCourseWeek(semesterStart, java.time.LocalDateTime.of(2026, 3, 9, 8, 0)))
        assertEquals(3, alignment.inferFirstCourseWeek(semesterStart, java.time.LocalDateTime.of(2026, 3, 16, 0, 0)))
        // 早于开学日 → 1
        assertEquals(1, alignment.inferFirstCourseWeek(semesterStart, java.time.LocalDateTime.of(2026, 2, 23, 0, 0)))
    }

    @Test
    fun `shiftCoursesToSemesterWeeks 零偏移原样返回`() {
        val courses = listOf(course("c1", "高等数学", "李老师"))
        val result = ImportWeekAlignment.shiftCoursesToSemesterWeeks(courses, firstCourseWeek = 1)
        assertEquals(courses, result)
    }

    @Test
    fun `shiftCoursesToSemesterWeeks 自定义周整体顺延并清单双周标志`() {
        val base = course("c1", "高等数学", "李老师").copy(
            startWeek = 1,
            endWeek = 3,
            customWeeks = listOf(1, 3),
            isOddWeek = true,
        )
        val result = ImportWeekAlignment.shiftCoursesToSemesterWeeks(listOf(base), firstCourseWeek = 3)
        assertEquals(1, result.size)
        assertEquals(listOf(3, 5), result[0].normalizedCustomWeeks)
        assertEquals(3, result[0].startWeek)
        assertEquals(5, result[0].endWeek)
        assertFalse(result[0].isOddWeek)
        assertFalse(result[0].isEvenWeek)
    }

    @Test
    fun `shiftCoursesToSemesterWeeks 奇偏移翻转单双周`() {
        val base = course("c1", "高等数学", "李老师").copy(
            startWeek = 1,
            endWeek = 8,
            isOddWeek = true,
        )
        val result = ImportWeekAlignment.shiftCoursesToSemesterWeeks(listOf(base), firstCourseWeek = 2)
        assertEquals(2, result[0].startWeek)
        assertEquals(9, result[0].endWeek)
        // flipParity: isOdd -> isEven
        assertFalse(result[0].isOddWeek)
        assertTrue(result[0].isEvenWeek)
    }
}
