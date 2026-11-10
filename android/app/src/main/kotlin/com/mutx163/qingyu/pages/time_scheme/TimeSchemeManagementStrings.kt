package com.mutx163.qingyu.pages.time_scheme

/**
 * 时间模板管理页（`pages/time_scheme`）用到的全部屏上文案。
 *
 * ## 为什么自己带一份文案对象
 *
 * 页面是 Kotlin 重写，不读 Flutter 的 gen-l10n，所以每一条文案都要落成常量再
 * 逐字对拍 `lib/l10n/app_zh.arb`（`TimeSchemeManagementStringsParityTest` 机械校验）。
 * 命名与本包内 [TimeSchemeManagementText] 一致，键名与 ARB 键**完全相同**——不缩写、
 * 不合并，这样任一边新增一条都能立刻对不上。
 *
 * ## 为什么不复用 `pages.schedule.ScheduleStrings.ArbText`
 *
 * `ArbText` 定义在 `ScheduleStrings.kt` 里，属于日程模块的包。跨页 import 会把
 * 两个独立批次焊在一起（改日程那批的类就会牵动这一批的编译），而共享件目录
 * `components/` 按 Phase 3 台账是 Lead 的写作用域，本批不合规落笔。因此这里
 * 自带同形的小数据类，字段与 `filled` 语义与它保持一致，日后若要收口成共享件，
 * 只需把类提上去、本文件改成 import，文案本体不受影响。
 *
 * ## 关于两条「借用」的措辞
 *
 * - `nameRequired`：ARB 里没有 timeScheme 专属的必填提示，这里复用日程日期规则
 *   已有的通用句「请填写名称」（键 `scheduleDateRuleErrorNameRequired`）。宁可
 *   借用一句已有的通用文案，也不新造一句 ARB 里不存在的字——新造字在真机上就是
 *   一条无法被翻译、无法被校对的内容。
 * - `timeSchemeBlockerListSeparator` 是分隔符而不是句子，但它在 ARB 里就是一个
 *   独立的键，所以照样落成一个 [TimeSchemeManagementText]，让对拍把它一起覆盖。
 */
typealias TimeSchemeManagementText = com.mutx163.qingyu.app.ArbText

object TimeSchemeManagementStrings {

    // ── 管理列表页（TimeSchemeManagementPage） ──
    val timeSchemeTitle = TimeSchemeManagementText("timeSchemeTitle", "时间模板")
    val newSchemeTooltip = TimeSchemeManagementText("newSchemeTooltip", "新建模板")
    val locationTimeMatchEntryTitle = TimeSchemeManagementText("locationTimeMatchEntryTitle", "地点作息匹配")
    val scheduleDateRuleSectionTitle = TimeSchemeManagementText("scheduleDateRuleSectionTitle", "日期作息规则")
    val scheduleDateRuleActiveToday = TimeSchemeManagementText("scheduleDateRuleActiveToday", "今天在区间内")
    val timeSchemeEntryTitle = TimeSchemeManagementText("timeSchemeEntryTitle", "时间模板")
    val locationTimeMatchNeedTimeScheme = TimeSchemeManagementText("locationTimeMatchNeedTimeScheme", "请先创建一套时间模板")
    val timeSchemeSummary = TimeSchemeManagementText(
        "timeSchemeSummary",
        "{sections} 节 · {profiles} 个课表 · {courses} 节课程 · {overrideCourses} 节副时间模板",
    )
    val moreActionsTooltip = TimeSchemeManagementText("moreActionsTooltip", "更多操作")
    val timeSchemeStartsAt = TimeSchemeManagementText("timeSchemeStartsAt", "{start} 起")
    val usingNow = TimeSchemeManagementText("usingNow", "正在使用")
    val applyToCurrentTimetable = TimeSchemeManagementText("applyToCurrentTimetable", "应用到当前课表")
    val editSectionsAction = TimeSchemeManagementText("editSectionsAction", "编辑节次")
    val viewUsageAction = TimeSchemeManagementText("viewUsageAction", "查看使用情况")
    val renameAction = TimeSchemeManagementText("renameAction", "重命名")
    val duplicateAction = TimeSchemeManagementText("duplicateAction", "复制")
    val shareTimeSchemeAction = TimeSchemeManagementText("shareTimeSchemeAction", "分享")
    val deleteAction = TimeSchemeManagementText("deleteAction", "删除")

