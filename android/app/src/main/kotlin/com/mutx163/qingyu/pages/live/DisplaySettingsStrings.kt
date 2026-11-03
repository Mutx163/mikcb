package com.mutx163.qingyu.pages.live

/**
 * 「超级岛 · 显示设置页 + 超级岛预览」ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [DisplaySettingsStringsParityTest] 里与 ARB
 * 机械比对，键缺失或值被改写都会红。命名与 ARB 键逐字一致，便于 grep 双向核对。
 *
 * 复用 [LiveStrings] 文件里已有的顶层 `data class ArbText`（同包 public），
 * 因此**不需要**改动 `LiveStrings.kt`。
 */
object DisplaySettingsStrings {

    // ── 显示内容组（6 开关）──
    val displayContentTitle = ArbText("liveDisplayContentTitle", "显示内容")
    val showCourseNameTitle = ArbText("showCourseNameTitle", "显示课程名")
    val preferShortNameTitle = ArbText("preferShortNameTitle", "优先显示课程简称")
    val preferShortNameSubtitle = ArbText("preferShortNameSubtitle", "课程未填写简称时不生效")
    val showLocationTitle = ArbText("showLocationTitle", "显示地点")
    val showCountdownTitle = ArbText("showCountdownTitle", "显示倒计时")
    val showStageTextTitle = ArbText("showStageTextTitle", "显示阶段状态文案")
    val showStageTextInactiveHint = ArbText("showStageTextInactiveHint", "倒计时开启时不生效")
    val hidePrefixTextTitle = ArbText("hidePrefixTextTitle", "隐藏距上课与距下课前缀")
    val hidePrefixTextInactiveHint = ArbText("hidePrefixTextInactiveHint", "未生效：需先开启显示倒计时")
    val courseNameDuplicatedHint = ArbText("courseNameDuplicatedHint", "左侧已显示课程名")
    val locationDuplicatedHint = ArbText("locationDuplicatedHint", "左侧已显示地点")

    // ── 倒计时格式组 ──
    val countdownFormatLabel = ArbText("countdownFormatLabel", "倒计时格式")
    val countdownFormatHelp = ArbText("countdownFormatHelp", "纯分钟按分钟刷新，带秒按秒刷新")

    // ── 上课前快捷操作组 ──
    val beforeClassQuickActionTitle = ArbText("beforeClassQuickActionTitle", "上课前快捷操作")
    val beforeClassQuickActionSubtitle = ArbText(
        "beforeClassQuickActionSubtitle",
        "仅在上课前提醒的展开通知中显示；免打扰下课自动恢复，首次需系统授权",
    )
    val beforeClassQuickActionAutoTitle = ArbText("liveBeforeClassQuickActionAutoTitle", "自动执行")
    val beforeClassQuickActionAutoSubtitle = ArbText("liveBeforeClassQuickActionAutoSubtitle", "上课前自动开启，下课后恢复")
    val beforeClassQuickActionAutoOptionOff = ArbText("liveBeforeClassQuickActionAutoOptionOff", "不自动执行")
    val beforeClassQuickActionAutoOptionMinutes = ArbText("liveBeforeClassQuickActionAutoOptionMinutes", "上课前 {minutes} 分钟")

