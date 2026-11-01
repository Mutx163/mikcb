package com.mutx163.qingyu.pages.import.warehouse

/**
 * 导入·仓库适配域文案（P3-G2，import/warehouse 独占此文件）。
 *
 * **逐字抄录 `lib/l10n/app_zh.arb`，不许改写**：每一条都在
 * [WarehouseStringsParityTest] 里与 ARB 机械比对，键缺失或值被改写都会红。
 * 覆盖仓库适配、学校适配器、网页登录、宏录制、自定义调试与 AI 识图导入共 8 件 Dart 页面中的 ARB 文案。
 */
data class WarehouseArbText(val key: String, val zh: String) {
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)
    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

fun String.filled(name: String, value: String): String = replace("{$name}", value)

object WarehouseStrings {
    val adapterInfoTitle = WarehouseArbText("adapterInfoTitle", "适配器信息")
    val adapterIntroSubtitle = WarehouseArbText("adapterIntroSubtitle", "可查看适配器信息、登录入口与脚本状态")
    val adapterOverrideImportUrlHint = WarehouseArbText("adapterOverrideImportUrlHint", "当前使用你手动覆盖的登录地址")
    val addDebugRecordAction = WarehouseArbText("addDebugRecordAction", "新增调试记录")
    val addDebugRecordTitle = WarehouseArbText("addDebugRecordTitle", "新增调试记录")
    val addDebugRecordTooltip = WarehouseArbText("addDebugRecordTooltip", "新增调试记录")
    val aiExpertModeSuggestion = WarehouseArbText("aiExpertModeSuggestion", "建议豆包专家模式，支持多图，截图需带星期表头")
    val aiImportTitle = WarehouseArbText("aiImportTitle", "识图导入")
    val aiParseErrorTitle = WarehouseArbText("aiParseErrorTitle", "解析错误")
    val aiParseFailedChip = WarehouseArbText("aiParseFailedChip", "解析失败")
    val aiParseFailedIncompleteJson = WarehouseArbText("aiParseFailedIncompleteJson", "解析失败，请确认粘贴的是完整 JSON")
    val aiPasteJsonFirst = WarehouseArbText("aiPasteJsonFirst", "请先粘贴 AI 返回的 JSON")
    val aiPasteJsonHintLong = WarehouseArbText("aiPasteJsonHintLong", "把豆包返回的 JSON 原样粘贴到这里，然后点击导入，支持纯 JSON，也兼容 ```json 代码块")
    val aiPasteJsonHintShort = WarehouseArbText("aiPasteJsonHintShort", "粘贴 AI 返回的 JSON")
    val aiPasteJsonTitle = WarehouseArbText("aiPasteJsonTitle", "粘贴 AI 返回的 JSON")
    val aiPreviewCourseCount = WarehouseArbText("aiPreviewCourseCount", "课程数量：{count}")
    val aiPreviewCoursesTitle = WarehouseArbText("aiPreviewCoursesTitle", "课程预览")
    val aiPreviewMaxSection = WarehouseArbText("aiPreviewMaxSection", "最大节次：第 {section} 节")
    val aiPreviewRemainingCourses = WarehouseArbText("aiPreviewRemainingCourses", "其余 {count} 条将在导入后写入当前课表")
    val aiPreviewSummary = WarehouseArbText("aiPreviewSummary", "识别到 {courseCount} 门课，最高到第 {sectionCount} 节 {warningSuffix}")
    val aiPreviewTitle = WarehouseArbText("aiPreviewTitle", "解析预览")
    val aiPreviewWarningsTitle = WarehouseArbText("aiPreviewWarningsTitle", "识别提醒")
    val aiPromptSheetSubtitle = WarehouseArbText("aiPromptSheetSubtitle", "建议使用豆包，先把豆包左下角切换为专家模式，再把下面整段提示词和课表截图一起发过去，让它只返回 JSON，生成后把 JSON 复制回本页，点击导入后再选择开学日期")
    val aiPromptSheetTitle = WarehouseArbText("aiPromptSheetTitle", "识图提示词")
    val aiPromptShortAction = WarehouseArbText("aiPromptShortAction", "提示词")
    val aiWarningCountSuffix = WarehouseArbText("aiWarningCountSuffix", "，{count} 条提醒")
    val aiWorkflowSubtitle = WarehouseArbText("aiWorkflowSubtitle", "先复制提示词，再到豆包左下角切换为专家模式，把课表截图和提示词一起发过去，把豆包返回的 JSON 复制回这里，点击导入后再选择开学日期")
    val aiWorkflowTitle = WarehouseArbText("aiWorkflowTitle", "复制提示词 -> 豆包识图 -> 粘贴 JSON -> 导入")
    val applyReturnedTimeSchemeFailed = WarehouseArbText("applyReturnedTimeSchemeFailed", "应用返回的节次模板失败：{error}")
    val autofillAction = WarehouseArbText("autofillAction", "自动填充")
    val autofillLoginMessage = WarehouseArbText("autofillLoginMessage", "检测到已记住账号 {username}，是否自动填充？")
    val autofillLoginTitle = WarehouseArbText("autofillLoginTitle", "自动填充登录信息")
    val availableWeeksCount = WarehouseArbText("availableWeeksCount", "共 {count} 周")
    val cancelAction = WarehouseArbText("cancelAction", "取消")
    val categoryLabel = WarehouseArbText("categoryLabel", "类别")
    val clearAction = WarehouseArbText("clearAction", "清空")
    val clearCustomLoginAddressAction = WarehouseArbText("clearCustomLoginAddressAction", "清除自定义地址")
    val clearRememberedTooltip = WarehouseArbText("clearRememberedTooltip", "清除已记住账号")
    val clearSearchTooltip = WarehouseArbText("clearSearchTooltip", "清空")
    val clipboardNoText = WarehouseArbText("clipboardNoText", "剪贴板里没有可用文本")
    val confirmImportAction = WarehouseArbText("confirmImportAction", "确认导入")
    val copiedCurrentAddress = WarehouseArbText("copiedCurrentAddress", "已复制当前地址")
    val copiedImportLoginUrl = WarehouseArbText("copiedImportLoginUrl", "已复制教务登录地址")
    val copiedScriptRawUrl = WarehouseArbText("copiedScriptRawUrl", "已复制脚本原始地址")
    val copyAddress = WarehouseArbText("copyAddress", "复制地址")
    val copyCurrentAddressTooltip = WarehouseArbText("copyCurrentAddressTooltip", "复制当前地址")
    val copyLoginAddressAction = WarehouseArbText("copyLoginAddressAction", "复制登录地址")
    val copyScriptAddressAction = WarehouseArbText("copyScriptAddressAction", "复制脚本地址")
    val courseImportAutoRecordingStartedTip = WarehouseArbText("courseImportAutoRecordingStartedTip", "已在后台记录操作，导入成功后可保存为快捷导入")
    val courseImportLocationNotFilled = WarehouseArbText("courseImportLocationNotFilled", "未填写地点")
    val courseImportPreviewLine = WarehouseArbText("courseImportPreviewLine", "周 {weekday} 第 {startSection}～{endSection} 节  {name}  {location}  周次：{weekText}")
    val courseImportRecordingEmptyStatus = WarehouseArbText("courseImportRecordingEmptyStatus", "未录制到任何操作")
    val courseImportRecordingEmptyTip = WarehouseArbText("courseImportRecordingEmptyTip", "未录制到任何操作")
    val courseImportRecordingSavedStatus = WarehouseArbText("courseImportRecordingSavedStatus", "录制已保存，共 {count} 步")
    val courseImportRecordingStartedTip = WarehouseArbText("courseImportRecordingStartedTip", "录制已开始，请按正常流程操作教务网站")
    val courseImportRecordingStatus = WarehouseArbText("courseImportRecordingStatus", "录制中……点击停止完成录制")
    val courseImportSaveAutoRecordingMessage = WarehouseArbText("courseImportSaveAutoRecordingMessage", "导入成功。已记录 {count} 个操作步骤，是否保存本次导入路径，以便下次快捷导入？")
    val courseImportSaveRecordingMessage = WarehouseArbText("courseImportSaveRecordingMessage", "录制了 {count} 个操作步骤，是否保存为快捷导入？")
    val courseImportSaveRecordingTitle = WarehouseArbText("courseImportSaveRecordingTitle", "保存录制")
    val courseImportScriptFailed = WarehouseArbText("courseImportScriptFailed", "脚本执行失败")
    val courseImportWeekNotProvided = WarehouseArbText("courseImportWeekNotProvided", "未提供周次")
    val customDebugIntroSubtitle = WarehouseArbText("customDebugIntroSubtitle", "保存每所学校的网址与脚本，下次一键复用")
    val customDebugIntroTitle = WarehouseArbText("customDebugIntroTitle", "这里放你自己的教务调试记录")
    val customLoginAddressAction = WarehouseArbText("customLoginAddressAction", "自定义登录地址")
    val debugRecordFormula = WarehouseArbText("debugRecordFormula", "一条记录 = 一个网址 + 一段脚本")
    val debugRecordNameHint = WarehouseArbText("debugRecordNameHint", "例如：重庆机电-新版教务")
    val debugRecordNameLabel = WarehouseArbText("debugRecordNameLabel", "记录名称")
    val debugRecordNameRequired = WarehouseArbText("debugRecordNameRequired", "请先填写调试记录名称")
    val debugScriptHint = WarehouseArbText("debugScriptHint", "把浏览器扩展导出的完整脚本粘贴到这里")
    val debugScriptLabel = WarehouseArbText("debugScriptLabel", "调试脚本")
    val debugScriptLength = WarehouseArbText("debugScriptLength", "脚本 {count} 字符")
    val debugScriptRequired = WarehouseArbText("debugScriptRequired", "请先填写或导入脚本")
    val defaultContinuePrompt = WarehouseArbText("defaultContinuePrompt", "请按提示继续操作")
    val deleteAction = WarehouseArbText("deleteAction", "删除")
    val deleteDebugRecordMessage = WarehouseArbText("deleteDebugRecordMessage", "确认删除记录 {name}？已导入课程不受影响")
    val deleteDebugRecordTitle = WarehouseArbText("deleteDebugRecordTitle", "删除调试记录")
    val deletedDebugRecord = WarehouseArbText("deletedDebugRecord", "已删除调试记录：{name}")
    val dontRememberAction = WarehouseArbText("dontRememberAction", "不记住")
    val editAction = WarehouseArbText("editAction", "编辑")
    val editCustomLoginAddressAction = WarehouseArbText("editCustomLoginAddressAction", "修改自定义地址")
    val editDebugRecordTitle = WarehouseArbText("editDebugRecordTitle", "编辑调试记录")
    val executeFailedWithError = WarehouseArbText("executeFailedWithError", "执行失败：{error}")
    val executeImportScriptAction = WarehouseArbText("executeImportScriptAction", "执行导入脚本")
    val executeLocalDebugScriptAction = WarehouseArbText("executeLocalDebugScriptAction", "执行本地调试脚本")
    val fillRememberedTooltip = WarehouseArbText("fillRememberedTooltip", "填充已记住账号")
    val fillUrlThenImport = WarehouseArbText("fillUrlThenImport", "填写网址后导入")
    val fillUrlThenRecord = WarehouseArbText("fillUrlThenRecord", "填写网址后录制")
    val goAction = WarehouseArbText("goAction", "前往")
    val goFeedbackAction = WarehouseArbText("goFeedbackAction", "去反馈页")
    val homeWidgetDescriptionTitle = WarehouseArbText("homeWidgetDescriptionTitle", "说明")
    val importAiReplaceMessage = WarehouseArbText("importAiReplaceMessage", "是否使用解析结果替换现有课程？此操作将同时清空自习等独立日程。")
    val importAiResultTitle = WarehouseArbText("importAiResultTitle", "导入 AI 解析结果")
    val importCleartextBlockedHint = WarehouseArbText("importCleartextBlockedHint", "该站点暂不支持 HTTPS 访问且未在明文白名单内，无法在此打开")
    val importConfirmSemesterMappingTitle = WarehouseArbText("importConfirmSemesterMappingTitle", "确认开学日期和周次对应")
    val importCourseRecordsDropped = WarehouseArbText("importCourseRecordsDropped", "共收到 {imported} 门课程，其中 {dropped} 门数据有误未能导入")
    val importCourseWeeksTrimmed = WarehouseArbText("importCourseWeeksTrimmed", "另有 {count} 门课的部分周次没能识别，请对照教务系统核对")
    val importFileTooLarge = WarehouseArbText("importFileTooLarge", "文件超出大小上限 {size}，请选择较小的文件")
    val importFailedStatus = WarehouseArbText("importFailedStatus", "导入失败")
    val importFromFileAction = WarehouseArbText("importFromFileAction", "从文件导入")
    val importMethodAiTitle = WarehouseArbText("importMethodAiTitle", "识图导入")
    val importMethodWarehouseTitle = WarehouseArbText("importMethodWarehouseTitle", "教务系统导入")
    val importNoCourseChanges = WarehouseArbText("importNoCourseChanges", "没有需要新增或更新的课程")
    val importOverwriteCount = WarehouseArbText("importOverwriteCount", "已覆盖导入 {count} 条课程")
    val importReplaceExistingTitle = WarehouseArbText("importReplaceExistingTitle", "导入课程")
    val importUpdatedCount = WarehouseArbText("importUpdatedCount", "已更新课表：新增或更新 {count} 条课程")
    val importUrlLabel = WarehouseArbText("importUrlLabel", "教务网址")
    val importingAction = WarehouseArbText("importingAction", "导入中……")
    val injectingAdapterScript = WarehouseArbText("injectingAdapterScript", "正在注入适配器脚本")
    val injectingLocalDebugScript = WarehouseArbText("injectingLocalDebugScript", "正在注入本地调试脚本")
    val invalidCourseDataFormat = WarehouseArbText("invalidCourseDataFormat", "课程数据格式不正确")
    val noImportableCoursesFromScript = WarehouseArbText("noImportableCoursesFromScript", "脚本未返回可导入课程")
    val inputRequiredTitle = WarehouseArbText("inputRequiredTitle", "需要输入")
    val invalidImportUrl = WarehouseArbText("invalidImportUrl", "请输入有效的教务网址")
    val laterAction = WarehouseArbText("laterAction", "稍后再说")
    val localDebugModeScriptStatus = WarehouseArbText("localDebugModeScriptStatus", "本地调试模式：{scriptName}")
    val loginEntryLabel = WarehouseArbText("loginEntryLabel", "登录入口")
    val maintainerLabel = WarehouseArbText("maintainerLabel", "适配者")
    val moreActionsTooltip = WarehouseArbText("moreActionsTooltip", "更多操作")
    val noAvailableSchools = WarehouseArbText("noAvailableSchools", "暂无可用学校")
    val noMacroRecordFound = WarehouseArbText("noMacroRecordFound", "未找到录制记录，请先完成一次录制")
    val noMatchingSchools = WarehouseArbText("noMatchingSchools", "没有找到匹配的学校或适配器")
    val noRecognizedLoginInputs = WarehouseArbText("noRecognizedLoginInputs", "未识别到登录输入项")
    val noSavedDebugRecords = WarehouseArbText("noSavedDebugRecords", "还没有保存的调试记录")
    val noSavedDebugRecordsHint = WarehouseArbText("noSavedDebugRecordsHint", "先新增一条，把网址和脚本贴进去，以后就能直接复用")
    val noSavedQuickImportRecords = WarehouseArbText("noSavedQuickImportRecords", "暂无已保存的快捷导入记录")
    val noUsernameOrPasswordRecognized = WarehouseArbText("noUsernameOrPasswordRecognized", "未识别到用户名或密码")
    val noValidWarehouseLoginUrl = WarehouseArbText("noValidWarehouseLoginUrl", "未找到有效的教务登录地址")
    val notNowAction = WarehouseArbText("notNowAction", "暂不")
    val openInSystemBrowserAction = WarehouseArbText("openInSystemBrowserAction", "系统浏览器打开")
    val openLoginInAppAction = WarehouseArbText("openLoginInAppAction", "应用内打开登录入口")
    val pasteAction = WarehouseArbText("pasteAction", "粘贴")
    val pleaseChooseTitle = WarehouseArbText("pleaseChooseTitle", "请选择")
    val pleaseEnterFourDigitYear = WarehouseArbText("pleaseEnterFourDigitYear", "请输入 4 位年份")
    val previewAction = WarehouseArbText("previewAction", "预览")
    val promptCopiedHint = WarehouseArbText("promptCopiedHint", "提示词已复制，去豆包发送截图和提示词")
    val quickImportAction = WarehouseArbText("quickImportAction", "快捷导入")
    val quickImportDismissAction = WarehouseArbText("quickImportDismissAction", "完成")
    val quickImportFinishedTitle = WarehouseArbText("quickImportFinishedTitle", "导入完成")
    val quickImportMacroSteps = WarehouseArbText("quickImportMacroSteps", "{adapterName} · {stepCount} 步")
    val quickImportTitle = WarehouseArbText("quickImportTitle", "快捷导入 - {name}")
    val quickImportTooltip = WarehouseArbText("quickImportTooltip", "快捷导入")
    val recentSchoolLabel = WarehouseArbText("recentSchoolLabel", "最近使用")
    val recordImportAction = WarehouseArbText("recordImportAction", "录制导入")
    val reloadAction = WarehouseArbText("reloadAction", "重新加载")
    val rememberAndAutofillAction = WarehouseArbText("rememberAndAutofillAction", "记住并自动填充")
    val rememberCurrentInputTooltip = WarehouseArbText("rememberCurrentInputTooltip", "记住当前输入")
    val rememberLoginFailedWithError = WarehouseArbText("rememberLoginFailedWithError", "记住登录信息失败：{error}")
    val rememberPasswordMessage = WarehouseArbText("rememberPasswordMessage", "是否记住账号 {username} 的登录信息，并在下次自动填充？")
    val rememberPasswordTitle = WarehouseArbText("rememberPasswordTitle", "记住密码")
    val rememberedAccountLabel = WarehouseArbText("rememberedAccountLabel", "已记住账号：{username}")
    val rememberedCurrentLoginStatus = WarehouseArbText("rememberedCurrentLoginStatus", "已记住当前登录信息")
    val rememberedCurrentLoginSuccess = WarehouseArbText("rememberedCurrentLoginSuccess", "已记住当前登录信息")
    val repositoryLabel = WarehouseArbText("repositoryLabel", "仓库")
    val restoreRepositoryAddressAction = WarehouseArbText("restoreRepositoryAddressAction", "恢复仓库地址")
    val saveAction = WarehouseArbText("saveAction", "保存")
    val saveDebugRecordAction = WarehouseArbText("saveDebugRecordAction", "保存调试记录")
    val saveFailed = WarehouseArbText("saveFailed", "保存失败")
    val saveSectionTimesFailedWithError = WarehouseArbText("saveSectionTimesFailedWithError", "保存节次时间失败：{error}")
    val savingAction = WarehouseArbText("savingAction", "保存中……")
    val schoolLabel = WarehouseArbText("schoolLabel", "学校")
    val scriptEmpty = WarehouseArbText("scriptEmpty", "脚本为空")
    val scriptFileImportFailed = WarehouseArbText("scriptFileImportFailed", "导入脚本文件失败：{error}")
    val scriptFileImported = WarehouseArbText("scriptFileImported", "已导入脚本文件：{name}")
    val scriptFileReadFailed = WarehouseArbText("scriptFileReadFailed", "无法读取脚本文件")
    val scriptInjectionFailed = WarehouseArbText("scriptInjectionFailed", "脚本注入失败")
    val scriptLoadedLength = WarehouseArbText("scriptLoadedLength", "脚本已成功读取，长度 {count} 字符")
    val scriptPathLabel = WarehouseArbText("scriptPathLabel", "脚本路径")
    val scriptStatusTitle = WarehouseArbText("scriptStatusTitle", "脚本状态")
    val searchSchoolHint = WarehouseArbText("searchSchoolHint", "搜索学校或适配器名称")
    val searchSchoolSuggestion = WarehouseArbText("searchSchoolSuggestion", "可输入学校全称、适配器名称如 WakeUp 或学校代码")
    val selectQuickImportTitle = WarehouseArbText("selectQuickImportTitle", "选择快捷导入")
    val startDebugAction = WarehouseArbText("startDebugAction", "开始调试")
    val startRecordingTooltip = WarehouseArbText("startRecordingTooltip", "录制操作")
    val stopRecordingTooltip = WarehouseArbText("stopRecordingTooltip", "停止录制")
    val switchToDesktopWebTooltip = WarehouseArbText("switchToDesktopWebTooltip", "切换到桌面端页面")
    val switchToMobileWebTooltip = WarehouseArbText("switchToMobileWebTooltip", "切换到移动端页面")
    val unknownLocation = WarehouseArbText("unknownLocation", "未知地点")
    val unknownTeacher = WarehouseArbText("unknownTeacher", "未知教师")
    val unnamedScript = WarehouseArbText("unnamedScript", "未命名脚本")
    val unsetConfigLabel = WarehouseArbText("unsetConfigLabel", "未配置")
    val viewDetailsAction = WarehouseArbText("viewDetailsAction", "查看详情")
    val warehouseAdaptersLoadFailedTitle = WarehouseArbText("warehouseAdaptersLoadFailedTitle", "暂时无法读取适配器列表")
    val warehouseCustomDebugTitle = WarehouseArbText("warehouseCustomDebugTitle", "自定义调试")
    val warehouseFeedbackMissingSchoolTitle = WarehouseArbText("warehouseFeedbackMissingSchoolTitle", "缺少学校？去反馈")
    val warehouseImportExecutionLogMenuLabel = WarehouseArbText("warehouseImportExecutionLogMenuLabel", "课表导入执行日志")
    val warehouseMatchedAdaptersLabel = WarehouseArbText("warehouseMatchedAdaptersLabel", "匹配适配器：{names}")
    val warehouseMissingSchoolSubtitle = WarehouseArbText("warehouseMissingSchoolSubtitle", "请到反馈页提交 Issue，附上学校名称、教务系统网址与课表页截图，便于补充适配")
    val warehouseMissingSchoolTitle = WarehouseArbText("warehouseMissingSchoolTitle", "没找到你的学校？")
    val warehouseRootLoadFailedTitle = WarehouseArbText("warehouseRootLoadFailedTitle", "暂时无法读取适配仓")
    val warehouseSchoolTapHint = WarehouseArbText("warehouseSchoolTapHint", "点击进入，选择适配器导入")
    val warehouseSessionAlreadyActive = WarehouseArbText("warehouseSessionAlreadyActive", "教务仍处于登录状态，可直接导入")
    val webAddressHint = WarehouseArbText("webAddressHint", "输入网页地址")
    val webLoginImport = WarehouseArbText("webLoginImport", "网页登录导入")
    val weekListSeparator = WarehouseArbText("weekListSeparator", "、")