    // ── 新建 / 重命名 ──
    val createTimeSchemeTitle = TimeSchemeManagementText("createTimeSchemeTitle", "新建时间模板")
    val createAction = TimeSchemeManagementText("createAction", "创建")
    val timeSchemeNameLabel = TimeSchemeManagementText("timeSchemeNameLabel", "模板名称")
    val timeSchemeNameHint = TimeSchemeManagementText("timeSchemeNameHint", "例如：本校夏季作息")
    val saveFailed = TimeSchemeManagementText("saveFailed", "保存失败")
    val copiedTimeSchemeMessage = TimeSchemeManagementText("copiedTimeSchemeMessage", "已复制时间模板")
    val renameTimeSchemeTitle = TimeSchemeManagementText("renameTimeSchemeTitle", "重命名时间模板")
    val renamedToMessage = TimeSchemeManagementText("renamedToMessage", "已重命名为 {name}")

    // ── 删除 ──
    val deleteTimeSchemeTitle = TimeSchemeManagementText("deleteTimeSchemeTitle", "删除时间模板")
    val deleteTimeSchemeMessage = TimeSchemeManagementText("deleteTimeSchemeMessage", "确定删除作息 {name}？删除后无法恢复")
    val cancelAction = TimeSchemeManagementText("cancelAction", "取消")
    val deleteFailed = TimeSchemeManagementText("deleteFailed", "删除失败")
    val deletedTimeSchemeMessage = TimeSchemeManagementText("deletedTimeSchemeMessage", "已删除时间模板：{name}")
    val timeSchemeInUseMessage = TimeSchemeManagementText("timeSchemeInUseMessage", "当前课表正在使用这套模板")
    val timeSchemeBlockerListSeparator = TimeSchemeManagementText("timeSchemeBlockerListSeparator", "、")
    val timeSchemeBlockedByProfiles = TimeSchemeManagementText("timeSchemeBlockedByProfiles", "作为主时间模板的课表：{names}")
    val timeSchemeBlockedByOverrideCourses =
        TimeSchemeManagementText("timeSchemeBlockedByOverrideCourses", "把它设为副时间模板的课程：{count} 门")
    val timeSchemeBlockedByLocationCourses =
        TimeSchemeManagementText("timeSchemeBlockedByLocationCourses", "按上课地点自动匹配到它的课程：{count} 门")
    val timeSchemeBlockedByLocationGroups =
        TimeSchemeManagementText("timeSchemeBlockedByLocationGroups", "绑定了它的地点作息匹配：{names}")
    val timeSchemeBlockedByDateRules =
        TimeSchemeManagementText("timeSchemeBlockedByDateRules", "绑定了它的日期作息规则：{names}")
    val timeSchemeDeleteBlockedIntro =
        TimeSchemeManagementText("timeSchemeDeleteBlockedIntro", "还有下面的地方在用这套模板，解除后才能删除：")
    val appliedTimeSchemeMessage = TimeSchemeManagementText("appliedTimeSchemeMessage", "已应用时间模板：{name}")

    // ── 分享 ──
    val shareTimeSchemeTitle = TimeSchemeManagementText("shareTimeSchemeTitle", "分享时间模板")
    val shareTimeSchemeViaQr = TimeSchemeManagementText("shareTimeSchemeViaQr", "二维码分享")
    val shareTimeSchemeViaSystem = TimeSchemeManagementText("shareTimeSchemeViaSystem", "系统分享文件")
    val timeSchemeShareText = TimeSchemeManagementText("timeSchemeShareText", "轻屿课表时间模板 {name}，导入后即可使用")
    val timeSchemeShareSubject = TimeSchemeManagementText("timeSchemeShareSubject", "轻屿课表 · 时间模板")
    val sendFailedWithError = TimeSchemeManagementText("sendFailedWithError", "发送失败：{error}")
    val qrTransferResourceLimit = TimeSchemeManagementText(
        "qrTransferResourceLimit",
        "接收数据超过二维码传输资源上限，请重新开始并使用更小的备份。",
    )

