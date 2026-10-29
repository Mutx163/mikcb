package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.Course

/**
 * 备注弹层的两段输入（Dart `_CourseNoteSheetBodyState` 的两个 `TextEditingController`）。
 *
 * 这里故意只装**用户可编辑的文本**：`hasHomework`（「本节有作业」）不在这条链上，
 * 见 [CourseNoteModel] 的类注释。
 */
data class CourseNoteDraft(
    val wholeNote: String = "",
    val sessionNote: String = "",
) {
    /** 保存载荷：两段都走「`trim()` 后空串 → `null`」（Dart `course_note_sheet.dart:158-160`）。 */
    val savePayload: CourseNoteSave
        get() = CourseNoteSave(
            wholeNote = CourseNoteModel.normalize(wholeNote),
            sessionNote = CourseNoteModel.normalize(sessionNote),
        )
}

/**
 * 交给宿主的保存载荷：**只有文本**，两个字段都可为 `null`（= 该段被清空）。
 *
 * ## `hasHomework` 必须由宿主保留原值（**本层不碰**）
 *
 * Dart 保存时（`course_note_sheet.dart:160-168`）把本周备注重建为
 * `CourseSessionNote(text = 新文本, hasHomework = 原值)`，再 `withSessionNote(week, …)`：
 *
 * ```dart
 * final existingHomework = current.sessionNoteForWeek(week)?.hasHomework ?? false;
 * final sessionNote = CourseSessionNote(text: sessionNoteText, hasHomework: existingHomework).normalizedOrNull;
 * ```
 *
 * 原因写在 Dart 源码里：作业已经拆成独立入口，「本节有作业」是作业表单写的字段；
 * 备注弹层若写死 `false`，用户只改一句备注就会把本周的作业标记悄悄清掉，
 * 对应的 `homeworkMark` 作业下次重算时消失。
 *
 * ⇒ 壳（Lead 接线处）落库时**必须**照 Dart 做：
 * `course.withSessionNote(week, CourseSessionNote(text = sessionNote ?: "", hasHomework = 旧值))`，
 * 而不是 `CourseSessionNote(text = sessionNote ?: "")`（后者 `hasHomework` 默认 `false`）。
 */
data class CourseNoteSave(
    val wholeNote: String?,
    val sessionNote: String?,
)

/**
 * 课程备注弹层的**纯 Kotlin** 模型层（JVM 可测，禁 import `android.*` / `androidx.compose.*` /
 * `top.yukonga.miuix.*`）。对应 Dart `lib/widgets/course_note_sheet.dart` 的
 * `initState`（初始值）、`_save`（载荷归一化）与 `build` 里的副标题拼装。
 *
 * 渲染层 `CourseNoteSheet.kt` 只画不算：初值、副标题、只读门控、载荷归一化全在这里，
 * 这样这四条口径都能被 `CourseNoteModelTest` 用**手推的期望值**钉住。
 */
object CourseNoteModel {

    /**
     * 打开弹层时的两段初值（Dart `course_note_sheet.dart:70-86`）。
     *
     * - 课程简介：`course.description` 去空白后非空 → 用它（**已 trim**）；
     *   否则回落 legacy `course.note`（Dart 这一支 **不 trim**，原样给输入框，
     *   保真大于整洁：老数据里手打的缩进不会被悄悄吞掉）；
     * - 本节备注：`course.sessionNoteForWeek(week)?.text`，没有就是空串。
     */
    fun initialDraft(course: Course?, week: Int): CourseNoteDraft = CourseNoteDraft(
        wholeNote = initialWholeNote(course),
        sessionNote = initialSessionNote(course, week),
    )

    /** 课程简介初值：`description` 优先（trim 后非空），否则回落 legacy `note`。 */
    fun initialWholeNote(course: Course?): String {
        if (course == null) return ""
        val description = course.description?.trim()
        if (!description.isNullOrEmpty()) return description
        return course.note ?: ""
    }

    /** 本节课备注初值：只取本周那一条的文本；别的周、没有备注都是空串。 */
    fun initialSessionNote(course: Course?, week: Int): String =
        course?.sessionNoteForWeek(week)?.text ?: ""

    /**
     * 保存载荷归一化：`trim()` 后空串 → `null`（Dart `:158-160` 的 `trim()` +
     * 后续 `CourseSessionNote.normalizedOrNull` 的「文本空就算清空」口径）。
     *
     * 注意这里**只归一化文本**：本周备注是否整条存在还取决于 `hasHomework`（见
     * [CourseNoteSave]），所以「文本空 + 有作业」不是删除整条备注，而是「保留作业标记、
     * 清掉文字」——那一步由宿主用 `CourseSessionNote(text, hasHomework = 旧值).normalizedOrNull` 完成。
     */
    fun normalize(text: String): String? = text.trim().ifEmpty { null }

    /** 只读门控：`readOnly`（对方课程）时输入框禁编辑、底部无「保存」。Dart `:150` 直接 return。 */
    fun isEditable(readOnly: Boolean): Boolean = !readOnly

    /**
     * 头部副标题：`课名 · 第N周 · 第A-B节`（Dart `course_note_sheet.dart:214-216`）。
     *
     * 两段周次/节次文案走 ARB 模板（[CourseNoteStrings.weekText] /
     * [CourseNoteStrings.sectionRangeText]），分隔符与 Dart 一样是 ` · `（空格 + 中点 + 空格）。
     */
    fun subtitle(course: Course, week: Int): String =
        listOf(
            course.name,
            CourseNoteStrings.weekText(week),
            CourseNoteStrings.sectionRangeText(course.startSection, course.endSection),
        ).joinToString(" · ")
}
