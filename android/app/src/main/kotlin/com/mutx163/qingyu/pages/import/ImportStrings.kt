package com.mutx163.qingyu.pages.import

/**
 * 导入域文案（P3-G1，import 域独占此文件）。
 *
 * **逐字抄录 `lib/l10n/app_zh.arb`，不许改写**：每一条都在
 * [ImportStringsParityTest] 里与 ARB 机械比对，键缺失或值被改写都会红。
 * 命名与 ARB 键逐字一致，便于 `grep` 双向核对。
 *
 * 覆盖四个来源页面的文案（照 `course_import_entry_screen.dart` /
 * `import_shared.dart` / `ics_course_import_screen.dart` /
 * `spreadsheet_course_import_screen.dart` / `course_auto_refresh_runner.dart` /
 * `home_pull_quick_import.dart` 里出现的 l10n 键抄全）。
 */
typealias ImportArbText = com.mutx163.qingyu.app.ArbText

fun String.filledImport(name: String, value: String): String = replace("{$name}", value)
object ImportStrings {

    // ── 导入入口页 (CourseImportScreen) ──
    val courseImportTitle = ImportArbText("courseImportTitle", "导入课程")
    val chooseImportMethodTitle = ImportArbText("chooseImportMethodTitle", "选择导入方式")
    val importMethodIcsTitle = ImportArbText("importMethodIcsTitle", ".ics 日历导入")
    val importMethodIcsSubtitle = ImportArbText("importMethodIcsSubtitle", "从其他课表应用导出的日历文件")
    val importMethodAiTitle = ImportArbText("importMethodAiTitle", "识图导入")
    val importMethodAiSubtitle = ImportArbText("importMethodAiSubtitle", "从课表截图识别并导入")
    val importMethodWarehouseTitle = ImportArbText("importMethodWarehouseTitle", "教务系统导入")
    val importMethodWarehouseSubtitle = ImportArbText("importMethodWarehouseSubtitle", "登录学校教务系统导入")
    val importMethodSpreadsheetTitle = ImportArbText("importMethodSpreadsheetTitle", "表格导入")
    val importMethodSpreadsheetSubtitle = ImportArbText("importMethodSpreadsheetSubtitle", "填写 Excel / CSV 模板后导入")

    // ── 随机配色开关（import_random_color_toggle.dart）──
    val importRandomCourseColorTitle = ImportArbText("importRandomCourseColorTitle", "随机课程颜色")
    val importRandomCourseColorSubtitle = ImportArbText("importRandomCourseColorSubtitle", "按课程名与教师自动分配预设色")
    val importRandomColorGroupTitle = ImportArbText("importRandomColorGroupTitle", "随机配色组")
    val colorGroupAll = ImportArbText("colorGroupAll", "全部颜色")
    val colorGroupPastel = ImportArbText("colorGroupPastel", "马卡龙系")
    val colorGroupVibrant = ImportArbText("colorGroupVibrant", "活泼系")
    val colorGroupDeep = ImportArbText("colorGroupDeep", "深色系")
    val colorGroupDopamine = ImportArbText("colorGroupDopamine", "多巴胺系")
    val colorGroupSunset = ImportArbText("colorGroupSunset", "落日系")
    val colorGroupOcean = ImportArbText("colorGroupOcean", "海洋系")

    // ── ICS 导入页 (IcsCourseImportScreen) ──
    val icsImportTitle = ImportArbText("icsImportTitle", ".ics 日历导入")
    val icsScenarioIntro = ImportArbText(
        "icsScenarioIntro",
        "如果你已经能在其他课表应用里导入教务系统课程，再导出为 .ics 文件，这条路最稳",
    )
    val icsStep1Subtitle = ImportArbText("icsStep1Subtitle", "先在其他课表应用里导出 .ics 日历文件")
    val icsStep2Subtitle = ImportArbText("icsStep2Subtitle", "在此选择文件，可追加导入或替换现有课程")
    val icsStep3Subtitle = ImportArbText("icsStep3Subtitle", "导入前还会让你确认开学日期，以及课表第 1 周对应校历第几周")
    val supportedFilesSuffix = ImportArbText("supportedFilesSuffix", "文件后缀必须是 .ics")
    val supportedFilesImageHint = ImportArbText("supportedFilesImageHint", "课表截图请返回上一页使用识图导入")
    val chooseIcsFileAction = ImportArbText("chooseIcsFileAction", "选择 .ics 文件")

