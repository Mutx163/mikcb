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
