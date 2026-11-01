package com.mutx163.qingyu.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.mutx163.qingyu.pages.schedule.ScheduleDateRulePage
import com.mutx163.qingyu.pages.schedule.ScheduleItemBridge
import com.mutx163.qingyu.pages.schedule.ScheduleItemData
import com.mutx163.qingyu.pages.schedule.ScheduleListPage

/**
 * Phase 3.5 · 日程域宿主层（L4）：把 [TimetableRepository] 接到日程列表 / 日期规则页上。
 *
 * ## 与 `TimetableHost` 同一套订阅语义
 *
 * `observe` **订阅那一刻不推当前值**，所以首帧必须先读 `repository.snapshot`（接口语义，不是优化）。
 *
 * ## 为什么转换在 `ScheduleItemBridge` 而不在这里
 *
 * `core.ScheduleItem`（LocalDateTime）与 `ScheduleItemData`（ISO 字符串）的互转是纯函数，
 * 放 `main/pages/schedule/` 才能被 JVM 单测覆盖；本层只负责订阅与回调，尽量薄。
 *
 * ## 诚实边界
 *
 * 本层只到「渲染真实数据 + 回调接到仓储」。新增/编辑页的表单本身在页面渲染层，壳负责
 * 打开它并接保存/删除（见 `ShellWiring.saveScheduleItem` / `deleteScheduleItem`）。
 * 提醒通知调度属 Phase 4，本层不假装会弹提醒。
 */
@Composable
fun ScheduleListHost(
    repository: TimetableRepository,
    todayIso: String,
    onBack: () -> Unit,
    onAdd: () -> Unit,
    onEdit: (ScheduleItemData) -> Unit,
    onDelete: (ScheduleItemData) -> Unit,
) {
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    ScheduleListPage(
        groups = ScheduleItemBridge.buildListGroups(snapshot.scheduleItems, todayIso),
        onBack = onBack,
        onAddSchedule = onAdd,
        onEditSchedule = onEdit,
        onDeleteSchedule = onDelete,
    )
}

/**
 * 日程日期规则页宿主：读仓储里的 `schedule_date_rules`，保存/删除写回。
 *
 * 规则合法性（上限 2 条 / 区间重叠 / 日期格式）由页面的 `ScheduleDateRuleDomain.validateRule`
 * 在弹框里拦，**本层不重复实现一套校验**（两套判据必然漂移）。
 */
@Composable
fun ScheduleDateRuleHost(
    repository: TimetableRepository,
    todayIso: String,
    onBack: () -> Unit,
    /**
     * 规则新增 / 修改 / 删除**保存成功之后**回调，供宿主触发「日期规则自动套用作息」。
     *
     * 默认空实现：调用方（页面壳）不接时只是不自动套用，不会假装套过。
     */
    onRulesChanged: () -> Unit = {},
) {
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    val ruleViews = ScheduleItemBridge.buildDateRuleViews(
        rules = snapshot.scheduleDateRules,
        schemeNames = snapshot.timeSchemes.associate { it.id to it.name },
        todayIso = todayIso,
    )
    val availableSchemes = snapshot.timeSchemes.map { it.id to it.name }

    ScheduleDateRulePage(
        rules = ruleViews,
        availableSchemes = availableSchemes,
        onBack = onBack,
        onSaveRule = { incoming ->
            val ui = snapshot.scheduleDateRules.map { ScheduleItemBridge.toUiRule(it) }.toMutableList()
            ScheduleItemBridge.upsertRule(ui, incoming)
            repository.updateScheduleDateRules(ui.map { ScheduleItemBridge.toCoreRule(it) })
            onRulesChanged()
        },
        onDeleteRule = { target ->
            repository.updateScheduleDateRules(snapshot.scheduleDateRules.filter { it.id != target.id })
            onRulesChanged()
        },
    )
}
