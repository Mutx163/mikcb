package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.LocationTimeMatchLogic
import java.util.UUID

/**
 * 时间模板选项（地点组编辑页要选「绑定哪一套模板」）。
 *
 * **顺序就是 Dart `provider.timeSchemes` 的顺序**：编辑页在「当前组还没绑模板」时
 * 默认选中 `schemes.first`（`location_time_match_screen.dart:648-650`），所以调用方
 * 必须按模板列表原顺序构造，不要按名字排序。
 */
data class LocationTimeSchemeOption(val id: String, val name: String)

/**
 * 新建 / 编辑地点组的表单快照。
 *
 * 与 Dart `_LocationTimeGroupEditorScreenState` 的字段一一对应：
 * `_nameController.text` / `_timeSchemeId` / `_enabled` / `_keywords`。
 *
 * [editingId] 为 null = 新建；非 null = 编辑既有组。
 * [priority] 与 [sourceSchoolId] 是表单上看不到的存量字段：编辑时**原样保留**，
 * 新建时固定 0 / null（Dart `createGroup` 的默认参数，见 [LocationTimeGroupController]）。
 */
data class LocationTimeGroupDraft(
    val editingId: String?,
    val name: String,
    val timeSchemeId: String,
    val enabled: Boolean,
    val keywords: List<LocationKeyword>,
    val priority: Int = 0,
    val sourceSchoolId: String? = null,
)

/**
 * 一次分组写入的纯结果。
 *
 * `Applied.groups` 就是**交给落盘层的新整份列表**（顺序即展示顺序）；
 * 控制器从不自己写盘，也不缓存状态——每次调用都基于构造时的 [LocationTimeGroupController.groups] 现算。
 */
sealed interface LocationTimeGroupChange {

    /**
     * 可以落盘。
     *
     * @param groups 新整份列表（可直接交给 `location_time_groups` 的写入口）
     * @param target 被新建/修改的那一组；删除时为 null
     */
    data class Applied(
        val groups: List<LocationTimeGroup>,
        val target: LocationTimeGroup?,
    ) : LocationTimeGroupChange

    /** 表单校验没过（文案来自 [LocationTimeGroupEditorValidation]，与编辑页同一口径）。 */
    data class Rejected(val message: String) : LocationTimeGroupChange

    /** 目标组不存在（别处已删 / 传入 id 过期）。调用方应回列表或提示保存失败，不要伪造成功。 */
    data object Missing : LocationTimeGroupChange
}

/** 「重新匹配当前课表」点击后的下一步（先判有没有候选，再决定弹不弹确认框）。 */
sealed interface LocationTimeApplyDecision {

    /** 一门课程都没命中：Dart 直接 toast `locationTimeMatchApplyNoneMatched`，不弹确认框。 */
    data object NoMatch : LocationTimeApplyDecision

    /** 有候选：弹确认框，文案照 Dart `_applyToActive`（:180-190）。 */
    data class Confirm(
        val title: String,
        val message: String,
        val confirmLabel: String,
    ) : LocationTimeApplyDecision
}

/** 套用结果的语气（Dart `AppToastKind` 的五分支对应物）。 */
enum class LocationTimeApplyToastKind { SUCCESS, WARNING, INFO }

/**
 * 「重新匹配当前课表」的统计（Dart `LocationTimeApplyStats` 里页面用到的四项）。
 *
 * 注意 [matched] 只算**节次能完整坐进模板**的课程；[overflowCount] 是命中了地点但
 * 节次越界、被拒绝套用的课程（`timetable_location_rule_service.dart:429-453`）。
 */
data class LocationTimeApplyOutcome(
    val matched: Int,
    val updated: Int,
    val overflowCount: Int = 0,
    val overflowNames: List<String> = emptyList(),
)

/** 套用后要展示的一条提示（文案 + 可选第二行 + 语气）。 */
data class LocationTimeApplyToast(
    val message: String,
    val description: String?,
    val kind: LocationTimeApplyToastKind,
)

