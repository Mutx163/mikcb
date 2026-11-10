package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「哪些周上」弹层的**常驻组合**守卫（2026-11-03 建立）。
 *
 * 原来宿主写成 `if (openDraft != null && weekDraftEntryId != null) { AddCourseWeekPickerDialog(...) }`
 * ——数据存在性当挂载开关，官方退场动画一次都播不出来（与 2026-11-02 弹层债同一条口径）。
 * 正确配方：弹层常驻组合、`show` 显式驱动、内部 `rememberLastNonNull` 钉住退场期草稿。
 *
 * composeP1 源集不进 `src/test` 的编译单元，所以读源码文本（与 `TimetableProfilesDialogGuardTest`
 * 同一套做法）；找不到文件判失败而不是跳过。
 */
class AddCoursePageMountGuardTest {

    @Test
    fun `周选择弹层必须常驻组合 显隐只由 show 驱动`() {
        val source = pageSource()
        assertFalse(
            "禁止用数据存在性当挂载开关：`if (openDraft != null …)` 会让退场动画一次都播不出来",
            source.contains("if (openDraft != null"),
        )
        assertFalse(
            "`weekDraftEntryId != null` 也不许再作为挂载条件",
            source.contains("if (openDraft != null && weekDraftEntryId != null)"),
        )
        assertTrue(
            "弹层必须常驻组合，显隐由 `show = weekDraft != null && weekDraftEntryId != null` 驱动",
            source.contains("show = weekDraft != null && weekDraftEntryId != null"),
        )
        assertTrue(
            "退场动画期间要用 `rememberLastNonNull` 钉住最后一份草稿",
            source.contains("rememberLastNonNull(draftOrNull)"),
        )
    }

    @Test
    fun `放弃修改弹层必须常驻组合 显隐只由 show 驱动`() {
        val source = pageSource()
        // 行首锚定：注释里提到 `if (confirmDiscard)` 不会假红/假绿。
        assertFalse(
            "禁止条件挂载：`if (confirmDiscard) { OverlayDialog(show = true) }` 会在关闭瞬间" +
                "把整棵弹层摘出组合，官方退场动画一次都播不出来",
            conditionalMount("confirmDiscard").containsMatchIn(source),
        )
        assertTrue(
            "放弃修改弹层必须常驻组合，显隐由 `show = confirmDiscard` 驱动",
            source.contains("show = confirmDiscard"),
        )
        assertFalse(
            "组件常驻后不许再写死 `show = true`",
            Regex("""^\s*show = true""", RegexOption.MULTILINE).containsMatchIn(source),
        )
    }

    @Test
    fun `删除课程确认弹层必须常驻组合 显隐只由 show 驱动`() {
        val source = pageSource()
        assertFalse(
            "禁止条件挂载：`if (confirmDelete && isEditing) { OverlayDialog(show = true) }` " +
                "会让退场动画一次都播不出来",
            conditionalMount("confirmDelete && isEditing").containsMatchIn(source),
        )
        assertTrue(
            "删除确认弹层必须常驻组合，显隐由 `show = confirmDelete && isEditing` 驱动",
            source.contains("show = confirmDelete && isEditing"),
        )
    }

    /** 行首锚定的条件挂载判据：注释 / KDoc 里的同名字样不算命中。 */
    private fun conditionalMount(condition: String): Regex =
        Regex("""^\s*if \(${Regex.escape(condition)}\) \{""", RegexOption.MULTILINE)

    @Test
    fun `壳必须把沿用课程与教师地点候选传进加课页`() {
        val source = shellIndexSource()
        assertTrue(
            "壳必须传 courseTemplates（不传的话「沿用已有课程」按钮会退化成死按钮）",
            source.contains("courseTemplates = snapshot.courses"),
        )
        assertTrue("教师候选必须接线", source.contains("teacherSuggestions = courseFieldSuggestions.teachers"))
        assertTrue("地点候选必须接线", source.contains("locationSuggestions = courseFieldSuggestions.locations"))
        assertTrue(
            "候选必须由 CourseFieldSuggestionLogic 从课程 + 日程算出，不许写死",
            source.contains("CourseFieldSuggestionLogic.build("),
        )
        assertFalse("不许把候选写成空表冒充接线", source.contains("teacherSuggestions = emptyList()"))
    }

    /** 壳页索引：`ShellPageIndex.kt`（课程域宿主接线，读源码判，不上编译单元）。 */
    private fun shellIndexSource(): String {
        val file = File(
            androidSrc(),
            "main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        return file.readText().replace("\r\n", "\n")
    }

    private fun pageSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        return file.readText().replace("\r\n", "\n")
    }

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }
}