    // ── 小米岛左侧标签全套 ──
    val islandVisualTitle = ArbText("liveIslandVisualTitle", "胶囊左侧图标")
    val miuiLabelImageTitle = ArbText("liveMiuiLabelImageTitle", "超级岛左侧文字图标")
    val miuiLabelImageSubtitle = ArbText("liveMiuiLabelImageSubtitle", "推荐小米/红米，其他机型可能异常")
    val miuiLabelContentLabel = ArbText("liveMiuiLabelContentLabel", "左侧文字内容")
    val miuiLabelStyleLabel = ArbText("liveMiuiLabelStyleLabel", "左侧图标样式")
    val miuiLabelLogoTitle = ArbText("liveMiuiLabelLogoTitle", "左侧图标 Logo")
    val miuiLabelLogoSubtitle = ArbText("liveMiuiLabelLogoSubtitle", "未设置时用应用图标")
    val selectImageAction = ArbText("selectImageAction", "选择图片")
    val replaceImageAction = ArbText("replaceImageAction", "更换图片")
    val deleteAction = ArbText("deleteAction", "删除")
    val miuiLabelLogoCornerRadiusLabel = ArbText("liveMiuiLabelLogoCornerRadiusLabel", "左侧图标圆角 {value}")
    val miuiLabelAdvancedAccordionTitle = ArbText("liveMiuiLabelAdvancedAccordionTitle", "文字排版与位置微调")
    val miuiLabelAdvancedAccordionSubtitle = ArbText("liveMiuiLabelAdvancedAccordionSubtitle", "字号、水平/垂直偏移、粗细与清晰度")
    val miuiLabelFontSizeLabel = ArbText("liveMiuiLabelFontSizeLabel", "左侧文字大小 {value}")
    val miuiLabelOffsetXLabel = ArbText("liveMiuiLabelOffsetXLabel", "左侧文字水平偏移 {value}")
    val miuiLabelOffsetYLabel = ArbText("liveMiuiLabelOffsetYLabel", "左侧文字垂直偏移 {value}")
    val miuiLabelFontWeightLabel = ArbText("liveMiuiLabelFontWeightLabel", "左侧文字粗细")
    val miuiLabelRenderQualityLabel = ArbText("liveMiuiLabelRenderQualityLabel", "左侧文字清晰度")

    // ── 展开态图标组 ──
    val expandedIconSectionTitle = ArbText("liveExpandedIconSectionTitle", "展开卡片大图标")
    val miuiExpandedIconLabel = ArbText("liveMiuiExpandedIconLabel", "展开态大图标")

    // ── 展开详情组 ──
    val expandedDetailGroupTitle = ArbText("liveExpandedDetailGroupTitle", "展开详情")
    val resetExpandedDetailDefaultAction = ArbText("resetExpandedDetailDefaultAction", "恢复默认顺序与显示")
    val detailReorderHandleLabel = ArbText("liveExpandedDetailReorderHandleLabel", "拖动排序")
    val detailMoveUpAction = ArbText("liveExpandedDetailMoveUpAction", "上移")
    val detailMoveDownAction = ArbText("liveExpandedDetailMoveDownAction", "下移")
    val detailHiddenCaption = ArbText("liveExpandedDetailHiddenCaption", "已隐藏")

    // ── 展开详情字段名 ──
    val detailFieldStage = ArbText("liveExpandedDetailFieldStage", "阶段")
    val detailFieldShortName = ArbText("liveExpandedDetailFieldShortName", "课程简称")
    val detailFieldProgress = ArbText("liveExpandedDetailFieldProgress", "进度")
    val detailFieldStatus = ArbText("liveExpandedDetailFieldStatus", "状态")
    val detailFieldTime = ArbText("liveExpandedDetailFieldTime", "上课时间")
    val detailFieldLocation = ArbText("liveExpandedDetailFieldLocation", "地点")
    val detailFieldTeacher = ArbText("liveExpandedDetailFieldTeacher", "教师")
    val detailFieldNext = ArbText("liveExpandedDetailFieldNext", "下节课")
    val detailFieldNote = ArbText("liveExpandedDetailFieldNote", "备注")

    // ── 预览卡标题与动作 ──
    val islandPreviewTitle = ArbText("liveIslandPreviewTitle", "超级岛预览")
    val islandExpandedPreviewTitle = ArbText("liveIslandExpandedPreviewTitle", "展开态预览")
    /**
     * 预览诚实空态。复用日视图已有的 `dayViewEmptyTitle`，**不新增 ARB 键**；
     * 语义与「当前没有课程」一致。
     */
    val islandPreviewEmpty = ArbText("dayViewEmptyTitle", "暂无课程")
    /** 学期未配置时的副句，同样复用 ARB 原句。 */
    val islandPreviewSemesterUnsetHint =
        ArbText("pleaseSetSemesterStartDate", "请先在课表设置里填写开学日期")
    val islandPreviewFollowBadge = ArbText("liveIslandPreviewFollowBadge", "跟随课前提醒设置，修改课前提醒即生效")
    val stagePreviewBeforeClassAction = ArbText("liveStagePreviewBeforeClassAction", "试弹上课前岛")
    val stagePreviewDuringClassAction = ArbText("liveStagePreviewDuringClassAction", "试弹课中岛")
    val stagePreviewStopAction = ArbText("liveTestingCourseTestStopAction", "停止测试")

