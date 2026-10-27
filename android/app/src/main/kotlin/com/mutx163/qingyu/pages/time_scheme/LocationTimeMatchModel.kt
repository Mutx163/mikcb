package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.LocationTimeMatchLogic

/**
 * 地点作息匹配页（`lib/screens/location_time_match_screen.dart`，1 131 行）模型层。
 *
 * ## 这一页在做什么
 *
 * 一条规则 = 「一组地点关键词 → 绑一套时间模板」。列表页把规则摊成卡（可开关、可编辑、
 * 可删），并给一个「试匹配」输入框让人当场验证某个地点会命中哪套模板；底部还能
 * 「重新匹配当前课表」，把已手工指定模板的课程恢复成自动匹配。
 *
 * ## 算数不在这里
 *
 * 归一化与命中判定 Phase 2 已迁好（[LocationTimeMatchLogic]，与 Dart
 * `lib/domain/location_time_match_logic.dart` 逐行等价）：全角/半角、中点/破折号族、
 * 括号剔除、大小写，以及 prefix/contains/exact 三种匹配方式。本类只做屏层装配：
 *
 * 1. **卡片副标题**：`时间模板：{名字} · 关键词：{关键词}` —— 两个占位符各自有 ARB 键，
 *    拼接顺序照 Dart（`locationTimeMatchBoundScheme` + `locationTimeMatchKeywordsLine`）；
 * 2. **未知模板兜底**：绑定的模板已被删时显示「未知时间模板」，不是空白；
 * 3. **空态**：一组规则都没有时，列表里换成「新建地点组」一行；
 * 4. **试匹配预览**：输入框非空 → 调 [LocationTimeMatchLogic.match]，命中显示
 *    「将匹配：{组} · {模板}，关键词 {关键词}」，未命中显示「未命中任何地点组…」。
 */