    // ── 使用情况页 ──
    val overrideTimeSchemeShortLabel = TimeSchemeManagementText("overrideTimeSchemeShortLabel", "副时间模板")
    val mainTimeSchemeLabel = TimeSchemeManagementText("mainTimeSchemeLabel", "主时间模板")
    val timeSchemeUsageReference = TimeSchemeManagementText(
        "timeSchemeUsageReference",
        "{profileName} · {courseName} 周 {weekday} 第 {startSection} 至 {endSection} 节 {usageType}",
    )
    val timeSchemeBottomUsageMulti = TimeSchemeManagementText("timeSchemeBottomUsageMulti", "{first} 等 {count} 节课程")
    val timeSchemeUsageTitle = TimeSchemeManagementText("timeSchemeUsageTitle", "{name} 的使用情况")
    val timeSchemeUsageIntro = TimeSchemeManagementText(
        "timeSchemeUsageIntro",
        "先看总影响范围，再决定是直接编辑这套模板，还是先复制一套再改",
    )
    val profileCountLabel = TimeSchemeManagementText("profileCountLabel", "课表")
    val profileCountValue = TimeSchemeManagementText("profileCountValue", "{count} 个")
    val courseCountLabel = TimeSchemeManagementText("courseCountLabel", "课程")
    val courseSectionCountValue = TimeSchemeManagementText("courseSectionCountValue", "{count} 节")
    val overrideTimeSchemeLabel = TimeSchemeManagementText("overrideTimeSchemeLabel", "副时间模板")
    val directlyBoundProfilesTitle = TimeSchemeManagementText("directlyBoundProfilesTitle", "直接绑定这套模板的课表")
    val directlyBoundProfilesEmpty = TimeSchemeManagementText("directlyBoundProfilesEmpty", "当前没有课表直接使用这套模板")
    val directlyBoundProfilesSubtitle = TimeSchemeManagementText(
        "directlyBoundProfilesSubtitle",
        "这些课表切到这套模板后，默认都会按这套节次时间显示",
    )
    val followMainSchemeCoursesTitle = TimeSchemeManagementText("followMainSchemeCoursesTitle", "跟随主时间模板的课程")
    val followMainSchemeCoursesEmpty = TimeSchemeManagementText(
        "followMainSchemeCoursesEmpty",
        "当前没有课程通过课表主时间模板间接使用它",
    )
    val followMainSchemeCoursesSubtitle = TimeSchemeManagementText(
        "followMainSchemeCoursesSubtitle",
        "这些课程没有单独设置副时间模板，而是跟着所属课表一起用这套模板",
    )
    val overrideSchemeCoursesTitle = TimeSchemeManagementText("overrideSchemeCoursesTitle", "设为副时间模板的课程")
    val overrideSchemeCoursesEmpty = TimeSchemeManagementText("overrideSchemeCoursesEmpty", "当前没有课程把它作为副时间模板")
    val overrideSchemeCoursesSubtitle = TimeSchemeManagementText(
        "overrideSchemeCoursesSubtitle",
        "这些课程即使所在课表切换了主模板，也会继续单独使用这套时间",
    )
    val weekdaySectionRange = TimeSchemeManagementText("weekdaySectionRange", "周 {weekday} {startSection}～{endSection} 节")
    val timeSchemeBlockedLocationGroupsSubtitle =
        TimeSchemeManagementText("timeSchemeBlockedLocationGroupsSubtitle", "需先改绑到别的模板才能删除")
    val timeSchemeBlockedDateRulesSubtitle =
        TimeSchemeManagementText("timeSchemeBlockedDateRulesSubtitle", "需先改绑到别的模板才能删除")
    val closeAction = TimeSchemeManagementText("closeAction", "关闭")