    // ── 表格导入页 (SpreadsheetCourseImportScreen) ──
    val spreadsheetImportTitle = ImportArbText("spreadsheetImportTitle", "表格导入")
    val spreadsheetScenarioIntro = ImportArbText(
        "spreadsheetScenarioIntro",
        "轻屿模板按表头识别列：必填列是课程名、星期、开始节、结束节和周次，其余列可选。模板可整体下载，也可以只留必要列导入；WakeUp 的 7 列格式同样兼容。",
    )
    val spreadsheetStep1Subtitle = ImportArbText("spreadsheetStep1Subtitle", "下载完整模板填写，或仅填写必填列与上课周导入")
    val spreadsheetStep2Subtitle = ImportArbText("spreadsheetStep2Subtitle", "填写完成后另存为 .csv 或直接保留 .xlsx")
    val spreadsheetStep3Subtitle = ImportArbText("spreadsheetStep3Subtitle", "选择文件导入；如有识别提醒会先展示，再选择追加或替换")
    val spreadsheetSupportedFilesSuffix = ImportArbText("spreadsheetSupportedFilesSuffix", "支持 .csv 与 .xlsx，仅读取首个工作表")
    val downloadSpreadsheetTemplateAction = ImportArbText("downloadSpreadsheetTemplateAction", "下载轻屿课表模板")
    val chooseSpreadsheetFileAction = ImportArbText("chooseSpreadsheetFileAction", "选择表格文件")
    val spreadsheetImportWarningsTitle = ImportArbText("spreadsheetImportWarningsTitle", "导入提醒")
    val spreadsheetImportWarningsMessage = ImportArbText("spreadsheetImportWarningsMessage", "以下行未能导入，其余课程可继续：")
    val spreadsheetImportWarningsContinue = ImportArbText("spreadsheetImportWarningsContinue", "继续导入")

    // ── 导入引导面板（import_shared.dart: ImportGuidePanel）──
    val applicableScenarioTitle = ImportArbText("applicableScenarioTitle", "适用场景")
    val supportedFilesTitle = ImportArbText("supportedFilesTitle", "支持的文件")
    // ImportGuidePanel 的三步引导行标题（Dart `l10n.stepLabel('1')` → 圆形徽标里再去掉
    // 「步骤 」前缀只留数字）。前任落盘时漏收，渲染层需要，2026-10-27 续作补上。
    val stepLabel = ImportArbText("stepLabel", "步骤 {step}")

    // ── 文件与通用错误 ──
    val importFileReadFailed = ImportArbText("importFileReadFailed", "无法读取所选文件")
    val importFileTooLarge = ImportArbText("importFileTooLarge", "文件超出大小上限 {size}，请选择较小的文件")
    val importNoCoursesRecognized = ImportArbText("importNoCoursesRecognized", "未识别到可导入课程")
    val saveFailed = ImportArbText("saveFailed", "保存失败")

    // ── 替换选择 / 学期对齐（pickImportSemesterConfig / askImportReplaceExisting）──
    val importReplaceExistingTitle = ImportArbText("importReplaceExistingTitle", "导入课程")
    val importReplaceExistingMessage = ImportArbText(
        "importReplaceExistingMessage",
        "导入 {name} 时是否替换现有课程？此操作将同时清空自习等独立日程。",
    )
    // Dart 侧这句是写死在 `askImportReplaceExisting` 正文末尾的引导句（不在 Dart ARB）；
    // Compose 侧不能照抄硬编码——en/ja/ko/zh-TW 用户会看到中文，2026-11-02 补进六份 ARB。
    val importReplaceExistingGuidance = ImportArbText(
        "importReplaceExistingGuidance",
        "日常更新建议优先选择更新课表，保留本地独有课程并合并新课程",
    )
    val courseImportUpdateRecommendedAction = ImportArbText("courseImportUpdateRecommendedAction", "更新课表 推荐")
    val courseImportOverwriteAction = ImportArbText("courseImportOverwriteAction", "覆盖导入")
    val importConfirmSemesterMappingTitle = ImportArbText("importConfirmSemesterMappingTitle", "确认开学日期和周次对应")
    val importConfirmSemesterMappingSubtitleIcs = ImportArbText("importConfirmSemesterMappingSubtitleIcs", "周次已按文件里最早的上课日期预填")
    val importSemesterStartDateTitle = ImportArbText("importSemesterStartDateTitle", "开学日期")
    val importSemesterStartDateSubtitle = ImportArbText("importSemesterStartDateSubtitle", "按这一天所在周作为校历第 1 周")
    val importFirstCourseWeekMappingLabel = ImportArbText("importFirstCourseWeekMappingLabel", "第 1 周对应校历第几周")
    val importFirstCourseWeekMappingSubtitle = ImportArbText("importFirstCourseWeekMappingSubtitle", "如果第一周没课，就选第 2 周")
    val importSemesterMappingNoShiftHint = ImportArbText("importSemesterMappingNoShiftHint", "导入后会直接把课表第 1 周当作校历第 1 周")
    val importSemesterMappingShiftHint = ImportArbText(
        "importSemesterMappingShiftHint",
        "导入后会把所有课程周次整体顺延 {shiftedWeeks} 周，让课表第 1 周落在校历第 {calendarWeek} 周",
    )
    val calendarWeekOption = ImportArbText("calendarWeekOption", "校历第 {week} 周")