class LocationTimeMatchModel(
    /** 地点组清单（顺序即展示顺序）。 */
    val groups: List<LocationTimeGroup> = emptyList(),
    /** 模板 id → 模板名。绑定的模板被删了就不在表里，走「未知时间模板」兜底。 */
    val schemeNames: Map<String, String> = emptyMap(),
) {

    val isEmpty: Boolean get() = groups.isEmpty()

    val title: String get() = LocationTimeMatchStrings.title.zh
    val createGroupLabel: String get() = LocationTimeMatchStrings.createGroup.zh
    val applyActiveLabel: String get() = LocationTimeMatchStrings.applyActive.zh
    val subtitle: String get() = LocationTimeMatchStrings.subtitle.zh
    val weekAxisNote: String get() = LocationTimeMatchStrings.weekAxisNote.zh

    /**
     * 列表页尾部说明的完整文本。
     *
     * Dart `HyperosListView` 里是两段：`HyperosSectionDescription(locationTimeMatchSubtitle)`
     * 与（有规则时）底部「重新匹配」行。这里把说明单独暴露，尾部行动作由
     * [applyActiveLabel] + 宿主回调承担。
     */
    val footerNote: String get() = subtitle

    /** 一张规则卡的全部屏上文字（Dart `_buildGroupCard`）。 */
    data class GroupCard(
        val groupId: String,
        val title: String,
        val subtitle: String,
        val enabled: Boolean,
        val boundSchemeName: String,
        val keywordText: String,
        val keywordsEmpty: Boolean,
    )

    fun cards(): List<GroupCard> = groups.map { cardOf(it) }

    fun card(groupId: String): GroupCard? =
        groups.firstOrNull { it.id == groupId }?.let { cardOf(it) }

    private fun cardOf(group: LocationTimeGroup): GroupCard {
        // 模板被删 → 兜底「未知时间模板」（Dart: firstOrNull ?? l10n.locationTimeMatchUnknownScheme）
        val schemeName = schemeNames[group.timeSchemeId]
            ?: LocationTimeMatchStrings.unknownScheme.zh
        // 关键词为空 → 「未设置关键词」（Dart: keywordSummary.isEmpty ? … : keywordSummary）
        val keywordsEmpty = group.keywordSummary.isEmpty()
        val keywordText = if (keywordsEmpty) {
            LocationTimeMatchStrings.noKeywords.zh
        } else {
            group.keywordSummary
        }
        // 副标题两个占位符各走各的 ARB 键，中间用 Dart 原文的 ' · ' 连接。
        val subtitle = LocationTimeMatchStrings.boundScheme.filled("name", schemeName) +
            " · " +
            LocationTimeMatchStrings.keywordsLine.filled("keywords", keywordText)
        return GroupCard(
            groupId = group.id,
            title = group.name,
            subtitle = subtitle,
            enabled = group.enabled,
            boundSchemeName = schemeName,
            keywordText = keywordText,
            keywordsEmpty = keywordsEmpty,
        )
    }

    // ── 试匹配预览（Dart `_previewHint` / `_previewResult` 那段） ──

    /**
     * 试匹配结果的屏上文本。
     *
     * @param input 输入框里的地点原文；空白返回 null（Dart 同口径：空输入不显示结果）。
     */
    fun previewText(input: String): String? {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) return null
        val hit = LocationTimeMatchLogic.match(trimmed, groups)
            ?: return LocationTimeMatchStrings.previewNoMatch.zh
        // 命中的组可能已经绑了不存在的模板，仍然按「未知时间模板」显示，
        // 不在这里静默跳过（否则用户看到一条「将匹配：X · 」，后半截空着）。
        val schemeName = schemeNames[hit.timeSchemeId]
            ?: LocationTimeMatchStrings.unknownScheme.zh
        return LocationTimeMatchStrings.previewResult.filled(
            "group" to hit.groupName,
            "scheme" to schemeName,
            "keyword" to hit.matchedKeyword.pattern,
        )
    }

    /** 输入框提示语（Dart `locationTimeMatchPreviewHint`）。 */
    val previewHint: String get() = LocationTimeMatchStrings.previewHint.zh
    val previewLabel: String get() = LocationTimeMatchStrings.previewLabel.zh

    // ── 「重新匹配当前课表」的结果文案 ──

    /** 重新匹配确认弹层的正文（Dart `locationTimeMatchApplyMessage`，占位符 {count}）。 */
    fun applyMessage(matchedCourseCount: Int): String =
        LocationTimeMatchStrings.applyMessage.filled("count", matchedCourseCount.toString())

    val applyTitle: String get() = LocationTimeMatchStrings.applyTitle.zh
    val applyConfirmLabel: String get() = LocationTimeMatchStrings.applyConfirm.zh

    /**
     * 重新匹配完成后的结果文案（Dart 三种形态）。
     *
     * - 一门都没命中 → 「没有匹配到可套用的课程」；
     * - 命中但钟点无需改写 → 「已重新匹配 {matched} 门，钟点无需改写」；
     * - 正常改写 → 「已重新匹配 {matched} 门，更新 {updated} 门钟点」。
     *
     * 判据顺序照 Dart：先判 matched == 0，再判 updated == 0。
     */
    fun applyResultMessage(matched: Int, updated: Int): String = when {
        matched <= 0 -> LocationTimeMatchStrings.applyNoneMatched.zh
        updated <= 0 -> LocationTimeMatchStrings.applyAlreadyAligned.filled(
            "matched" to matched.toString(),
        )
        else -> LocationTimeMatchStrings.applyUpdated.filled(
            "matched" to matched.toString(),
            "updated" to updated.toString(),
        )
    }

    /** 超出模板节数、已取消套用时的附加提示（Dart `locationTimeMatchApplyOverflowResult`）。 */
    fun applyOverflowMessage(matched: Int, overflowCount: Int, examples: List<String>): String {
        val head = LocationTimeMatchStrings.applyOverflowResult.filled(
            "matched" to matched.toString(),
            "count" to overflowCount.toString(),
        )
        if (examples.isEmpty()) return head
        return head + " " + LocationTimeMatchStrings.applyOverflowHint.filled(
            "names" to examples.joinToString("、"),
        )
    }

    // ── 删除确认 ──

    fun deleteTitle(): String = LocationTimeMatchStrings.deleteTitle.zh

    fun deleteMessage(name: String): String =
        LocationTimeMatchStrings.deleteMessage.filled("name", name)

    val deletedMessage: String get() = LocationTimeMatchStrings.deleted.zh

    // ── 编辑页（Dart `_LocationTimeGroupEditorScreen`）的关键校验 ──

    /** 组名不能空（Dart `locationTimeMatchNameRequired`）。 */
    fun validateName(raw: String): String? =
        if (raw.trim().isEmpty()) LocationTimeMatchStrings.nameRequired.zh else null

    /** 至少要一个关键词（Dart `locationTimeMatchKeywordRequired`）。 */
    fun validateKeywords(keywords: List<String>): String? =
        if (keywords.none { it.trim().isNotEmpty() }) {
            LocationTimeMatchStrings.keywordRequired.zh
        } else {
            null
        }

    /**
     * 关键词「过短容易误匹配」的提示（Dart `locationTimeMatchKeywordTooShort`）。
     *
     * 判据照 Dart：归一化后长度 < 2 才提示；单个汉字也算过短（A1 这类两字符是底线）。
     */
    fun keywordTooShortHint(pattern: String): String? {
        val normalized = LocationTimeMatchLogic.normalizePattern(pattern)
        return if (normalized.length < 2) LocationTimeMatchStrings.keywordTooShort.zh else null
    }

    /** 关键词已被别的组占用（Dart `locationTimeMatchKeywordUsedByGroup`）。 */
    fun keywordOwnerHint(pattern: String, editingGroupId: String?): String? {
        val owner = LocationTimeMatchLogic.groupNameOwningPattern(
            groups = groups,
            pattern = pattern,
            excludingGroupId = editingGroupId,
        ) ?: return null
        return LocationTimeMatchStrings.keywordUsedByGroup.filled("group", owner)
    }

    /** 三种匹配方式的显示名（Dart `matchModeLabel` 三选一）。 */
    fun modeLabel(mode: LocationKeywordMatchMode): String = when (mode) {
        LocationKeywordMatchMode.PREFIX -> LocationTimeMatchStrings.modePrefix.zh
        LocationKeywordMatchMode.CONTAINS -> LocationTimeMatchStrings.modeContains.zh
        LocationKeywordMatchMode.EXACT -> LocationTimeMatchStrings.modeExact.zh
    }

    val modeLabelTitle: String get() = LocationTimeMatchStrings.modeLabel.zh
    val savedMessage: String get() = LocationTimeMatchStrings.saved.zh
    val saveFailedMessage: String get() = LocationTimeMatchStrings.saveFailed.zh
}
