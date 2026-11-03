package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableSettings
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 导入流程纯逻辑的行为测试（F07 · 2026-10-29）。
 *
 * 覆盖「选完文件之后」的每一步判断：覆盖 / 更新各写成什么样、节次够不够怎么算、
 * 随机配色怎么排、MIME 候选与体积文案。期望值按 Dart 源手推
 * （`import_export_logic.dart` 的 merge/replace、`ensureImportSectionCapacity` 的算术、
 * `import_random_color_preferences.dart` 的默认值），不从 Kotlin 实现里抄。
 */
class ImportFlowModelTest {

    private fun course(
        id: String,
        name: String = "高等数学",
        teacher: String = "张老师",
        location: String = "教学楼101",
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
        endWeek: Int = 16,
        color: String = "#2196F3",
    ): Course = Course(
        id = id,
        name = name,
        teacher = teacher,
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "08:45",
        endWeek = endWeek,
        color = color,
    )

    // ------------------------------------------------------------------
    // 覆盖 / 更新
    // ------------------------------------------------------------------

    @Test
    fun `覆盖导入只留导入侧课程`() {
        val existing = listOf(course("old-1", name = "旧课"), course("old-2", name = "另一门旧课"))
        val imported = listOf(course("new-1", name = "新课"))
        val plan = ImportFlowModel.planApply(
            existingCourses = existing,
            importedCourses = imported,
            replaceExisting = true,
            preserveLocalColors = true,
        )
        assertTrue(plan.replaceExisting)
        assertEquals(1, plan.courses.size)
        assertEquals("新课", plan.courses.single().name)
        // 覆盖导入的计数口径 = 落盘后总数（Dart `importOverwriteCount`）。
        assertEquals(1, plan.importedCount)
    }

    @Test
    fun `更新课表保留本地课程并只更新匹配到的那条`() {
        val existing = listOf(course("local-1"))
        val imported = listOf(course("imported-1"))
        val plan = ImportFlowModel.planApply(
            existingCourses = existing,
            importedCourses = imported,
            replaceExisting = false,
            preserveLocalColors = true,
        )
        assertFalse(plan.replaceExisting)
        assertEquals(1, plan.courses.size)
        // 软匹配保留本地 id（作业引用靠它），所以不是导入侧 id。
        assertEquals("local-1", plan.courses.single().id)
        assertEquals(0, plan.addedCount)
        assertEquals(1, plan.updatedCount)
        assertEquals(1, plan.importedCount)
    }

    @Test
    fun `更新课表把没匹配到的新课追加进来`() {
        val existing = listOf(course("local-1"))
        val imported = listOf(course("imported-1", name = "全新的课", dayOfWeek = 3))
        val plan = ImportFlowModel.planApply(
            existingCourses = existing,
            importedCourses = imported,
            replaceExisting = false,
            preserveLocalColors = true,
        )
        assertEquals(2, plan.courses.size)
        assertEquals(1, plan.addedCount)
        assertEquals(0, plan.updatedCount)
        assertEquals(1, plan.importedCount)
    }

    @Test
    fun `本地没有课时两条分支都只留导入内容`() {
        val imported = listOf(course("a"), course("b", name = "另一门"))
        for (replaceExisting in listOf(true, false)) {
            val plan = ImportFlowModel.planApply(
                existingCourses = emptyList(),
                importedCourses = imported,
                replaceExisting = replaceExisting,
                preserveLocalColors = true,
            )
            assertEquals(2, plan.courses.size)
            assertEquals(2, plan.importedCount)
        }
    }

    @Test
    fun `导入包里的重复条目只留一条`() {
        val duplicated = listOf(course("dup-1"), course("dup-2"))
        val plan = ImportFlowModel.planApply(
            existingCourses = emptyList(),
            importedCourses = duplicated,
            replaceExisting = true,
            preserveLocalColors = true,
        )
        assertEquals(1, plan.courses.size)
    }

    // ------------------------------------------------------------------
    // 节次容量
    // ------------------------------------------------------------------