    // ── 试弹触发反馈（键全部为 ARB 既有键，速览管线接线时复用）──
    val stagePreviewStartedToast = ArbText("liveStagePreviewStartedToast", "已开启超级岛预览")
    val stagePreviewStoppedToast = ArbText("liveStagePreviewStoppedToast", "已停止超级岛预览")
    val stagePreviewStageBeforeClass = ArbText("liveStagePreviewStageBeforeClass", "上课前")
    val stagePreviewStageDuringClass = ArbText("liveStagePreviewStageDuringClass", "课中")
    val testingInFlight = ArbText("liveTestingInFlight", "测试进行中，请勿重复点击，请稍后再试")
    val sendFailedWithError = ArbText("sendFailedWithError", "发送失败：{error}")

    // ── 课中/下课页「配置方式」组 ──
    val displayConfigModeTitle = ArbText("liveDisplayConfigModeTitle", "配置方式")
    val followBeforeClassDisplayTitle = ArbText("followBeforeClassDisplayTitle", "跟随上课前提醒设置")

    // ── 页面标题（课前 / 课中与下课两个变体）──
    val displayEntryTitleBeforeClass = ArbText("liveBeforeClassDisplayEntryTitle", "上课前提醒显示")
    val displayEntryTitleDuringEnd = ArbText("liveDuringEndDisplayEntryTitle", "课中与下课提醒显示")

    // ── 预览阶段词与倒计时前缀 ──
    val stageBeforeClass = ArbText("liveIslandPreviewStageBeforeClass", "即将上课")
    val stageInClass = ArbText("liveIslandPreviewStageInClass", "上课中")
    val stageBeforeEnd = ArbText("liveIslandPreviewStageBeforeEnd", "下课提醒")
    val untilClassStart = ArbText("liveIslandPreviewUntilClassStart", "距上课 {time}")
    val untilClassEnd = ArbText("liveIslandPreviewUntilClassEnd", "距下课 {time}")

    // ── 预览样例数据（仅设计稿 / 测试构造；生产预览改读真实课程）──
    val sampleCourse = ArbText("liveIslandPreviewSampleCourse", "高等数学")
    val sampleCourseShort = ArbText("liveIslandPreviewSampleCourseShort", "高数")
    val sampleLocation = ArbText("liveIslandPreviewSampleLocation", "三教-401")
    val sampleTeacher = ArbText("liveIslandPreviewSampleTeacher", "张老师")
    val sampleNextClass = ArbText("liveIslandPreviewSampleNextClass", "大学物理")
    val sampleNote = ArbText("liveIslandPreviewSampleNote", "带教材与习题册")
    val previewTitleBeforeClass = ArbText("liveIslandPreviewTitleBeforeClass", "即将上课：{course}")
    val previewTitleBeforeEnd = ArbText("liveIslandPreviewTitleBeforeEnd", "下课提醒：{course}")
    val expandedPreviewCaption = ArbText(
        "liveIslandExpandedPreviewCaption",
        "Android 16 课中带进度条时，展开态由系统绘制，本设置不生效",
    )
    val expandedPreviewEmptyHint = ArbText("liveIslandExpandedPreviewEmptyHint", "已隐藏全部详情行，展开后只显示标题与摘要")
    val unfilledSuffix = ArbText("liveExpandedDetailUnfilledSuffix", "未填写，岛上不显示")
    val unfilledValue = ArbText("liveExpandedDetailUnfilledValue", "无")