    val allTexts: List<WarehouseArbText> = listOf(
        adapterInfoTitle,
        adapterIntroSubtitle,
        adapterOverrideImportUrlHint,
        addDebugRecordAction,
        addDebugRecordTitle,
        addDebugRecordTooltip,
        aiExpertModeSuggestion,
        aiImportTitle,
        aiParseErrorTitle,
        aiParseFailedChip,
        aiParseFailedIncompleteJson,
        aiPasteJsonFirst,
        aiPasteJsonHintLong,
        aiPasteJsonHintShort,
        aiPasteJsonTitle,
        aiPreviewCourseCount,
        aiPreviewCoursesTitle,
        aiPreviewMaxSection,
        aiPreviewRemainingCourses,
        aiPreviewSummary,
        aiPreviewTitle,
        aiPreviewWarningsTitle,
        aiPromptSheetSubtitle,
        aiPromptSheetTitle,
        aiPromptShortAction,
        aiWarningCountSuffix,
        aiWorkflowSubtitle,
        aiWorkflowTitle,
        applyReturnedTimeSchemeFailed,
        autofillAction,
        autofillLoginMessage,
        autofillLoginTitle,
        availableWeeksCount,
        cancelAction,
        categoryLabel,
        clearAction,
        clearCustomLoginAddressAction,
        clearRememberedTooltip,
        clearSearchTooltip,
        clipboardNoText,
        confirmImportAction,
        copiedCurrentAddress,
        copiedImportLoginUrl,
        copiedScriptRawUrl,
        copyAddress,
        copyCurrentAddressTooltip,
        copyLoginAddressAction,
        copyScriptAddressAction,
        courseImportAutoRecordingStartedTip,
        courseImportLocationNotFilled,
        courseImportPreviewLine,
        courseImportRecordingEmptyStatus,
        courseImportRecordingEmptyTip,
        courseImportRecordingSavedStatus,
        courseImportRecordingStartedTip,
        courseImportRecordingStatus,
        courseImportSaveAutoRecordingMessage,
        courseImportSaveRecordingMessage,
        courseImportSaveRecordingTitle,
        courseImportScriptFailed,
        courseImportWeekNotProvided,
        customDebugIntroSubtitle,
        customDebugIntroTitle,
        customLoginAddressAction,
        debugRecordFormula,
        debugRecordNameHint,
        debugRecordNameLabel,
        debugRecordNameRequired,
        debugScriptHint,
        debugScriptLabel,
        debugScriptLength,
        debugScriptRequired,
        defaultContinuePrompt,
        deleteAction,
        deleteDebugRecordMessage,
        deleteDebugRecordTitle,
        deletedDebugRecord,
        dontRememberAction,
        editAction,
        editCustomLoginAddressAction,
        editDebugRecordTitle,
        executeFailedWithError,
        executeImportScriptAction,
        executeLocalDebugScriptAction,
        fillRememberedTooltip,
        fillUrlThenImport,
        fillUrlThenRecord,
        goAction,
        goFeedbackAction,
        homeWidgetDescriptionTitle,
        importAiReplaceMessage,
        importAiResultTitle,
        importCleartextBlockedHint,
        importConfirmSemesterMappingTitle,
        importCourseRecordsDropped,
        importCourseWeeksTrimmed,
        importFileTooLarge,
        importFailedStatus,
        importFromFileAction,
        importMethodAiTitle,
        importMethodWarehouseTitle,
        importNoCourseChanges,
        importOverwriteCount,
        importReplaceExistingTitle,
        importUpdatedCount,
        importUrlLabel,
        importingAction,
        injectingAdapterScript,
        injectingLocalDebugScript,
        inputRequiredTitle,
        invalidCourseDataFormat,
        invalidImportUrl,
        laterAction,
        noImportableCoursesFromScript,
        localDebugModeScriptStatus,
        loginEntryLabel,
        maintainerLabel,
        moreActionsTooltip,
        noAvailableSchools,
        noMacroRecordFound,
        noMatchingSchools,
        noRecognizedLoginInputs,
        noSavedDebugRecords,
        noSavedDebugRecordsHint,
        noSavedQuickImportRecords,
        noUsernameOrPasswordRecognized,
        noValidWarehouseLoginUrl,
        notNowAction,
        openInSystemBrowserAction,
        openLoginInAppAction,
        pasteAction,
        pleaseChooseTitle,
        pleaseEnterFourDigitYear,
        previewAction,
        promptCopiedHint,
        quickImportAction,
        quickImportDismissAction,
        quickImportFinishedTitle,
        quickImportMacroSteps,
        quickImportTitle,
        quickImportTooltip,
        recentSchoolLabel,
        recordImportAction,
        reloadAction,
        rememberAndAutofillAction,
        rememberCurrentInputTooltip,
        rememberLoginFailedWithError,
        rememberPasswordMessage,
        rememberPasswordTitle,
        rememberedAccountLabel,
        rememberedCurrentLoginStatus,
        rememberedCurrentLoginSuccess,
        repositoryLabel,
        restoreRepositoryAddressAction,
        saveAction,
        saveDebugRecordAction,
        saveFailed,
        saveSectionTimesFailedWithError,
        savingAction,
        schoolLabel,
        scriptEmpty,
        scriptFileImportFailed,
        scriptFileImported,
        scriptFileReadFailed,
        scriptInjectionFailed,
        scriptLoadedLength,
        scriptPathLabel,
        scriptStatusTitle,
        searchSchoolHint,
        searchSchoolSuggestion,
        selectQuickImportTitle,
        startDebugAction,
        startRecordingTooltip,
        stopRecordingTooltip,
        switchToDesktopWebTooltip,
        switchToMobileWebTooltip,
        unknownLocation,
        unknownTeacher,
        unnamedScript,
        unsetConfigLabel,
        viewDetailsAction,
        warehouseAdaptersLoadFailedTitle,
        warehouseCustomDebugTitle,
        warehouseFeedbackMissingSchoolTitle,
        warehouseImportExecutionLogMenuLabel,
        warehouseMatchedAdaptersLabel,
        warehouseMissingSchoolSubtitle,
        warehouseMissingSchoolTitle,
        warehouseRootLoadFailedTitle,
        warehouseSchoolTapHint,
        warehouseSessionAlreadyActive,
        webAddressHint,
        webLoginImport,
        weekListSeparator,
    )
}
