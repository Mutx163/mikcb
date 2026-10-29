package com.mutx163.qingyu.pages.time_scheme

/**
 * 地点作息匹配 (Location Time Match) 模块用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * **逐字抄录，不许改写**：每一条都在 [LocationTimeMatchStringsParityTest] 里与 ARB 机械比对，
 * 键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+ 重新生成 `gen-l10n`，
 * 再同步这里。
 *
 * 命名与 ARB 键逐字一致（`locationTimeMatchTitle` 等），便于 `grep` 双向核对。
 * 对应页面：`lib/screens/location_time_match_screen.dart`（列表页 + 编辑页 + 两个对话框）。
 * 占位符用 [ArbText.filled] 替换，顺序与 ARB 一致。
 */
data class ArbText(val key: String, val zh: String) {
    /** 替换模板里的单个占位符（`{name}` → [value]）。 */
    fun filled(name: String, value: String): String = zh.replace("{$name}", value)

    /** 替换多个占位符，按传入顺序逐个替换。 */
    fun filled(vararg pairs: Pair<String, String>): String {
        var result = zh
        for ((name, value) in pairs) {
            result = result.replace("{$name}", value)
        }
        return result
    }
}

object LocationTimeMatchStrings {

    // ── 设置页入口 ──
    val entryTitle = ArbText("locationTimeMatchEntryTitle", "地点作息匹配")
    val entrySubtitle = ArbText("locationTimeMatchEntrySubtitle", "按上课地点关键词自动选用时间模板")

    // ── 列表页 ──
    val title = ArbText("locationTimeMatchTitle", "地点作息匹配")
    val subtitle = ArbText(
        "locationTimeMatchSubtitle",
        "按地点关键词匹配时间模板，仅更新命中课程的钟点",
    )
    val weekAxisNote = ArbText(
        "locationTimeMatchWeekAxisNote",
        "说明：首页左侧时间列仍显示课表默认模板；卡片、详情和实况上的钟点以地点匹配结果为准。",
    )
    val previewLabel = ArbText("locationTimeMatchPreviewLabel", "试匹配地点")
    val previewHint = ArbText("locationTimeMatchPreviewHint", "例如 A1062 或 A主201")
    val previewNoMatch = ArbText(
        "locationTimeMatchPreviewNoMatch",
        "未命中任何地点组，将使用课表默认时间模板",
    )
    val previewResult = ArbText(
        "locationTimeMatchPreviewResult",
        "将匹配：{group} · {scheme}，关键词 {keyword}",
    )
    val applyActive = ArbText("locationTimeMatchApplyActive", "重新匹配当前课表")

    /**
     * 「重新匹配当前课表」**能力层未接入**时给的一句实话。
     *
     * 复用 ARB 里已有的 `aboutUnavailable`（"不可用"）——清单 §1.2 点名的正是这个先例
     * （`b.general` 的「立即试一次」在能力未到位时就取它）。
     *
     * **故意不新造键**：新键要六份 ARB 同步 + 重新 `gen-l10n`，那会把别批次正在改的
     * `lib/l10n/app_localizations*.dart` 卷进这次提交。等真正的
     * `TimetableLocationRuleService.applyToActiveProfile` 入口在 Kotlin 侧落地，
     * 这条和宿主里那个分支一起删掉。
     */
    val applyUnavailable = ArbText("aboutUnavailable", "不可用")
    val applyTitle = ArbText("locationTimeMatchApplyTitle", "重新匹配当前课表？")
    val applyMessage = ArbText(
        "locationTimeMatchApplyMessage",
        "当前有 {count} 门课程命中地点规则。节次适配的课程会恢复自动匹配并同步钟点；" +
            "此前手动指定的模板将被清除，未命中的课程不会改变。",
    )
    val applyConfirm = ArbText("locationTimeMatchApplyConfirm", "重新匹配")
    val applyUpdated = ArbText("locationTimeMatchApplyUpdated", "已重新匹配 {matched} 门，更新 {updated} 门钟点")
    val applyAlreadyAligned = ArbText("locationTimeMatchApplyAlreadyAligned", "已重新匹配 {matched} 门，钟点无需改写")
    val applyNoneMatched = ArbText("locationTimeMatchApplyNoneMatched", "没有匹配到可套用的课程")
    val applyOverflowResult = ArbText(
        "locationTimeMatchApplyOverflowResult",
        "已匹配 {matched} 门课程。另有 {count} 门超出模板节数，已取消套用",
    )
    val applyOverflowHint = ArbText("locationTimeMatchApplyOverflowHint", "未套用示例：{names}")
    val empty = ArbText("locationTimeMatchEmpty", "还没有地点组")
    val createGroup = ArbText("locationTimeMatchCreateGroup", "新建地点组")
    val editGroup = ArbText("locationTimeMatchEditGroup", "编辑地点组")
    val unknownScheme = ArbText("locationTimeMatchUnknownScheme", "未知时间模板")
    val noKeywords = ArbText("locationTimeMatchNoKeywords", "未设置关键词")
    val boundScheme = ArbText("locationTimeMatchBoundScheme", "时间模板：{name}")
    val keywordsLine = ArbText("locationTimeMatchKeywordsLine", "关键词：{keywords}")
    val deleteTitle = ArbText("locationTimeMatchDeleteTitle", "删除地点组？")
    val deleteMessage = ArbText(
        "locationTimeMatchDeleteMessage",
        "确定删除匹配规则 {name}？自动匹配的课程将恢复默认作息，手动指定的课程不受影响。",
    )
    val deleted = ArbText("locationTimeMatchDeleted", "已删除地点组")
    /** 删除落盘失败（Dart `_deleteGroup:345-352` 用的通用 `l10n.deleteFailed`）。 */
    val deleteFailed = ArbText("deleteFailed", "删除失败")