    // ── 展开详情行格式（{value} 占位）──
    val detailLineShortName = ArbText("liveExpandedDetailLineShortName", "简称：{value}")
    val detailLineProgressNext = ArbText("liveExpandedDetailLineProgressNext", "下一节点：{value}")
    val detailLineProgressFinal = ArbText("liveExpandedDetailLineProgressFinal", "整节下课：{value}")
    val detailLineStatus = ArbText("liveExpandedDetailLineStatus", "状态：{value}")
    val detailLineTime = ArbText("liveExpandedDetailLineTime", "时间：{value}")
    val detailLineLocation = ArbText("liveExpandedDetailLineLocation", "地点：{value}")
    val detailLineTeacher = ArbText("liveExpandedDetailLineTeacher", "教师：{value}")
    val detailLineNext = ArbText("liveExpandedDetailLineNext", "下一节：{value}")
    val detailLineNote = ArbText("liveExpandedDetailLineNote", "备注：{value}")

    // ── 倒计时 12 种样式名（下拉项）──
    val countdownStyleSmart = ArbText("liveCountdownTextStyleSmart", "智能 中文")
    val countdownStyleSmartMinS = ArbText("liveCountdownTextStyleSmartMinS", "智能 英文")
    val countdownStyleMinuteSecondCn = ArbText("liveCountdownTextStyleMinuteSecondCn", "分秒 5分19秒")
    val countdownStyleMinuteSecondColon = ArbText("liveCountdownTextStyleMinuteSecondColon", "分秒 05:19")
    val countdownStyleMinuteSecondMinS = ArbText("liveCountdownTextStyleMinuteSecondMinS", "英文 5min19s")
    val countdownStyleMinuteSecondMinSlashS = ArbText("liveCountdownTextStyleMinuteSecondMinSlashS", "英文 5min/19s")
    val countdownStyleMinuteOnlyCn = ArbText("liveCountdownTextStyleMinuteOnlyCn", "纯分钟 5分钟")
    val countdownStyleMinuteOnlyMin = ArbText("liveCountdownTextStyleMinuteOnlyMin", "纯分钟 5min")
    val countdownStyleMinuteOnlySlash = ArbText("liveCountdownTextStyleMinuteOnlySlash", "纯分钟 5/min")
    val countdownStyleSecondOnlyCn = ArbText("liveCountdownTextStyleSecondOnlyCn", "纯秒 5秒")
    val countdownStyleSecondOnlyShort = ArbText("liveCountdownTextStyleSecondOnlyShort", "纯秒 5s")
    val countdownStyleSecondOnlySlash = ArbText("liveCountdownTextStyleSecondOnlySlash", "纯秒 5/s")

    // ── 左侧图标样式 / 内容 ──
    val labelStyleTextOnly = ArbText("miuiIslandLabelStyleTextOnly", "仅文字")
    val labelStyleIconAndText = ArbText("miuiIslandLabelStyleIconAndText", "图标+文字")
    val labelContentCourseName = ArbText("miuiIslandLabelContentCourseName", "课程名")
    val labelContentLocation = ArbText("miuiIslandLabelContentLocation", "教室")
    val labelContentCourseNameAndLocation = ArbText("miuiIslandLabelContentCourseNameAndLocation", "课程名+教室")

    // ── 字重 / 清晰度 下拉项 ──
    val fontWeightRegular = ArbText("miuiIslandLabelFontWeightRegular", "常规")
    val fontWeightMedium = ArbText("miuiIslandLabelFontWeightMedium", "中等")
    val fontWeightBold = ArbText("miuiIslandLabelFontWeightBold", "加粗")
    val renderQualityStandard = ArbText("miuiIslandLabelRenderQualityStandard", "标准")
    val renderQualityHigh = ArbText("miuiIslandLabelRenderQualityHigh", "高清")
    val renderQualityUltra = ArbText("miuiIslandLabelRenderQualityUltra", "超高清")

