package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「已有教师 / 地点」接线的源级守卫（发布版 `add_course_screen.dart:917/:933`、
 * `course_followup_sheets.dart:421`）。
 *
 * 这条链最容易假完成：弹层做了、模型算了，但页面/壳忘了把候选传下去——按钮点开只有
 * 手输框，历史候选永远空。本守卫把「候选必须从注入参数一路传到弹层」钉在源码上：
 * - `AddCoursePage`：教师 / 地点候选参数存在、两处条目行与共享卡两行都接 `CourseFieldPickerSheet`，
 *   且传的是注入参数（不是空表）；
 * - `CourseFollowupSheets`：`CourseRescheduleSheet` 透传到地点子弹层，旧「等壳注入」注释不得回潮；
 * - `CourseActionSheet`：`locationSuggestions` 一路下传。
 *
 * 读源码走 `testutil` 共享剥离（2026-11-11 守卫迁移）：接线类判据用
 * [readKotlinSourceNoStrings]（剥注释 + 中性化字符串，字符串里写同名片段骗不过去）；
 * 「旧注释不许回潮」这条要看**注释原文**，所以单独走 [readSourceNormalized]——
 * 剥了注释再断言它不在，等于断言恒真。
 */
class CourseFieldSuggestionWiringGuardTest {

    @Test
    fun `加课页教师与地点都接选择弹层 候选来自注入参数`() {
        val source = pageSource("AddCoursePage.kt")
        assertTrue("缺少 teacherSuggestions 入参", source.contains("teacherSuggestions: List<String>"))
        assertTrue("缺少 locationSuggestions 入参", source.contains("locationSuggestions: List<String>"))
        assertTrue("教师/地点弹层必须走共享件", source.contains("CourseFieldPickerSheet("))
        assertTrue(
            "候选必须来自注入参数（不是空表/本地假数据）",
            source.contains("suggestions = if (pickerIsTeacher) teacherSuggestions else locationSuggestions"),
        )
        assertTrue(
            "条目教师行与地点行都要能开弹层",
            source.contains("onOpenTeacherPicker") && source.contains("onOpenLocationPicker"),
        )
        assertTrue(
            "共享信息卡两行也要接同一套弹层",
            source.contains("CourseFieldPickerTarget.Shared(teacher = true)") &&
                source.contains("CourseFieldPickerTarget.Shared(teacher = false)"),
        )
        assertFalse(
            "教师/地点不许退回纯手输 TextField（发布版这两处是选择行）",
            source.contains("value = sharedTeacher,") || source.contains("value = entry.teacher,"),
        )
    }

    @Test
    fun `调课弹层透传地点候选 旧注释不得回潮`() {
        val followup = pageSource("CourseFollowupSheets.kt")
        assertTrue("CourseRescheduleSheet 必须有 locationSuggestions 入参", followup.contains("locationSuggestions: List<String>"))
        assertTrue("地点子弹层必须收到候选", followup.contains("suggestions = locationSuggestions,"))
        assertFalse(
            "「等壳注入候选」的旧注释不许回来（说明契约又被挖空）",
            // 必须读未剥注释的原文：剥完注释再断言「这段注释不在」是恒真。
            readSourceNormalized(courseFile("CourseFollowupSheets.kt")).contains("等壳把候选注入进来"),
        )

        val action = pageSource("CourseActionSheet.kt")
        assertTrue("CourseActionSheet 也要有 locationSuggestions", action.contains("locationSuggestions: List<String>"))
        assertTrue("必须下传给调课弹层", action.contains("locationSuggestions = locationSuggestions,"))
    }

    /** 接线类判据：剥注释 + 中性化字符串，只留代码骨架。 */
    private fun pageSource(name: String): String = readKotlinSourceNoStrings(courseFile(name))

    private fun courseFile(name: String): String =
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/$name"
}