    // ── 星期短名（周选择器、使用情况行） ──
    val weekdayShortMonday = TimeSchemeManagementText("weekdayShortMonday", "一")
    val weekdayShortTuesday = TimeSchemeManagementText("weekdayShortTuesday", "二")
    val weekdayShortWednesday = TimeSchemeManagementText("weekdayShortWednesday", "三")
    val weekdayShortThursday = TimeSchemeManagementText("weekdayShortThursday", "四")
    val weekdayShortFriday = TimeSchemeManagementText("weekdayShortFriday", "五")
    val weekdayShortSaturday = TimeSchemeManagementText("weekdayShortSaturday", "六")
    val weekdayShortSunday = TimeSchemeManagementText("weekdayShortSunday", "日")

    // ── 编辑器（编辑节次页） ──
    val editTimeSchemeTitle = TimeSchemeManagementText("editTimeSchemeTitle", "编辑时间模板")
    val saveAction = TimeSchemeManagementText("saveAction", "保存")
    val currentInUse = TimeSchemeManagementText("currentInUse", "当前使用")
    val timeSchemeEditorActiveAndCoursesHint = TimeSchemeManagementText(
        "timeSchemeEditorActiveAndCoursesHint",
        "当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程",
    )
    val timeSchemeEditorActiveHint = TimeSchemeManagementText(
        "timeSchemeEditorActiveHint",
        "当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表",
    )
    val timeSchemeEditorOverrideHint = TimeSchemeManagementText(
        "timeSchemeEditorOverrideHint",
        "有课程正在把这套模板作为副时间模板使用，保存后会同步更新所有引用课程",
    )
    val sectionTimesTitle = TimeSchemeManagementText("sectionTimesTitle", "节次时间")
    val sectionTimesSubtitle = TimeSchemeManagementText(
        "sectionTimesSubtitle",
        "如果当前课表正在使用这套模板，节次数量不能小于已使用的最大节次",
    )
    val quickGenerateAction = TimeSchemeManagementText("quickGenerateAction", "快捷生成")
    val addSectionAction = TimeSchemeManagementText("addSectionAction", "新增一节")
    val removeLastSectionAction = TimeSchemeManagementText("removeLastSectionAction", "删除末节")
    val resetDefaultAction = TimeSchemeManagementText("resetDefaultAction", "恢复默认")
    val sectionLabel = TimeSchemeManagementText("sectionLabel", "第 {section} 节")
    val selectStartTimeTitle = TimeSchemeManagementText("selectStartTimeTitle", "选择开始时间")
    val selectEndTimeTitle = TimeSchemeManagementText("selectEndTimeTitle", "选择结束时间")
    val timeRangeValidationNoCrossDay =
        TimeSchemeManagementText("timeRangeValidationNoCrossDay", "结束时间必须晚于开始时间")

    /**
     * 复制出来的新名字模板。
     *
     * 借的是 ARB 里已有的同形键（`themeDuplicateCopyName` = `{name} 副本`）。理由与
     * [nameRequired] 相同：Dart 侧这个名字本身也是**硬编码字面量**
     * （`timetable_time_scheme_service.dart:224` 的 `'${source.name} 副本'`），
     * 借一条已有键既能让对拍覆盖它，又不新造一个字。
     */
    val copiedSchemeNameTemplate = TimeSchemeManagementText("themeDuplicateCopyName", "{name} 副本")

