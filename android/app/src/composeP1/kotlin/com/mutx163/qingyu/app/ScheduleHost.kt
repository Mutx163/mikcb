package com.mutx163.qingyu.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.pages.schedule.ScheduleDateRuleAutoApplyHost
import com.mutx163.qingyu.pages.schedule.ScheduleDateRuleData
import com.mutx163.qingyu.pages.schedule.ScheduleDateRulePage
import com.mutx163.qingyu.pages.schedule.ScheduleDateRuleSavedFeedback
import com.mutx163.qingyu.pages.schedule.ScheduleDateRuleSavedFeedbackLogic
import com.mutx163.qingyu.pages.schedule.ScheduleItemBridge
import com.mutx163.qingyu.pages.schedule.ScheduleItemData
import com.mutx163.qingyu.pages.schedule.ScheduleListPage
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.transfer.AppToastCapsule
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
 * 提示胶囊要显示的内容：文案 + 是否警示。
 *
 * ## 为什么需要这个类型（而不是只留四态）
 *
 * 四态 [ScheduleDateRuleSavedFeedback] 的前提是「规则**写盘成功**」——写盘抛错时那四档一句话
 * 都不成立（说「已保存」就是假成功）。但**落点必须是同一条胶囊**：留两个并行状态
 * （`feedback` + `saveFailure`）在「失败后紧接着成功」这类交替里会互相盖掉，看起来像提示丢了。
 * 所以统一成一个可空状态，谁写进来就显示谁。
 *
 * 「保存失败」一句复用 `SettingsStringsExt2.saveFailed`（零 ARB 改动，与设置域三处保存提示同一句）；
 * `scheduleDateRuleSaveFailed` 那条复合键留着，等文案决策把 reason 体系建起来再接。
 */
private data class RuleToast(val message: String, val isError: Boolean)

/**
 * 日程日期规则页宿主：读仓储里的 `schedule_date_rules`，保存/删除写回，**并负责保存后的
 * 「自动套用 + 四态提示」**（发布版 `schedule_date_rule_screen.dart:380-430`）。
 *
 * 规则合法性（上限 2 条 / 区间重叠 / 日期格式）由页面的 `ScheduleDateRuleDomain.validateRule`
 * 在弹框里拦，**本层不重复实现一套校验**（两套判据必然漂移）。
 *
 * ## 为什么自动套用收进本层（2026-11-05）
 *
 * 之前壳自己在 `onRulesChanged` 里 `launch(Dispatchers.IO) { applyDue(...) }`，**返回值直接丢掉**：
 * 规则今天该套却套不成（模板缺失 / 节数不够 / 落盘失败）时用户看到的是「已保存」，
 * 作息却没变、也没有任何解释。现在套用与文案在同一处发生：
 * 写盘成功 → `applyDue` → 用 [ScheduleDateRuleSavedFeedbackLogic] 判四态 → 弹提示
 * （失败档走警示样式）。壳不再自己起协程，避免两处各跑一次、也避免再有人把返回值丢掉。
 *
 * ## 写盘抛错也要说话（2026-11-05 补）
 *
 * 仓储 `updateScheduleDateRules` 的契约是「先落盘、成功才改内存并通知」，落盘失败会**抛异常**。
 * 之前两个回调都是裸调用：抛出去的异常要么把应用带崩，要么（被上层吞掉时）变成「弹框关了、
 * 列表还是旧规则、一句话都没有」。现在统一经 [writeRules]：失败只提示 `SettingsStringsExt2.saveFailed`
 * 且不跑自动套用/四态（没保存成功不许说「已保存」），成功才走后面那条链。
 */