    // ── 节次容量（ensureImportSectionCapacity）──
    val courseImportSectionCountInsufficientTitle = ImportArbText("courseImportSectionCountInsufficientTitle", "时间模板节次不足")
    val courseImportSectionCountInsufficientMessage = ImportArbText(
        "courseImportSectionCountInsufficientMessage",
        "当前课表时间模板只有 {current} 节，但导入数据需要到第 {required} 节，是否自动补齐后继续导入？",
    )
    val courseImportAutoFillAndImportAction = ImportArbText("courseImportAutoFillAndImportAction", "自动补齐并导入")

    // ── 教务网址补填（promptImportWarehouseUrl）──
    val courseImportPortalUrlTitle = ImportArbText("courseImportPortalUrlTitle", "输入教务网址")
    val courseImportPortalUrlSaveContinue = ImportArbText("courseImportPortalUrlSaveContinue", "保存并继续")
    val courseImportPortalUrlMissingBody = ImportArbText(
        "courseImportPortalUrlMissingBody",
        "{schoolName} {adapterName} 无默认登录地址，请先输入教务系统网址",
    )
    val courseImportPortalUrlLabel = ImportArbText("courseImportPortalUrlLabel", "教务网址")
    val courseImportPortalUrlHint = ImportArbText("courseImportPortalUrlHint", "保存后下次会直接使用，也可以在适配器信息页里修改")
    val courseImportPortalUrlInvalid = ImportArbText("courseImportPortalUrlInvalid", "登录地址格式不正确")

    // ── 星期短名（importWeekdayLabel）──
    val weekdayShortMonday = ImportArbText("weekdayShortMonday", "一")
    val weekdayShortTuesday = ImportArbText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = ImportArbText("weekdayShortWednesday", "三")
    val weekdayShortThursday = ImportArbText("weekdayShortThursday", "四")
    val weekdayShortFriday = ImportArbText("weekdayShortFriday", "五")
    val weekdayShortSaturday = ImportArbText("weekdayShortSaturday", "六")
    val weekdayShortSunday = ImportArbText("weekdayShortSunday", "日")

    // ── 快捷导入 / 首页下拉（home_pull_quick_import.dart）──
    val noSavedQuickImportRecords = ImportArbText("noSavedQuickImportRecords", "暂无已保存的快捷导入记录")
    val noValidWarehouseLoginUrl = ImportArbText("noValidWarehouseLoginUrl", "未找到有效的教务登录地址")
    val quickImportUnknownError = ImportArbText("quickImportUnknownError", "发生未知错误")
    val quickImportTitle = ImportArbText("quickImportTitle", "快捷导入 - {name}")
    val courseImportQuickImportDescription = ImportArbText("courseImportQuickImportDescription", "快捷导入 {schoolName} {adapterName}")

    /**
     * 首页下拉快捷导入「更新中」那一拍的文字（Dart `homePullQuickImportFetchingCourses`）。
     *
     * 只在**转起来之后**才显示：拖动中与到阈值两拍故意不带字，免得收拢时闪一行字。
     */
    val homePullQuickImportFetchingCourses =
        ImportArbText("homePullQuickImportFetchingCourses", "正在获取新课程……")

    // ── 课表自动更新（course_auto_refresh_runner.dart）──
    val courseAutoRefreshUpdatedTip = ImportArbText("courseAutoRefreshUpdatedTip", "已自动更新课表")
    val courseAutoRefreshFailedTip = ImportArbText("courseAutoRefreshFailedTip", "自动更新没成功，可下拉重试")