    // ── 快捷生成弹层（TimeSchemeQuickGenerateSheet，契约变更 4） ──
    val quickGenerateTimeSchemeTitle = TimeSchemeManagementText("quickGenerateTimeSchemeTitle", "快捷生成课表时间")
    val morningSectionCountLabel = TimeSchemeManagementText("morningSectionCountLabel", "上午几节")
    val morningFirstSectionTimeLabel = TimeSchemeManagementText("morningFirstSectionTimeLabel", "早上第一节时间")
    val afternoonSectionCountLabel = TimeSchemeManagementText("afternoonSectionCountLabel", "下午几节")
    val afternoonFirstSectionTimeLabel = TimeSchemeManagementText("afternoonFirstSectionTimeLabel", "下午第一节时间")
    val eveningSectionCountLabel = TimeSchemeManagementText("eveningSectionCountLabel", "晚上几节")
    val eveningFirstSectionTimeLabel = TimeSchemeManagementText("eveningFirstSectionTimeLabel", "晚上第一节时间")
    val classDurationMinutesLabel = TimeSchemeManagementText("classDurationMinutesLabel", "单节课时长 分钟")
    val smallBreakDurationMinutesLabel = TimeSchemeManagementText("smallBreakDurationMinutesLabel", "小课间时长 分钟")
    val largeBreakRulesTitle = TimeSchemeManagementText("largeBreakRulesTitle", "大课间规则")
    val noLargeBreakRulesHint =
        TimeSchemeManagementText("noLargeBreakRulesHint", "未设置大课间规则，将全部使用小课间时长")
    val addBreakRuleAction = TimeSchemeManagementText("addBreakRuleAction", "新增大课间规则")
    val afterSectionLabel = TimeSchemeManagementText("afterSectionLabel", "第几节后")
    val breakDurationMinutesLabel = TimeSchemeManagementText("breakDurationMinutesLabel", "休息时长 分钟")
    val deleteRuleTooltip = TimeSchemeManagementText("deleteRuleTooltip", "删除规则")
    val generateAction = TimeSchemeManagementText("generateAction", "生成")

    /**
     * 快捷生成弹层的**结果预览**一行（2026-11-10 重做新增）。
     *
     * 用户改完「几节 / 几点开始 / 多长」之后最想知道的是「生成出来几点放学」；原来要
     * 先点生成、看完节次表才知道（不满意就再回来重填）。这条把它实时摆出来。
     */
    val quickGeneratePreviewSummary = TimeSchemeManagementText(
        "quickGeneratePreviewSummary",
        "共 {sections} 节 · 最后一节 {endTime} 结束",
    )
    val fillNumbersValidationMessage =
        TimeSchemeManagementText("fillNumbersValidationMessage", "请把节数和时长填写为数字")
    val breakOverrideInvalidMessage = TimeSchemeManagementText(
        "breakOverrideInvalidMessage",
        "大课间规则要改：第几节后填 1 以上的数字，时长填 0 以上的数字",
    )

    /** 时间选择器「确定」（与 [cancelAction] 一对；快捷生成里时/分滚轮页要用）。 */
    val confirmAction = TimeSchemeManagementText("confirmAction", "确认")

    /**
     * 名称必填提示。
     *
     * 借的是 ARB 里已有的通用句（键 `scheduleDateRuleErrorNameRequired`），
     * 理由见文件头「关于两条『借用』的措辞」。
     */
    val nameRequired = TimeSchemeManagementText("scheduleDateRuleErrorNameRequired", "请填写名称")