    // ── 展开态图标模式 下拉项 ──
    val expandedIconAppIcon = ArbText("miuiIslandExpandedIconAppIcon", "应用图标")
    val expandedIconCustomImage = ArbText("miuiIslandExpandedIconCustomImage", "自定义图片")
    val expandedIconHidden = ArbText("miuiIslandExpandedIconHidden", "不显示")

    // ── 上课前快捷操作 下拉项 ──
    val quickActionNone = ArbText("liveBeforeClassQuickActionNone", "不显示")
    val quickActionSilent = ArbText("liveBeforeClassQuickActionSilent", "打开静音")
    val quickActionDoNotDisturb = ArbText("liveBeforeClassQuickActionDoNotDisturb", "打开免打扰")
    val quickActionPriorityOnly = ArbText("liveBeforeClassQuickActionPriorityOnly", "仅放行优先通知")
    val quickActionBoth = ArbText("liveBeforeClassQuickActionBoth", "静音和免打扰")

    // ── 选图与系统权限的失败提示 ──
    // 2026-10-29 质量审核：这两句原先硬编码在 `composeP1/app/LiveDisplayHost.kt`
    // （渲染层中文字面量，进不了 ARB 也就没有多语言），搬来此处参与 Parity 对拍。
    val imagePickFailed = ArbText("liveImagePickFailed", "图片读取失败，请换一张再试")
    val doNotDisturbAccessUnavailable = ArbText(
        "liveDoNotDisturbAccessUnavailable",
        "这台设备没有勿扰权限设置页，请到系统设置里手动授权",
    )

    /** 所有对接 ARB 的文案集合（用于 Parity 测试机械对拍）。 */
    val allTexts: List<ArbText> = listOf(
        imagePickFailed,
        doNotDisturbAccessUnavailable,
        displayContentTitle,
        showCourseNameTitle,
        preferShortNameTitle,
        preferShortNameSubtitle,
        showLocationTitle,
        showCountdownTitle,
        showStageTextTitle,
        showStageTextInactiveHint,
        hidePrefixTextTitle,
        hidePrefixTextInactiveHint,
        courseNameDuplicatedHint,
        locationDuplicatedHint,
        countdownFormatLabel,
        countdownFormatHelp,
        beforeClassQuickActionTitle,
        beforeClassQuickActionSubtitle,
        beforeClassQuickActionAutoTitle,
        beforeClassQuickActionAutoSubtitle,
        beforeClassQuickActionAutoOptionOff,
        beforeClassQuickActionAutoOptionMinutes,
        islandVisualTitle,
        miuiLabelImageTitle,
        miuiLabelImageSubtitle,
        miuiLabelContentLabel,
        miuiLabelStyleLabel,
        miuiLabelLogoTitle,
        miuiLabelLogoSubtitle,
        selectImageAction,
        replaceImageAction,
        deleteAction,
        miuiLabelLogoCornerRadiusLabel,
        miuiLabelAdvancedAccordionTitle,
        miuiLabelAdvancedAccordionSubtitle,
        miuiLabelFontSizeLabel,
        miuiLabelOffsetXLabel,
        miuiLabelOffsetYLabel,
        miuiLabelFontWeightLabel,
        miuiLabelRenderQualityLabel,
        expandedIconSectionTitle,
        miuiExpandedIconLabel,
        expandedDetailGroupTitle,
        resetExpandedDetailDefaultAction,
        detailReorderHandleLabel,
        detailMoveUpAction,
        detailMoveDownAction,
        detailHiddenCaption,
        detailFieldStage,
        detailFieldShortName,
        detailFieldProgress,
        detailFieldStatus,
        detailFieldTime,
        detailFieldLocation,
        detailFieldTeacher,
        detailFieldNext,
        detailFieldNote,
        islandPreviewTitle,
        islandExpandedPreviewTitle,
        islandPreviewEmpty,
        islandPreviewSemesterUnsetHint,
        islandPreviewFollowBadge,
        stagePreviewBeforeClassAction,
        stagePreviewDuringClassAction,
        stagePreviewStopAction,
        stagePreviewStartedToast,
        stagePreviewStoppedToast,
        stagePreviewStageBeforeClass,
        stagePreviewStageDuringClass,
        testingInFlight,
        sendFailedWithError,
        displayConfigModeTitle,
        followBeforeClassDisplayTitle,
        displayEntryTitleBeforeClass,
        displayEntryTitleDuringEnd,
        stageBeforeClass,
        stageInClass,
        stageBeforeEnd,
        untilClassStart,
        untilClassEnd,
        sampleCourse,
        sampleCourseShort,
        sampleLocation,
        sampleTeacher,
        sampleNextClass,
        sampleNote,
        previewTitleBeforeClass,
        previewTitleBeforeEnd,
        expandedPreviewCaption,
        expandedPreviewEmptyHint,
        unfilledSuffix,
        unfilledValue,
        detailLineShortName,
        detailLineProgressNext,
        detailLineProgressFinal,
        detailLineStatus,
        detailLineTime,
        detailLineLocation,
        detailLineTeacher,
        detailLineNext,
        detailLineNote,
        countdownStyleSmart,
        countdownStyleSmartMinS,
        countdownStyleMinuteSecondCn,
        countdownStyleMinuteSecondColon,
        countdownStyleMinuteSecondMinS,
        countdownStyleMinuteSecondMinSlashS,
        countdownStyleMinuteOnlyCn,
        countdownStyleMinuteOnlyMin,
        countdownStyleMinuteOnlySlash,
        countdownStyleSecondOnlyCn,
        countdownStyleSecondOnlyShort,
        countdownStyleSecondOnlySlash,
        labelStyleTextOnly,
        labelStyleIconAndText,
        labelContentCourseName,
        labelContentLocation,
        labelContentCourseNameAndLocation,
        fontWeightRegular,
        fontWeightMedium,
        fontWeightBold,
        renderQualityStandard,
        renderQualityHigh,
        renderQualityUltra,
        expandedIconAppIcon,
        expandedIconCustomImage,
        expandedIconHidden,
        quickActionNone,
        quickActionSilent,
        quickActionDoNotDisturb,
        quickActionPriorityOnly,
        quickActionBoth,
    )

