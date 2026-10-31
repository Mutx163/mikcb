package com.mutx163.qingyu.pages.task

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 任务模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * ## 为什么补这个文件
 *
 * 审核 `docs/plans/2026-10-29-quality-audit/misc-wiring.md` P2-2：`TaskStrings.kt`
 * 的类注释写着「通过单元测试逐条对拍」，但仓库里 **34 个 `*StringsParityTest` 里
 * 一个 task 的都没有**——注释在说一件没有的事（rubric 判「文档失真」）。
 * 同域的 `ScheduleStringsParityTest` / `ExamStringsParityTest` 早就有，只有 task 缺。
 *
 * ## 这张表为什么是手写的
 *
 * `TaskStrings` 用的是 `const val` 而不是其它域的 `ArbText` 包装，没有可遍历的
 * `allTexts` 列表；`const val` 也不会出现在 Kotlin 反射的成员属性里。
 * 所以这里用**显式对照表**：新增一条常量时，若忘了往表里加，本测试不会自动红
 * （这是与其它域 parity 测试同样的已知边界），但只要表里有，改名/改值就一定红。
 *
 * ## 日期量纲标签（2026-10-30 起不再是例外）
 *
 * `datePickerYear` / `datePickerMonth` / `datePickerDay` 原先在 ARB 里没有独立键，
 * 只能做「钉住当前值」的弱断言；六份 ARB 补键后，三条已改成与其它文案一样的逐字对拍
 * （见 `日期量纲标签与 ARB 逐字一致`）。
 */
class TaskStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    /** 「ARB 键 → 屏上值」对照表。键名与 `TaskStrings` 里的常量名**同名**。 */
    private val pairs: List<Pair<String, String>> = listOf(
        "taskListTitle" to TaskStrings.taskListTitle,
        "addTask" to TaskStrings.addTask,
        "editTask" to TaskStrings.editTask,
        "saveTask" to TaskStrings.saveTask,
        "taskTitleLabel" to TaskStrings.taskTitleLabel,
        "taskTitleHint" to TaskStrings.taskTitleHint,
        "taskTitleRequired" to TaskStrings.taskTitleRequired,
        "taskNoteLabel" to TaskStrings.taskNoteLabel,
        "taskNoteHint" to TaskStrings.taskNoteHint,
        "taskDueDateLabel" to TaskStrings.taskDueDateLabel,
        "taskNoDueDate" to TaskStrings.taskNoDueDate,
        "taskDueDateHint" to TaskStrings.taskDueDateHint,
        "taskUndatedHintSubtitle" to TaskStrings.taskUndatedHintSubtitle,
        "taskCourseLabel" to TaskStrings.taskCourseLabel,
        "taskCourseFilter" to TaskStrings.taskCourseFilter,
        "taskAllCourses" to TaskStrings.taskAllCourses,
        "taskNoCourse" to TaskStrings.taskNoCourse,
        "taskAllFilter" to TaskStrings.taskAllFilter,
        "taskTodayFilter" to TaskStrings.taskTodayFilter,
        "taskWeekFilter" to TaskStrings.taskWeekFilter,
        "taskOverdueSection" to TaskStrings.taskOverdueSection,
        "taskCompletedSection" to TaskStrings.taskCompletedSection,
        "taskNoTasks" to TaskStrings.taskNoTasks,
        "taskNoTasksForToday" to TaskStrings.taskNoTasksForToday,
        "taskNoTasksForWeek" to TaskStrings.taskNoTasksForWeek,
        "taskNoTasksForCourse" to TaskStrings.taskNoTasksForCourse,
        "taskDelete" to TaskStrings.taskDelete,
        "taskDeleteConfirm" to TaskStrings.taskDeleteConfirm,
        "taskHomeworkDefaultTitle" to TaskStrings.taskHomeworkDefaultTitle,
        "taskAddFromCourse" to TaskStrings.taskAddFromCourse,
        "taskViewCourse" to TaskStrings.taskViewCourse,
        "taskSaved" to TaskStrings.taskSaved,
        "taskUpdated" to TaskStrings.taskUpdated,
        "taskDeleted" to TaskStrings.taskDeleted,
        "saveFailed" to TaskStrings.saveFailed,
        "cancelAction" to TaskStrings.cancelAction,
        "deleteAction" to TaskStrings.deleteAction,
        "confirmAction" to TaskStrings.confirmAction,
        "serviceMsgLinkedCourseNotFound" to TaskStrings.serviceMsgLinkedCourseNotFound,
    )

    @Test
    fun `每一条任务文案都与 app_zh_arb 逐字一致`() {
        assertTrue("对照表不应少于 39 条，当前 ${pairs.size}", pairs.size >= 39)
        for ((key, value) in pairs) {
            val template = arbMap[key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `$key`", template != null)
            assertMatchesArb(key, value, template!!)
        }
    }

    @Test
    fun `带占位符的渲染函数与 ARB 模板对得上`() {
        // taskUndatedHint：ARB 是「{count} 条作业没设日期」。
        assertMatchesArb("taskUndatedHint", TaskStrings.taskUndatedHint(3), arbMap.getValue("taskUndatedHint"))
        assertEquals("3 条作业没设日期", TaskStrings.taskUndatedHint(3))

        // weekLabel：ARB 是「第 {week} 周」。
        assertMatchesArb("weekLabel", TaskStrings.weekLabel(7), arbMap.getValue("weekLabel"))
        assertEquals("第 7 周", TaskStrings.weekLabel(7))

        assertMatchesArb(
            "dayTaskBandCountSummary",
            TaskStrings.dayTaskBandCountSummary(5),
            arbMap.getValue("dayTaskBandCountSummary"),
        )
        assertMatchesArb(
            "dayTaskBandOverdueBadge",
            TaskStrings.dayTaskBandOverdueBadge(2),
            arbMap.getValue("dayTaskBandOverdueBadge"),
        )
        assertMatchesArb(
            "dayTaskBandOverdueMore",
            TaskStrings.dayTaskBandOverdueMore(4),
            arbMap.getValue("dayTaskBandOverdueMore"),
        )
    }

    /**
     * 日期量纲标签（年 / 月 / 日）：**已补 ARB 键，走逐字对拍**。
     *
     * 历史：2026-10-29 这三位在 ARB 里没有独立键，只能做「钉住当前值」的弱断言；
     * 2026-10-30 六份 ARB 已补 `datePickerYear` / `datePickerMonth` / `datePickerDay`
     * （考试页滚轮用同一组键），于是本条改成真对拍——那条「ARB 里不许出现」的
     * 反向断言已按它自己的提醒删掉。
     */
    @Test
    fun `日期量纲标签与 ARB 逐字一致`() {
        assertEquals(
            "datePickerYear 与 ARB 不一致",
            arbMap.getValue("datePickerYear"),
            TaskStrings.datePickerYear,
        )
        assertEquals(
            "datePickerMonth 与 ARB 不一致",
            arbMap.getValue("datePickerMonth"),
            TaskStrings.datePickerMonth,
        )
        assertEquals(
            "datePickerDay 与 ARB 不一致",
            arbMap.getValue("datePickerDay"),
            TaskStrings.datePickerDay,
        )
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "lib/l10n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 lib/l10n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