@Composable
fun ScheduleDateRuleHost(
    repository: TimetableRepository,
    todayIso: String,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    // 「已套用签名」按 Dart 的原键存 prefs（`schedule_date_rule_last_applied_signature`），
    // 同一档期只套一次靠的就是它。
    val prefs = remember(context) { PrefsKeyValueStore(context) }
    val scope = rememberCoroutineScope()
    var toast by remember { mutableStateOf<RuleToast?>(null) }

    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    /**
     * 规则写盘成功之后：跑一次 `applyDue`（要知道「今天到底套没套、有没有套失败」），
     * 再把结果翻成四态文案。套用会落盘 ⇒ 放 IO；文案回主线程算并驱动提示胶囊。
     *
     * 返回值的**每一个字段**都要用上：`failedWhileDue` / `didApply` 是四态里两档的判据，
     * 丢一次就等于「套用失败也不吭声」。
     */
    fun applyDueAndReport(savedRule: ScheduleDateRuleData) {
        scope.launch {
            val applyResult = withContext(Dispatchers.IO) {
                ScheduleDateRuleAutoApplyHost.applyDue(repository, prefs)
            }
            val resolved = ScheduleDateRuleSavedFeedbackLogic.resolve(
                rule = savedRule,
                applyResult = applyResult,
                todayIso = todayIso,
            )
            toast = RuleToast(resolved.message, resolved.isWarning)
        }
    }

    /**
     * 规则写盘。**抛错必须说出来**：仓储是「先落盘、成功才改内存并通知」，
     * 抛错时盘上和内存里都还是旧规则；不 catch 就等于「点了保存、弹框关了、列表没变、一个字不提示」，
     * 页面还会带着旧数据（发布版 Dart 这边是有 `scheduleDateRuleSaveFailed` 的 catch 的）。
     *
     * [onLanded] 只在真落盘后才跑：没落盘就继续跑自动套用 + 四态提示，等于把失败说成「已保存」。
     */
    fun writeRules(
        rules: List<ScheduleDateRule>,
        onLanded: () -> Unit,
    ) {
        val landed = runCatching { repository.updateScheduleDateRules(rules) }
        if (landed.isFailure) {
            // 文案复用 `SettingsStringsExt2.saveFailed`（「保存失败」，零 ARB 改动）。
            // 四态那三句复合键的前提都是「已保存」，这里一句都不能用。
            toast = RuleToast(SettingsStringsExt2.saveFailed.text, isError = true)
        } else {
            onLanded()
        }
    }

    val ruleViews = ScheduleItemBridge.buildDateRuleViews(
        rules = snapshot.scheduleDateRules,
        schemeNames = snapshot.timeSchemes.associate { it.id to it.name },
        todayIso = todayIso,
    )
    val availableSchemes = snapshot.timeSchemes.map { it.id to it.name }

    Box(modifier = Modifier.fillMaxSize()) {
        ScheduleDateRulePage(
            rules = ruleViews,
            availableSchemes = availableSchemes,
            onBack = onBack,
            onSaveRule = { incoming ->
                val ui = snapshot.scheduleDateRules.map { ScheduleItemBridge.toUiRule(it) }.toMutableList()
                ScheduleItemBridge.upsertRule(ui, incoming)
                // 写盘失败：只提示「保存失败」，**不跑自动套用、也不出四态**（没说保存成功就不能说已保存）。
                writeRules(ui.map { ScheduleItemBridge.toCoreRule(it) }) {
                    applyDueAndReport(incoming)
                }
            },
            onDeleteRule = { target ->
                // 删除写盘同样可能抛错（存储不可写），静默会把「删不掉」变成「点了没反应」。
                writeRules(snapshot.scheduleDateRules.filter { it.id != target.id }) {
                    // 删规则后同样要重排（Dart `:1729` 同一触发点）。这里不出四态提示：
                    // 「已保存，但今日自动套用失败」那句话在删除场景是错的（未保存任何规则）。
                    scope.launch {
                        withContext(Dispatchers.IO) {
                            ScheduleDateRuleAutoApplyHost.applyDue(repository, prefs)
                        }
                    }
                }
            },
        )
        // 提示胶囊：复用共享件（Dart `showAppToast` 的对位），失败档（四态的套用失败、写盘失败）走警示样式。
        toast?.let { current ->
            AppToastCapsule(
                message = current.message,
                dark = dark,
                isError = current.isError,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 24.dp),
                onDismiss = { toast = null },
            )
        }
    }
}