    // ── 导入结果（buildImportResultMessage）──
    val importOverwriteCount = ImportArbText("importOverwriteCount", "已覆盖导入 {count} 条课程")
    val importUpdatedCount = ImportArbText("importUpdatedCount", "已更新课表：新增或更新 {count} 条课程")
    val importNoCourseChanges = ImportArbText("importNoCourseChanges", "没有需要新增或更新的课程")
    val aiWarningExtraSuffix = ImportArbText("aiWarningExtraSuffix", "，另有 {count} 条识别提醒")

    // ── 导入预览（确认对话框的「识别到 N 门课程」）──
    // Dart 侧这句话用在 AI 识图导入的预览确认上；ICS / 表格两条线原先各有自己的对话框链
    // （替换选择 → 学期映射 → 节次容量），Kotlin 侧合并成一张预览卡，计数句沿用同一条 ARB。
    val importCourseCountPrompt = ImportArbText("importCourseCountPrompt", "识别到 {count} 门课程，是否导入？")

    // ── 通用动作 ──
    val cancelAction = ImportArbText("cancelAction", "取消")

    /**
     * 所有 ARB 文案清单，用于机械化单测逐字对拍。
     *
     * 带占位符的键不提供同名插值函数（属性与函数同名会在对象内解析冲突），
     * 插值一律在调用点用 [ImportArbText.filled] 完成——与 ScheduleStrings 同一套做法。
     */
    val allTexts: List<ImportArbText> by lazy {
        listOf(
            courseImportTitle,
            chooseImportMethodTitle,
            importMethodIcsTitle,
            importMethodIcsSubtitle,
            importMethodAiTitle,
            importMethodAiSubtitle,
            importMethodWarehouseTitle,
            importMethodWarehouseSubtitle,
            importMethodSpreadsheetTitle,
            importMethodSpreadsheetSubtitle,
            importRandomCourseColorTitle,
            importRandomCourseColorSubtitle,
            importRandomColorGroupTitle,
            colorGroupAll,
            colorGroupPastel,
            colorGroupVibrant,
            colorGroupDeep,
            colorGroupDopamine,
            colorGroupSunset,
            colorGroupOcean,
            icsImportTitle,
            icsScenarioIntro,
            icsStep1Subtitle,
            icsStep2Subtitle,
            icsStep3Subtitle,
            supportedFilesSuffix,
            supportedFilesImageHint,
            chooseIcsFileAction,
            spreadsheetImportTitle,
            spreadsheetScenarioIntro,
            spreadsheetStep1Subtitle,
            spreadsheetStep2Subtitle,
            spreadsheetStep3Subtitle,
            spreadsheetSupportedFilesSuffix,
            downloadSpreadsheetTemplateAction,
            chooseSpreadsheetFileAction,
            spreadsheetImportWarningsTitle,
            spreadsheetImportWarningsMessage,
            spreadsheetImportWarningsContinue,
            applicableScenarioTitle,
            supportedFilesTitle,
            stepLabel,
            importFileReadFailed,
            importFileTooLarge,
            importNoCoursesRecognized,
            saveFailed,
            importReplaceExistingTitle,
            importReplaceExistingMessage,
            importReplaceExistingGuidance,
            courseImportUpdateRecommendedAction,
            courseImportOverwriteAction,
            importConfirmSemesterMappingTitle,
            importConfirmSemesterMappingSubtitleIcs,
            importSemesterStartDateTitle,
            importSemesterStartDateSubtitle,
            importFirstCourseWeekMappingLabel,
            importFirstCourseWeekMappingSubtitle,
            importSemesterMappingNoShiftHint,
            importSemesterMappingShiftHint,
            calendarWeekOption,
            courseImportSectionCountInsufficientTitle,
            courseImportSectionCountInsufficientMessage,
            courseImportAutoFillAndImportAction,
            courseImportPortalUrlTitle,
            courseImportPortalUrlSaveContinue,
            courseImportPortalUrlMissingBody,
            courseImportPortalUrlLabel,
            courseImportPortalUrlHint,
            courseImportPortalUrlInvalid,
            weekdayShortMonday,
            weekdayShortTuesday,
            weekdayShortWednesday,
            weekdayShortThursday,
            weekdayShortFriday,
            weekdayShortSaturday,
            weekdayShortSunday,
            noSavedQuickImportRecords,
            noValidWarehouseLoginUrl,
            quickImportUnknownError,
            quickImportTitle,
            courseImportQuickImportDescription,
            homePullQuickImportFetchingCourses,
            courseAutoRefreshUpdatedTip,
            courseAutoRefreshFailedTip,
            importOverwriteCount,
            importUpdatedCount,
            importNoCourseChanges,
            importCourseCountPrompt,
            aiWarningExtraSuffix,
            cancelAction,
        )
    }
}