/**
 * 地点作息匹配页的**纯控制器**（无 Compose / Android 依赖，JVM 可测）。
 *
 * 覆盖 Dart `lib/screens/location_time_match_screen.dart`（1 131 行）里属于页面职责的
 * 状态变化，判据逐条对拍 Dart 与 `timetable_location_rule_service.dart`：
 *
 * | 动作 | Dart 出处 | 本控制器语义 |
 * |---|---|---|
 * | 新建组 | `_save`:1032-1095 → `createLocationTimeGroup`（`timetable_provider.dart:1523`）→ `TimetableLocationRuleService.createGroup`:174-203 | 组名 trim、关键词 trim 并丢弃空串；id = UUID v4；`priority` 固定 0、`sourceSchoolId` 固定 null；新组**追加到列表末尾** |
 * | 编辑组 | `_save` → `updateLocationTimeGroup`（`timetable_provider.dart:1542`）→ `updateGroup`:205-241 | 只替换目标组；`id`/`priority`/`sourceSchoolId` 原样保留；列表顺序不变 |
 * | 开关组 | `location_time_match_screen.dart:129-146` 的 `HyperosSwitchTile` | 只翻 `enabled`，其余字段原样；**停用不等于删除**——`LocationTimeMatchLogic.match` 会跳过停用组（`location_time_match_logic.dart:101`） |
 * | 删除组 | `_deleteGroup`:327-368 | 删除前必须由 UI 弹确认框（标题 `deleteTitle`、正文 `deleteMessage(name)`、确认词 `deleteAction`、`destructiveConfirm: true`）；确认后本控制器才按 id 过滤 |
 * | 重新匹配当前课表 | `_applyToActive`:162-326 | **页面只负责「候选数 → 不弹框 / 弹确认 → 结果文案」**；真正的钟点重写与 override 释放属于 `TimetableLocationRuleService.applyToActiveProfile`:286-585（见下文） |
 * | 校验 | `_save`:1032-1072 | 直接复用 [LocationTimeGroupEditorValidation]，**不另写一套顺序**：空名称 → 未选模板 → 空关键词 → 关键词被别的组占用 |
 *
 * ## 「重新匹配当前课表」到底做什么（去 Dart 核过，不是猜的）
 *
 * 1. **候选数**：`provider.courses.where((c) => provider.matchLocationTime(c.location) != null).length`
 *    （`:168-170`；`matchLocationTime` 就是 `LocationTimeMatchLogic.match`，只算启用中且绑了模板的组）。
 * 2. 候选数为 0 → `applyNoneMatched` toast，**不弹确认框**；否则弹确认框
 *    `applyTitle` / `applyMessage(count)` / `applyConfirm`（`:176-186`）。
 * 3. 确认后调 `applyLocationTimeRulesToActiveProfile()`：逐门课程
 *    - 有 `hasCustomTime` 的课程**完全不动**（适配脚本下发的真实钟点是权威值，`:396-400`）；
 *    - 未命中的课程不动；
 *    - 命中的组绑的模板不存在 → 不动；
 *    - 节次 `startSection/endSection` 坐不进模板节数 → 记 overflow、**不写 override 也不改钟点**；
 *    - 其余：先清 `timeSchemeIdOverride`（恢复自动匹配），再按模板对应节次重写 `startTime/endTime`。
 *    `matched` 只统计最后这类「完整坐进模板」的课程；`updated` 只统计钟点或 override 真变了的。
 * 4. 结果 toast 是五个分支（先 `updated>0 && overflow>0`，再 `updated>0`，再
 *    `overflow>0 && matched>0`，再 `matched>0`，否则 none），见 [applyToast]。
 *
 * **本控制器不执行第 3 步的写入**：那是一次整表课程重写 + 落盘，需要仓储/服务层入口
 * （`TimetableLocationRuleService` 的 Kotlin 版尚未接；本批只交付页面半边）。
 * 页面宿主在未接该能力时给出「尚未接入」的实话，不伪造成功。
 *
 * ## 与 Dart 的唯一有意差异：编辑目标消失时不假报「已保存」
 *
 * Dart `_save` 调 `updateLocationTimeGroup` 后**不看返回值**（`updateGroup` 找不到 id 时返回 null，
 * `location_time_match_screen.dart:1074-1094` 仍会 pop + toast「地点组已保存」）。这属于 Dart 的
 * 既有 bug，与「不允许假成功」的交付硬约束冲突，所以本控制器的 [save] 在编辑目标不存在时返回
 * [LocationTimeGroupChange.Missing]，由宿主提示「保存失败」。除这条外，其余判据逐条照 Dart。
 *
 * ## 落盘格式
 *
 * 新列表的每一组都走 `LocationTimeGroup.toJsonMap()` / `fromJson()` 往返，顶层 key 是
 * `TimetableStore.KEY_LOCATION_TIME_GROUPS = "location_time_groups"`（与 Dart 同名）。
 * 本控制器不改字段、不加字段。
 *
 * @param groups 当前分组列表（顺序即展示顺序）
 * @param schemes 可选时间模板，**顺序必须是快照里 `timeSchemes` 的原顺序**
 * @param availableLocations 课表里出现过的地点（去重后），供试匹配/楼栋关键词建议
 * @param idFactory 新组 id 生成器；默认 UUID v4。Dart 出处：`TimetableLocationRuleService.createGroup`
 *   的 `id: const Uuid().v4()`（`lib/services/timetable_location_rule_service.dart:190`）；
 *   Kotlin 既有等价物：`TimetableCourseService` 头注释「Dart Uuid().v4() → UUID.randomUUID().toString()」
 *   （`android/.../course/TimetableCourseService.kt:31`）。
 */