    /** 所有 ARB 文案清单，供机械化单测逐字对拍。 */
    val allTexts: List<TimeSchemeManagementText> by lazy {
        listOf(
            timeSchemeTitle,
            newSchemeTooltip,
            locationTimeMatchEntryTitle,
            scheduleDateRuleSectionTitle,
            scheduleDateRuleActiveToday,
            timeSchemeEntryTitle,
            locationTimeMatchNeedTimeScheme,
            timeSchemeSummary,
            moreActionsTooltip,
            timeSchemeStartsAt,
            usingNow,
            applyToCurrentTimetable,
            editSectionsAction,
            viewUsageAction,
            renameAction,
            duplicateAction,
            shareTimeSchemeAction,
            deleteAction,
            createTimeSchemeTitle,
            createAction,
            timeSchemeNameLabel,
            timeSchemeNameHint,
            saveFailed,
            copiedTimeSchemeMessage,
            renameTimeSchemeTitle,
            renamedToMessage,
            deleteTimeSchemeTitle,
            deleteTimeSchemeMessage,
            cancelAction,
            deleteFailed,
            deletedTimeSchemeMessage,
            timeSchemeInUseMessage,
            timeSchemeBlockerListSeparator,
            timeSchemeBlockedByProfiles,
            timeSchemeBlockedByOverrideCourses,
            timeSchemeBlockedByLocationCourses,
            timeSchemeBlockedByLocationGroups,
            timeSchemeBlockedByDateRules,
            timeSchemeDeleteBlockedIntro,
            appliedTimeSchemeMessage,
            shareTimeSchemeTitle,
            shareTimeSchemeViaQr,
            shareTimeSchemeViaSystem,
            timeSchemeShareText,
            timeSchemeShareSubject,
            sendFailedWithError,
            qrTransferResourceLimit,
            overrideTimeSchemeShortLabel,
            mainTimeSchemeLabel,
            timeSchemeUsageReference,
            timeSchemeBottomUsageMulti,
            timeSchemeUsageTitle,
            timeSchemeUsageIntro,
            profileCountLabel,
            profileCountValue,
            courseCountLabel,
            courseSectionCountValue,
            overrideTimeSchemeLabel,
            directlyBoundProfilesTitle,
            directlyBoundProfilesEmpty,
            directlyBoundProfilesSubtitle,
            followMainSchemeCoursesTitle,
            followMainSchemeCoursesEmpty,
            followMainSchemeCoursesSubtitle,
            overrideSchemeCoursesTitle,
            overrideSchemeCoursesEmpty,
            overrideSchemeCoursesSubtitle,
            weekdaySectionRange,
            timeSchemeBlockedLocationGroupsSubtitle,
            timeSchemeBlockedDateRulesSubtitle,
            closeAction,
            weekdayShortMonday,
            weekdayShortTuesday,
            weekdayShortWednesday,
            weekdayShortThursday,
            weekdayShortFriday,
            weekdayShortSaturday,
            weekdayShortSunday,
            editTimeSchemeTitle,
            saveAction,
            currentInUse,
            timeSchemeEditorActiveAndCoursesHint,
            timeSchemeEditorActiveHint,
            timeSchemeEditorOverrideHint,
            sectionTimesTitle,
            sectionTimesSubtitle,
            quickGenerateAction,
            addSectionAction,
            removeLastSectionAction,
            resetDefaultAction,
            sectionLabel,
            selectStartTimeTitle,
            selectEndTimeTitle,
            timeRangeValidationNoCrossDay,
            copiedSchemeNameTemplate,
            quickGenerateTimeSchemeTitle,
            morningSectionCountLabel,
            morningFirstSectionTimeLabel,
            afternoonSectionCountLabel,
            afternoonFirstSectionTimeLabel,
            eveningSectionCountLabel,
            eveningFirstSectionTimeLabel,
            classDurationMinutesLabel,
            smallBreakDurationMinutesLabel,
            largeBreakRulesTitle,
            noLargeBreakRulesHint,
            addBreakRuleAction,
            afterSectionLabel,
            breakDurationMinutesLabel,
            deleteRuleTooltip,
            generateAction,
            quickGeneratePreviewSummary,
            fillNumbersValidationMessage,
            breakOverrideInvalidMessage,
            confirmAction,
            nameRequired,
        )
    }

    /** 周一至周日的单字短名；非 1..7 返回空串（调用方据此跳过渲染）。 */
    fun weekdayShort(weekday: Int): String = when (weekday) {
        1 -> weekdayShortMonday.text
        2 -> weekdayShortTuesday.text
        3 -> weekdayShortWednesday.text
        4 -> weekdayShortThursday.text
        5 -> weekdayShortFriday.text
        6 -> weekdayShortSaturday.text
        7 -> weekdayShortSunday.text
        else -> ""
    }
}