    // ── 枚举 → 屏上文案 ───────────────────────────────────────────

    fun countdownTextStyleLabel(style: LiveCountdownTextStyle): String = when (style) {
        LiveCountdownTextStyle.SMART -> countdownStyleSmart.zh
        LiveCountdownTextStyle.SMART_MIN_S -> countdownStyleSmartMinS.zh
        LiveCountdownTextStyle.MINUTE_SECOND_CN -> countdownStyleMinuteSecondCn.zh
        LiveCountdownTextStyle.MINUTE_SECOND_COLON -> countdownStyleMinuteSecondColon.zh
        LiveCountdownTextStyle.MINUTE_SECOND_MIN_S -> countdownStyleMinuteSecondMinS.zh
        LiveCountdownTextStyle.MINUTE_SECOND_MIN_SLASH_S -> countdownStyleMinuteSecondMinSlashS.zh
        LiveCountdownTextStyle.MINUTE_ONLY_CN -> countdownStyleMinuteOnlyCn.zh
        LiveCountdownTextStyle.MINUTE_ONLY_MIN -> countdownStyleMinuteOnlyMin.zh
        LiveCountdownTextStyle.MINUTE_ONLY_SLASH -> countdownStyleMinuteOnlySlash.zh
        LiveCountdownTextStyle.SECOND_ONLY_CN -> countdownStyleSecondOnlyCn.zh
        LiveCountdownTextStyle.SECOND_ONLY_SHORT -> countdownStyleSecondOnlyShort.zh
        LiveCountdownTextStyle.SECOND_ONLY_SLASH -> countdownStyleSecondOnlySlash.zh
    }

    fun miuiIslandLabelStyleLabel(style: MiuiIslandLabelStyle): String = when (style) {
        MiuiIslandLabelStyle.TEXT_ONLY -> labelStyleTextOnly.zh
        MiuiIslandLabelStyle.ICON_AND_TEXT -> labelStyleIconAndText.zh
    }