    @Test
    fun `需要到第几节`() {
        assertEquals(0, ImportFlowModel.requiredSectionCount(emptyList()))
        assertEquals(
            10,
            ImportFlowModel.requiredSectionCount(
                listOf(course("a", endSection = 10), course("b", endSection = 4)),
            ),
        )
    }

    @Test
    fun `现有节次够用时不补`() {
        val current = TimetableSettings.DEFAULT_SECTIONS // 10 节
        assertFalse(ImportFlowModel.needsSectionExpansion(current, 10))
        assertTrue(ImportFlowModel.needsSectionExpansion(current, 11))
        assertEquals(current, ImportFlowModel.sectionsForImport(current, 10))
    }

    @Test
    fun `补节按最后一条的节长与课间往后接`() {
        val current = TimetableSettings.DEFAULT_SECTIONS // 末节 19:55-20:40
        val expanded = ImportFlowModel.sectionsForImport(current, 12)
        assertEquals(12, expanded.size)
        // 默认节次表的节长 45 分钟、课间 10 分钟（19:45 结束 → 19:55 开始）
        // ⇒ 第 11 节 20:50-21:35、第 12 节 21:45-22:30。
        assertEquals("20:50", expanded[10].startTime)
        assertEquals("21:35", expanded[10].endTime)
        assertEquals("21:45", expanded[11].startTime)
        assertEquals("22:30", expanded[11].endTime)
    }

    @Test
    fun `补节不会造出跨零点的节次`() {
        val almostFullDay = listOf(
            com.mutx163.qingyu.core.SectionTime("23:00", "23:45"),
        )
        val expanded = ImportFlowModel.sectionsForImport(almostFullDay, 6)
        // 23:45 + 10 分钟课间 = 23:55，+45 分钟 = 40 分（次日）⇒ 超 24:00 直接停。
        assertEquals(1, expanded.size)
    }

    // ------------------------------------------------------------------
    // 随机配色
    // ------------------------------------------------------------------

    @Test
    fun `关掉随机配色时课程颜色一动不动`() {
        val courses = listOf(course("a", color = "#123456"), course("b", name = "另一门", color = "#654321"))
        val result = ImportFlowModel.coursesWithOptionalRandomColors(
            courses = courses,
            prefs = ImportRandomColorPrefs(enabled = false, groupId = "ocean"),
            random = Random(7),
        )
        assertEquals(listOf("#123456", "#654321"), result.map { it.color })
        // 关掉时原样返回（连对象都不换）：覆盖导入要靠它保留本地课程颜色。
        assertSame(courses[0], result[0])
    }

    @Test
    fun `打开随机配色时只从选定颜色组里取色且同名同色`() {
        val courses = listOf(
            course("a", name = "高等数学", teacher = "张老师"),
            course("b", name = "高等数学", teacher = "张老师"),
            course("c", name = "大学英语", teacher = "李老师"),
        )
        val result = ImportFlowModel.coursesWithOptionalRandomColors(
            courses = courses,
            prefs = ImportRandomColorPrefs(enabled = true, groupId = "ocean"),
            random = Random(3),
        )
        val palette = ImportSharedModel.courseColorGroupPalette("ocean")
        for (item in result) {
            assertTrue("课程 ${item.name} 的颜色 ${item.color} 不在 ocean 组里", item.color in palette)
        }
        assertEquals("同名同教师必须共享一色", result[0].color, result[1].color)
        assertTrue("不同课程组应该取到不同色", result[0].color != result[2].color)
        // 没勾「文字色」⇒ 不写 textColor（Dart 默认 opt-in）。
        assertTrue(result.all { it.textColor == null })
    }

    @Test
    fun `勾了文字色时按背景亮度配可读墨色`() {
        val result = ImportFlowModel.coursesWithOptionalRandomColors(
            courses = listOf(course("a")),
            prefs = ImportRandomColorPrefs(enabled = true, groupId = "all", textColorEnabled = true),
            random = Random(11),
        )
        val textColor = result.single().textColor
        assertTrue("文字色应该被写上", textColor != null)
        assertEquals(
            ImportSharedModel.matchingCourseTextColorHex(result.single().color),
            textColor,
        )
    }