class LocationTimeGroupController(
    val groups: List<LocationTimeGroup>,
    val schemes: List<LocationTimeSchemeOption> = emptyList(),
    val availableLocations: List<String> = emptyList(),
    private val idFactory: () -> String = { UUID.randomUUID().toString() },
) {

    /** 模板 id → 名字（顺序同 [schemes]）。绑定模板被删时这里没有那个 id，卡片兜底「未知时间模板」。 */
    val schemeNames: Map<String, String> = LinkedHashMap<String, String>().apply {
        for (scheme in schemes) put(scheme.id, scheme.name)
    }

    /** 屏层模型（卡片、试匹配、模板名兜底、套用文案都在那一份里，不重复实现）。 */
    fun model(): LocationTimeMatchModel = LocationTimeMatchModel(groups = groups, schemeNames = schemeNames)

    /**
     * 新建表单的初始值（Dart `initState`:404-412 + `build`:648-650）：
     * 名称空、`enabled = true`、无关键词；模板为空时默认选第一套模板（没有模板就保持空串，
     * 保存时由校验给出 `locationTimeMatchNeedTimeScheme`）。
     */
    fun newDraft(): LocationTimeGroupDraft = LocationTimeGroupDraft(
        editingId = null,
        name = "",
        timeSchemeId = schemes.firstOrNull()?.id ?: "",
        enabled = true,
        keywords = emptyList(),
        priority = 0,
        sourceSchoolId = null,
    )

    /**
     * 编辑表单的初始值。
     *
     * 与 Dart 一致：
     * - 名称/关键词/启用状态照抄原组；
     * - `timeSchemeId` 为空且模板列表非空时，build 阶段回落到第一套模板（`:648-650`）；
     * - 绑定的模板已被删（id 不在 [schemes] 里）时**不回落到第一套**：Dart 只在
     *   `_timeSchemeId.isEmpty` 时回落，非空但失效的 id 会原样保留，保存时由写入层报
     *   `time_scheme_not_found`。这里保持同一行为，不静默改绑。
     */
    fun editDraft(groupId: String): LocationTimeGroupDraft? {
        val group = groups.firstOrNull { it.id == groupId } ?: return null
        val schemeId = if (group.timeSchemeId.isEmpty()) {
            schemes.firstOrNull()?.id ?: ""
        } else {
            group.timeSchemeId
        }
        return LocationTimeGroupDraft(
            editingId = group.id,
            name = group.name,
            timeSchemeId = schemeId,
            enabled = group.enabled,
            keywords = group.keywords,
            priority = group.priority,
            sourceSchoolId = group.sourceSchoolId,
        )
    }

    /** 试匹配输入框的结果（空输入 → null，交给宿主显示提示语）。 */
    fun previewText(input: String): String? = model().previewText(input)

    /**
     * 保存表单（新建或编辑）。
     *
     * 顺序照 Dart `_save`：先 trim 名称与关键词、丢弃空关键词，再走
     * [LocationTimeGroupEditorValidation]。校验失败返回 [LocationTimeGroupChange.Rejected]，
     * **不产生任何新列表**（避免「一半已改」）。
     *
     * 新建（Dart `createGroup`）：`priority` 固定 0、`sourceSchoolId` null、追加到末尾。
     * 编辑（Dart `updateGroup`）：只改 name / timeSchemeId / enabled / keywords，
     * `id` / `priority` / `sourceSchoolId` 原样保留。
     */
    fun save(draft: LocationTimeGroupDraft): LocationTimeGroupChange {
        val name = draft.name.trim()
        val keywords = draft.keywords
            .map { it.copy(pattern = it.pattern.trim()) }
            .filter { it.pattern.isNotEmpty() }
        val error = LocationTimeGroupEditorValidation.saveError(
            model = model(),
            name = name,
            timeSchemeId = draft.timeSchemeId,
            keywords = keywords,
            editingGroupId = draft.editingId,
        )
        if (error != null) return LocationTimeGroupChange.Rejected(error)

        // 模板存在性：Dart 的页面校验只判「非空」，真正查表的是 provider/service
        // （`TimetableLocationRuleService.createGroup:183-185` / `updateGroup:219-222`，
        // 抛 ArgumentError('time_scheme_not_found')，编辑页再 `localizeServiceMessage` 给用户看）。
        // 这里补同一道检查，避免写出一条绑着已删模板的悬空分组。
        // `schemes` 为空 = 调用方没把模板列表传进来（壳缺数据），此时不拦——
        // 编辑页本身会显示「请先创建一套时间模板」，不能把「数据没传」误判成「模板被删」。
        if (schemes.isNotEmpty() && schemes.none { it.id == draft.timeSchemeId }) {
            return LocationTimeGroupChange.Rejected(
                TimeSchemeServiceMessages.localize("time_scheme_not_found"),
            )
        }

        if (draft.editingId == null) {
            val created = LocationTimeGroup(
                id = idFactory(),
                name = name,
                timeSchemeId = draft.timeSchemeId,
                enabled = draft.enabled,
                // Dart createGroup 的默认参数：priority = 0；不取 draft 里的值，
                // 免得表单层意外带入「新建就高优先级」这种 Dart 不存在的行为。
                priority = 0,
                keywords = keywords,
                sourceSchoolId = null,
            )
            return LocationTimeGroupChange.Applied(groups = groups + created, target = created)
        }

        val index = groups.indexOfFirst { it.id == draft.editingId }
        if (index < 0) return LocationTimeGroupChange.Missing
        val updated = groups[index].copy(
            name = name,
            timeSchemeId = draft.timeSchemeId,
            enabled = draft.enabled,
            keywords = keywords,
        )
        val next = ArrayList<LocationTimeGroup>(groups)
        next[index] = updated
        return LocationTimeGroupChange.Applied(groups = next, target = updated)
    }

    /**
     * 开关某一组（Dart `group.copyWith(enabled: value)` → `updateLocationTimeGroup`）。
     *
     * 只翻 `enabled`；不重排、不改 priority。停用组仍留在列表里（卡片照常显示，只是
     * `LocationTimeMatchLogic.match` 不会再用它路由）。
     */
    fun setEnabled(groupId: String, enabled: Boolean): LocationTimeGroupChange {
        val index = groups.indexOfFirst { it.id == groupId }
        if (index < 0) return LocationTimeGroupChange.Missing
        val updated = groups[index].copy(enabled = enabled)
        if (updated == groups[index]) {
            return LocationTimeGroupChange.Applied(groups = groups, target = groups[index])
        }
        val next = ArrayList<LocationTimeGroup>(groups)
        next[index] = updated
        return LocationTimeGroupChange.Applied(groups = next, target = updated)
    }

    /**
     * 删除某一组（**调用前必须已经过 UI 确认框**，见类注释）。
     *
     * Dart `deleteGroup` 用 `where((g) => g.id != groupId)`：找不到目标时列表不变、
     * 返回 false，不抛错。这里对应 [LocationTimeGroupChange.Missing]。
     */
    fun delete(groupId: String): LocationTimeGroupChange {
        val next = groups.filterNot { it.id == groupId }
        if (next.size == groups.size) return LocationTimeGroupChange.Missing
        return LocationTimeGroupChange.Applied(groups = next, target = null)
    }

    /**
     * 编辑页「从课表识别的楼栋」建议：排除本组已有关键词与其它组的关键词。
     *
     * 与 Dart `_LocationTimeGroupEditorScreenState.build` 的 `uncoveredClusters(...)` 同口径
     *（`location_time_match_screen.dart:655-666`），聚类本身复用
     * [LocationBuildingClusterLogic]，不在这里重写。
     */
    fun buildingSuggestions(
        currentKeywords: List<LocationKeyword>,
        excludingGroupId: String?,
    ): List<BuildingCluster> {
        val owned = currentKeywords + LocationTimeMatchLogic.keywordsFromOtherGroups(
            groups = groups,
            excludingGroupId = excludingGroupId,
        )
        return LocationBuildingClusterLogic.uncoveredClusters(availableLocations, owned)
    }

    /**
     * 「重新匹配当前课表」的候选数（Dart `_applyToActive`:168-170）：
     * 只看**课程**命中，不看地点去重——同一地点两门课就是 2。
     */
    fun matchedCourseCount(courses: List<Course>): Int =
        courses.count { LocationTimeMatchLogic.match(it.location, groups) != null }

    /** 候选数 → 是否弹确认框（见类注释第 1、2 步）。 */
    fun applyDecision(matchedCourseCount: Int): LocationTimeApplyDecision =
        if (matchedCourseCount <= 0) {
            LocationTimeApplyDecision.NoMatch
        } else {
            val model = model()
            LocationTimeApplyDecision.Confirm(
                title = model.applyTitle,
                message = model.applyMessage(matchedCourseCount),
                confirmLabel = model.applyConfirmLabel,
            )
        }

    /**
     * 套用结果 → 屏上提示（Dart `_applyToActive`:240-300 的五分支，顺序与 `；` 连接符照抄）。
     *
     * 只在**真的执行了** `applyToActiveProfile` 之后调用；没有统计就不要调，别拿 0/0 假装
     * 「没有匹配到」。
     */
    fun applyToast(outcome: LocationTimeApplyOutcome): LocationTimeApplyToast {
        val overflowText = LocationTimeMatchStrings.applyOverflowResult.filled(
            "matched" to outcome.matched.toString(),
            "count" to outcome.overflowCount.toString(),
        )
        val overflowDescription = if (outcome.overflowNames.isEmpty()) {
            null
        } else {
            LocationTimeMatchStrings.applyOverflowHint.filled(
                "names" to outcome.overflowNames.joinToString("、"),
            )
        }
        return when {
            outcome.updated > 0 && outcome.overflowCount > 0 -> LocationTimeApplyToast(
                message = model().applyResultMessage(outcome.matched, outcome.updated) + "；" + overflowText,
                description = overflowDescription,
                kind = LocationTimeApplyToastKind.WARNING,
            )

            outcome.updated > 0 -> LocationTimeApplyToast(
                message = model().applyResultMessage(outcome.matched, outcome.updated),
                description = null,
                kind = LocationTimeApplyToastKind.SUCCESS,
            )

            outcome.overflowCount > 0 && outcome.matched > 0 -> LocationTimeApplyToast(
                message = overflowText,
                description = overflowDescription,
                kind = LocationTimeApplyToastKind.WARNING,
            )

            outcome.matched > 0 -> LocationTimeApplyToast(
                message = model().applyResultMessage(outcome.matched, updated = 0),
                description = null,
                kind = LocationTimeApplyToastKind.SUCCESS,
            )

            else -> LocationTimeApplyToast(
                message = LocationTimeMatchStrings.applyNoneMatched.text,
                description = null,
                kind = LocationTimeApplyToastKind.INFO,
            )
        }
    }
}