    fun miuiIslandLabelContentLabel(content: MiuiIslandLabelContent): String = when (content) {
        MiuiIslandLabelContent.COURSE_NAME -> labelContentCourseName.zh
        MiuiIslandLabelContent.LOCATION -> labelContentLocation.zh
        MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION -> labelContentCourseNameAndLocation.zh
    }

    fun miuiIslandLabelFontWeightLabel(weight: MiuiIslandLabelFontWeight): String = when (weight) {
        MiuiIslandLabelFontWeight.REGULAR -> fontWeightRegular.zh
        MiuiIslandLabelFontWeight.MEDIUM -> fontWeightMedium.zh
        MiuiIslandLabelFontWeight.BOLD -> fontWeightBold.zh
    }

    fun miuiIslandLabelRenderQualityLabel(quality: MiuiIslandLabelRenderQuality): String = when (quality) {
        MiuiIslandLabelRenderQuality.STANDARD -> renderQualityStandard.zh
        MiuiIslandLabelRenderQuality.HIGH -> renderQualityHigh.zh
        MiuiIslandLabelRenderQuality.ULTRA -> renderQualityUltra.zh
    }

    fun miuiIslandExpandedIconModeLabel(mode: MiuiIslandExpandedIconMode): String = when (mode) {
        MiuiIslandExpandedIconMode.APP_ICON -> expandedIconAppIcon.zh
        MiuiIslandExpandedIconMode.CUSTOM_IMAGE -> expandedIconCustomImage.zh
        MiuiIslandExpandedIconMode.HIDDEN -> expandedIconHidden.zh
    }

    fun liveBeforeClassQuickActionLabel(action: LiveBeforeClassQuickAction): String = when (action) {
        LiveBeforeClassQuickAction.NONE -> quickActionNone.zh
        LiveBeforeClassQuickAction.SILENT -> quickActionSilent.zh
        LiveBeforeClassQuickAction.DO_NOT_DISTURB -> quickActionDoNotDisturb.zh
        LiveBeforeClassQuickAction.PRIORITY_ONLY -> quickActionPriorityOnly.zh
        LiveBeforeClassQuickAction.BOTH -> quickActionBoth.zh
    }

    fun liveExpandedDetailFieldLabel(field: LiveExpandedDetailField): String = when (field) {
        LiveExpandedDetailField.STAGE -> detailFieldStage.zh
        LiveExpandedDetailField.SHORT_NAME -> detailFieldShortName.zh
        LiveExpandedDetailField.PROGRESS -> detailFieldProgress.zh
        LiveExpandedDetailField.STATUS -> detailFieldStatus.zh
        LiveExpandedDetailField.TIME -> detailFieldTime.zh
        LiveExpandedDetailField.LOCATION -> detailFieldLocation.zh
        LiveExpandedDetailField.TEACHER -> detailFieldTeacher.zh
        LiveExpandedDetailField.NEXT_COURSE -> detailFieldNext.zh
        LiveExpandedDetailField.NOTE -> detailFieldNote.zh
    }

    // ── 占位符格式化 ─────────────────────────────────────────────

    fun autoMinutesLabel(minutes: Int): String =
        beforeClassQuickActionAutoOptionMinutes.filled("minutes", minutes.toString())

    fun logoCornerRadiusLabel(value: String): String =
        miuiLabelLogoCornerRadiusLabel.filled("value", value)

    fun fontSizeLabel(value: String): String = miuiLabelFontSizeLabel.filled("value", value)

    fun offsetXLabel(value: String): String = miuiLabelOffsetXLabel.filled("value", value)

    fun offsetYLabel(value: String): String = miuiLabelOffsetYLabel.filled("value", value)

    /** 快捷操作「自动执行」下拉项文案：0 → 不自动执行；其余 → 上课前 N 分钟。 */
    fun quickActionAutoMinuteLabel(minutes: Int): String =
        if (minutes <= 0) beforeClassQuickActionAutoOptionOff.zh else autoMinutesLabel(minutes)
}
