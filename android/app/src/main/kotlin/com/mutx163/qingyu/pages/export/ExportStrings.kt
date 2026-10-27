package com.mutx163.qingyu.pages.export

/**
 * 导出（ICS 日历 / 系统日历同步）模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [ExportStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 键名与 ARB 键逐字一致（`icsExportTitle` 等），便于 `grep` 双向核对。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

object ExportStrings {

    // ── 导出日历页 (IcsExportScreen) ──
    /** 数据迁移页里那一行的标题（同时也作页面标题）。 */
    val icsExportSectionTitle = ArbText("icsExportSectionTitle", "导出日历")
    val icsExportTitle = ArbText("icsExportTitle", "导出日历")
    val icsExportProfileLabel = ArbText("icsExportProfileLabel", "课表")
    val icsExportDateRangeTitle = ArbText("icsExportDateRangeTitle", "日期范围")
    val icsExportStartDate = ArbText("icsExportStartDate", "开始日期")
    val icsExportEndDate = ArbText("icsExportEndDate", "结束日期")
    val icsExportTypesTitle = ArbText("icsExportTypesTitle", "日历内容")
    val icsExportCourses = ArbText("icsExportCourses", "课程")
    val icsExportExams = ArbText("icsExportExams", "考试")
    val icsExportSchedules = ArbText("icsExportSchedules", "日程")
    val icsExportSkipHolidayCourses = ArbText("icsExportSkipHolidayCourses", "跳过节假日课程")
    val icsExportSkipHolidayCoursesSubtitle =
        ArbText("icsExportSkipHolidayCoursesSubtitle", "调休休息日也跳过，上班日仍导出")
    val icsExportSkipHolidayCoursesOn =
        ArbText("icsExportSkipHolidayCoursesOn", "已跳过节假日课程")

    // ── 导出按钮与产出 ──
    val icsExportButton = ArbText("icsExportButton", "导出并分享")
    val icsExportSharing = ArbText("icsExportSharing", "准备日历……")
    val icsExportShared = ArbText("icsExportShared", "已导出并分享 {count} 个日历事件")
    val icsExportShareText = ArbText("icsExportShareText", "这是来自轻屿课表的日历文件")
    val icsExportShareSubject = ArbText("icsExportShareSubject", "轻屿课表日历")
    val icsExportActionShare = ArbText("icsExportActionShare", "分享给别人")
    val icsExportActionSave = ArbText("icsExportActionSave", "保存到手机目录")
    val icsExportSavedCount = ArbText("icsExportSavedCount", "日历已保存，共 {count} 个事件")
    val icsExportSaveCancelled = ArbText("icsExportSaveCancelled", "已取消保存日历")
    val icsExportSaveFailed = ArbText("icsExportSaveFailed", "日历保存失败，请稍后重试")

    // ── 校验与失败提示 ──
    val icsExportNoProfiles = ArbText("icsExportNoProfiles", "暂无可导出的课表")
    val icsExportDateRangeInvalid = ArbText("icsExportDateRangeInvalid", "请选择不早于开始日期的结束日期")
    val icsExportNoSelection = ArbText("icsExportNoSelection", "至少选择一种日历内容")
    val icsExportSemesterStartRequired =
        ArbText("icsExportSemesterStartRequired", "导出课程前，请先设置学期开始日期")
    val icsExportNoEvents = ArbText("icsExportNoEvents", "所选日期范围内没有日历事件")
    val icsExportCancelled = ArbText("icsExportCancelled", "已取消分享日历")
    val icsExportFailed = ArbText("icsExportFailed", "日历导出失败，请稍后重试")

    // ── 同步到系统日历 ──
    val icsExportSyncCalendarButton = ArbText("icsExportSyncCalendarButton", "同步到系统日历")
    val icsExportSyncCalendarTitle = ArbText("icsExportSyncCalendarTitle", "同步到系统日历")
    val icsExportSyncCalendarBody = ArbText(
        "icsExportSyncCalendarBody",
        "将在系统日历中创建日历 {calendarName} 并同步所选日程，重复同步将覆盖旧数据。首次同步需要日历权限。",
    )
    val icsExportSyncCalendarConfirm = ArbText("icsExportSyncCalendarConfirm", "开始同步")
    val icsExportSyncCalendarName = ArbText("icsExportSyncCalendarName", "轻屿课表·{profileName}")
    val icsExportSyncCalendarSuccess =
        ArbText("icsExportSyncCalendarSuccess", "已同步 {count} 个日程到系统日历")
    val icsExportSyncCalendarSkipped =
        ArbText("icsExportSyncCalendarSkipped", "已跳过假期中的 {count} 个课程")
    val icsExportSyncCalendarPermissionDenied =
        ArbText("icsExportSyncCalendarPermissionDenied", "未获得日历权限，请在系统设置中允许后重试")
    val icsExportSyncCalendarFailed =
        ArbText("icsExportSyncCalendarFailed", "同步到系统日历失败，请稍后重试")

    // ── 移除已同步日程 ──
    val icsExportRemoveCalendarButton = ArbText("icsExportRemoveCalendarButton", "移除已同步的日程")
    val icsExportRemoveCalendarTitle = ArbText("icsExportRemoveCalendarTitle", "移除已同步的日程")
    val icsExportRemoveCalendarBody = ArbText(
        "icsExportRemoveCalendarBody",
        "将从系统日历中移除轻屿课表专属日历及全部日程，其他日程不受影响。",
    )
    val icsExportRemoveCalendarConfirm = ArbText("icsExportRemoveCalendarConfirm", "移除")
    val icsExportRemoveCalendarSuccess =
        ArbText("icsExportRemoveCalendarSuccess", "已从系统日历移除全部同步日程")
    val icsExportRemoveCalendarNothing = ArbText("icsExportRemoveCalendarNothing", "还没有同步过日程")
    val icsExportRemoveCalendarFailed = ArbText("icsExportRemoveCalendarFailed", "移除失败，请稍后重试")

    // ── 通用按钮 ──
    val cancelAction = ArbText("cancelAction", "取消")

    /** 全部上屏文案（`ExportStringsParityTest` 逐条与 ARB 对拍）。 */
    val allTexts: List<ArbText> = listOf(
        icsExportSectionTitle,
        icsExportTitle,
        icsExportProfileLabel,
        icsExportDateRangeTitle,
        icsExportStartDate,
        icsExportEndDate,
        icsExportTypesTitle,
        icsExportCourses,
        icsExportExams,
        icsExportSchedules,
        icsExportSkipHolidayCourses,
        icsExportSkipHolidayCoursesSubtitle,
        icsExportSkipHolidayCoursesOn,
        icsExportButton,
        icsExportSharing,
        icsExportShared,
        icsExportShareText,
        icsExportShareSubject,
        icsExportActionShare,
        icsExportActionSave,
        icsExportSavedCount,
        icsExportSaveCancelled,
        icsExportSaveFailed,
        icsExportNoProfiles,
        icsExportDateRangeInvalid,
        icsExportNoSelection,
        icsExportSemesterStartRequired,
        icsExportNoEvents,
        icsExportCancelled,
        icsExportFailed,
        icsExportSyncCalendarButton,
        icsExportSyncCalendarTitle,
        icsExportSyncCalendarBody,
        icsExportSyncCalendarConfirm,
        icsExportSyncCalendarName,
        icsExportSyncCalendarSuccess,
        icsExportSyncCalendarSkipped,
        icsExportSyncCalendarPermissionDenied,
        icsExportSyncCalendarFailed,
        icsExportRemoveCalendarButton,
        icsExportRemoveCalendarTitle,
        icsExportRemoveCalendarBody,
        icsExportRemoveCalendarConfirm,
        icsExportRemoveCalendarSuccess,
        icsExportRemoveCalendarNothing,
        icsExportRemoveCalendarFailed,
        cancelAction,
    )
}