    @Test
    fun `覆盖导入时保不保留本地颜色取决于随机配色开关`() {
        // Dart `shouldPreserveLocalColorsOnImport` = !(replaceExisting && randomColorsEnabled)
        assertFalse(ImportFlowModel.shouldPreserveLocalColors(replaceExisting = true, randomColorsEnabled = true))
        assertTrue(ImportFlowModel.shouldPreserveLocalColors(replaceExisting = true, randomColorsEnabled = false))
        assertTrue(ImportFlowModel.shouldPreserveLocalColors(replaceExisting = false, randomColorsEnabled = true))
        assertTrue(ImportFlowModel.shouldPreserveLocalColors(replaceExisting = false, randomColorsEnabled = false))
    }

    // ------------------------------------------------------------------
    // SAF 候选与文案
    // ------------------------------------------------------------------

    @Test
    fun `扩展名判定`() {
        assertTrue(ImportFlowModel.isIcsFile("课表.ICS"))
        assertTrue(ImportFlowModel.isSpreadsheetFile("课表.xlsx"))
        assertTrue(ImportFlowModel.isSpreadsheetFile("课表.csv"))
        assertFalse(ImportFlowModel.isSpreadsheetFile("课表.ics"))
        assertFalse(ImportFlowModel.isIcsFile("课表"))
        assertFalse(ImportFlowModel.isXlsxFile("课表.csv"))
        assertEquals("", ImportFlowModel.extensionOf("没有后缀"))
        assertEquals("", ImportFlowModel.extensionOf("奇怪的.后缀."))
        assertEquals("csv", ImportFlowModel.extensionOf("带.点的.名字.CSV"))
    }

    @Test
    fun `选文件的 MIME 候选包含标准值且不放通配`() {
        assertTrue("text/calendar" in ImportFlowModel.ICS_MIME_TYPES)
        assertTrue(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" in
                ImportFlowModel.SPREADSHEET_MIME_TYPES,
        )
        assertTrue("text/csv" in ImportFlowModel.SPREADSHEET_MIME_TYPES)
        // 通配 `*/*` 等于把整个文件系统摊开给用户选，Dart 侧也只允许 .ics / 表格。
        assertFalse(ImportFlowModel.ICS_MIME_TYPES.contains("*/*"))
        assertFalse(ImportFlowModel.SPREADSHEET_MIME_TYPES.contains("*/*"))
    }

    @Test
    fun `体积上限文案与 Dart 同口径`() {
        assertEquals("20 MB", ImportFlowModel.formatSizeLimit(20 * 1024 * 1024))
        assertEquals("512 B", ImportFlowModel.formatSizeLimit(512))
    }

    // ------------------------------------------------------------------
    // 导入后置：学期总周数（Dart `importParsedCourses`）
    // ------------------------------------------------------------------

    @Test
    fun `学期总周数按导入课程抬升`() {
        // Dart：nextSemesterWeekCount = max(当前, maxCourseWeek(合并后课程))
        assertEquals(20, ImportFlowModel.nextSemesterWeekCount(20, emptyList()))
        assertEquals(25, ImportFlowModel.nextSemesterWeekCount(20, listOf(course("a", endWeek = 25))))
        assertEquals(16, ImportFlowModel.nextSemesterWeekCount(16, listOf(course("a", endWeek = 8))))
        assertEquals(30, ImportFlowModel.nextSemesterWeekCount(20, listOf(course("a", endWeek = 40))))
    }

    @Test
    fun `学期总周数只升不降 自定义周次也参与抬升`() {
        assertEquals(18, ImportFlowModel.nextSemesterWeekCount(18, listOf(course("a", endWeek = 16))))
        val custom = course("a", endWeek = 16).copy(customWeeks = listOf(1, 3, 21))
        assertEquals(21, ImportFlowModel.nextSemesterWeekCount(16, listOf(custom)))
        // 空课表保持当前值（不能落成 0）
        assertEquals(30, ImportFlowModel.nextSemesterWeekCount(30, emptyList()))
    }
}