    // ── 编辑页表单项 ──
    val groupNameLabel = ArbText("locationTimeMatchGroupNameLabel", "地点组名称")
    val groupNameHint = ArbText("locationTimeMatchGroupNameHint", "例如：主教学楼或其他教学楼")
    val boundSchemeLabel = ArbText("locationTimeMatchBoundSchemeLabel", "绑定时间模板")
    val needTimeScheme = ArbText("locationTimeMatchNeedTimeScheme", "请先创建一套时间模板")
    val enabledLabel = ArbText("locationTimeMatchEnabledLabel", "启用此地点组")
    val keywordsSection = ArbText("locationTimeMatchKeywordsSection", "地点关键词")
    val keywordsHelp = ArbText(
        "locationTimeMatchKeywordsHelp",
        "可从地点识别楼栋或填写关键词如 A主、A1。建议采用前缀匹配，优先匹配较长关键词。",
    )
    val selectedKeywords = ArbText("locationTimeMatchSelectedKeywords", "已选关键词")
    val noSelectedKeywords = ArbText("locationTimeMatchNoSelectedKeywords", "尚未添加关键词")
    val pickFromLocations = ArbText("locationTimeMatchPickFromLocations", "从课表地点选择")
    val buildingSuggestions = ArbText("locationTimeMatchBuildingSuggestions", "从课表识别的楼栋")
    val noBuildingSuggestions = ArbText("locationTimeMatchNoBuildingSuggestions", "未识别到楼栋地点")
    val addBuilding = ArbText("locationTimeMatchAddBuilding", "添加")
    val addAllBuildings = ArbText("locationTimeMatchAddAllBuildings", "一键添加全部未配置楼栋")
    val buildingRoomCount = ArbText("locationTimeMatchBuildingRoomCount", "{count} 间教室")
    val buildingGateTags = ArbText("locationTimeMatchBuildingGateTags", "标签：{tags}")
    val keywordExtracted = ArbText("locationTimeMatchKeywordExtracted", "已从地点提取关键词 {keyword}")
    val keywordAlreadyExists = ArbText("locationTimeMatchKeywordAlreadyExists", "关键词已存在")
    val keywordUsedByGroup = ArbText("locationTimeMatchKeywordUsedByGroup", "关键词已被 {group} 使用")
    val addKeyword = ArbText("locationTimeMatchAddKeyword", "手动添加关键词")
    val keywordLabel = ArbText("locationTimeMatchKeywordLabel", "关键词")
    val keywordHint = ArbText("locationTimeMatchKeywordHint", "A1、A主、六教")
    val modeLabel = ArbText("locationTimeMatchModeLabel", "匹配模式")
    val modePrefix = ArbText("locationTimeMatchModePrefix", "前缀")
    val modeContains = ArbText("locationTimeMatchModeContains", "包含")
    val modeExact = ArbText("locationTimeMatchModeExact", "精确")
    val keywordTooShort = ArbText("locationTimeMatchKeywordTooShort", "关键词过短，容易误匹配")
    val nameRequired = ArbText("locationTimeMatchNameRequired", "请填写地点组名称")
    val keywordRequired = ArbText("locationTimeMatchKeywordRequired", "请至少添加一个关键词")
    val saved = ArbText("locationTimeMatchSaved", "地点组已保存")
    val saveFailed = ArbText("locationTimeMatchSaveFailed", "保存失败")
    val matchedSchemeHint = ArbText("locationTimeMatchedSchemeHint", "地点匹配 · {scheme}")

    // ── 通用动作（沿用 ARB 通用键，对齐既有页面先例）──
    val saveAction = ArbText("saveAction", "保存")
    val cancelAction = ArbText("cancelAction", "取消")
    val deleteAction = ArbText("deleteAction", "删除")
    val editAction = ArbText("editAction", "编辑")

    /** 匹配模式的中文标签（对应 ARB `locationTimeMatchMode*`，顺序同 enum）。 */
    fun modeLabel(mode: String): ArbText = when (mode) {
        "contains" -> modeContains
        "exact" -> modeExact
        else -> modePrefix
    }

    /** 所有 ARB 文案清单，用于机械化单测逐字对拍。 */
    val allTexts: List<ArbText> by lazy {
        listOf(
            entryTitle,
            entrySubtitle,
            title,
            subtitle,
            weekAxisNote,
            previewLabel,
            previewHint,
            previewNoMatch,
            previewResult,
            applyActive,
            applyTitle,
            applyMessage,
            applyConfirm,
            applyUpdated,
            applyAlreadyAligned,
            applyNoneMatched,
            applyOverflowResult,
            applyOverflowHint,
            empty,
            createGroup,
            editGroup,
            unknownScheme,
            noKeywords,
            boundScheme,
            keywordsLine,
            deleteTitle,
            deleteMessage,
            deleted,
            deleteFailed,
            groupNameLabel,
            groupNameHint,
            boundSchemeLabel,
            needTimeScheme,
            enabledLabel,
            keywordsSection,
            keywordsHelp,
            selectedKeywords,
            noSelectedKeywords,
            pickFromLocations,
            buildingSuggestions,
            noBuildingSuggestions,
            addBuilding,
            addAllBuildings,
            buildingRoomCount,
            buildingGateTags,
            keywordExtracted,
            keywordAlreadyExists,
            keywordUsedByGroup,
            addKeyword,
            keywordLabel,
            keywordHint,
            modeLabel,
            modePrefix,
            modeContains,
            modeExact,
            keywordTooShort,
            nameRequired,
            keywordRequired,
            saved,
            saveFailed,
            applyUnavailable,
            matchedSchemeHint,
            saveAction,
            cancelAction,
            deleteAction,
            editAction,
        )
    }
}
