package com.mutx163.qingyu.pages.course

/**
 * 课程备注弹层（Dart `lib/widgets/course_note_sheet.dart`）用到的 ARB 文案。
 *
 * **逐字抄录，不许改写**：每一条都在 [CourseNoteStringsParityTest] 里与
 * `lib/l10n/app_zh.arb` 机械比对（键缺失、值被改写、占位符分段丢失都会红）。
 * 要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，再同步这里。
 *
 * 命名与 ARB 键逐字一致（`courseNoteSheetTitle` 等），便于 `grep` 双向核对。
 * 复用同包 [ArbText]（定义在 `CourseOverviewStrings.kt:15`），**不重复定义**。
 *
 * ## 谁用哪几条
 *
 * | 键 | 用在哪 |
 * |---|---|
 * | `courseNoteSheetTitle` | 弹层头部标题（`course_note_sheet.dart:254`） |
 * | `courseNoteWholeCourse*` | 第一段「课程简介」的标题 / 说明 / 占位（`:272-281`） |
 * | `courseNoteSession*` | 第二段「本节课备注」的标题 / 说明（含 `{week}`）/ 占位（`:292-301`） |
 * | `courseNoteReadOnlyNotice` | 只读态底部提示（`:311`） |
 * | `cancelAction` / `courseNoteSaveAction` | 底部两个按钮（`:318` / `:330`） |
 * | `weekLabel` / `sectionRangeLabel` | 头部副标题「课名 · 第N周 · 第A-B节」（`:214-216`） |
 * | `courseNoteAction` | **弹层外的「备注」详情行标题**（Dart `course_action_sheet.dart:939`，S 泳道用） |
 * | `courseNoteTabWholeCourse` / `courseNoteTabThisSession` | 编辑课程页的两段页签（同族键，留位不新增） |
 * | `courseNoteDoneEditingAction` | 只读态收尾按钮（同族键，留位不新增） |
 * | `saveFailed` | 保存失败提示（**壳**在用，Dart `course_note_sheet.dart:193`） |
 *
 * 本轮**不新增任何 ARB 键**；上表全部是 `app_zh.arb` 里已有的键。
 */
object CourseNoteStrings {

    // ── 弹层头部 ──
    val courseNoteSheetTitle = ArbText("courseNoteSheetTitle", "课程备注")

    // ── 第一段：课程简介（同名课程共享）──
    val courseNoteWholeCourseLabel = ArbText("courseNoteWholeCourseLabel", "课程简介")
    val courseNoteWholeCourseHint = ArbText(
        "courseNoteWholeCourseHint",
        "同名课程共享并长期保留，如课堂说明或要求。",
    )
    val courseNoteWholeCoursePlaceholder = ArbText(
        "courseNoteWholeCoursePlaceholder",
        "例如：这位教师容易点名、教室在新楼……",
    )

    // ── 第二段：本节课备注（只对本周有效）──
    val courseNoteSessionLabel = ArbText("courseNoteSessionLabel", "本节课备注")
    val courseNoteSessionHint = ArbText(
        "courseNoteSessionHint",
        "仅对第 {week} 周这一次课生效，适合记录携带物品或课堂提醒。",
    )
    val courseNoteSessionPlaceholder = ArbText(
        "courseNoteSessionPlaceholder",
        "例如：带电脑、换教室、记得带计算器……",
    )

    // ── 只读（对方课程）──
    val courseNoteReadOnlyNotice = ArbText("courseNoteReadOnlyNotice", "对方课程仅可查看备注，无法编辑。")
    val courseNoteDoneEditingAction = ArbText("courseNoteDoneEditingAction", "完成")

    // ── 底部按钮 ──
    val courseNoteSaveAction = ArbText("courseNoteSaveAction", "保存")
    val cancelAction = ArbText("cancelAction", "取消")

    // ── 副标题的两个片段（Dart `course_note_sheet.dart:214-216` 直接拼）──
    val weekLabel = ArbText("weekLabel", "第 {week} 周")
    val sectionRangeLabel = ArbText("sectionRangeLabel", "第 {startSection}～{endSection} 节")

    // ── 弹层外的「备注」详情行（Dart `course_action_sheet.dart:939`，S 泳道接这一行）──
    val courseNoteAction = ArbText("courseNoteAction", "备注")
    val courseNoteTileSubtitleEmpty = ArbText("courseNoteTileSubtitleEmpty", "记录携带物品或课堂提醒")
    val courseNoteTileSubtitleWhole = ArbText("courseNoteTileSubtitleWhole", "已有课程简介")
    val courseNoteTileSubtitleSession = ArbText("courseNoteTileSubtitleSession", "已有本节课备注")
    val courseNoteTileSubtitleBoth = ArbText("courseNoteTileSubtitleBoth", "课程简介与本节课均有备注")

    // ── 编辑课程页的同族页签（同一族键，留位）──
    val courseNoteTabWholeCourse = ArbText("courseNoteTabWholeCourse", "课程简介")
    val courseNoteTabThisSession = ArbText("courseNoteTabThisSession", "本节课")

    // ── 壳在用（保存失败 toast）──
    val saveFailed = ArbText("saveFailed", "保存失败")

    /** 「第 N 周」；`weekLabel` 的占位符填充（Dart `l10n.weekLabel(week)`）。 */
    fun weekText(week: Int): String = weekLabel.filled("week", week.toString())

    /** 「第 A～B 节」；Dart `l10n.sectionRangeLabel(start, end)`。 */
    fun sectionRangeText(startSection: Int, endSection: Int): String =
        sectionRangeLabel.filled(
            "startSection" to startSection.toString(),
            "endSection" to endSection.toString(),
        )

    /** 「本节课备注」的说明句；Dart `l10n.courseNoteSessionHint(week)`。 */
    fun sessionHint(week: Int): String =
        courseNoteSessionHint.filled("week", week.toString())

    /** 所有对接 ARB 的文案集合（Parity 测试用）。 */
    val allTexts: List<ArbText> = listOf(
        courseNoteSheetTitle,
        courseNoteWholeCourseLabel,
        courseNoteWholeCourseHint,
        courseNoteWholeCoursePlaceholder,
        courseNoteSessionLabel,
        courseNoteSessionHint,
        courseNoteSessionPlaceholder,
        courseNoteReadOnlyNotice,
        courseNoteDoneEditingAction,
        courseNoteSaveAction,
        cancelAction,
        weekLabel,
        sectionRangeLabel,
        courseNoteAction,
        courseNoteTileSubtitleEmpty,
        courseNoteTileSubtitleWhole,
        courseNoteTileSubtitleSession,
        courseNoteTileSubtitleBoth,
        courseNoteTabWholeCourse,
        courseNoteTabThisSession,
        saveFailed,
    )
}
