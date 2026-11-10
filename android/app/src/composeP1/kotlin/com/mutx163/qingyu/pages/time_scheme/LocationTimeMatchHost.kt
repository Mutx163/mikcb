package com.mutx163.qingyu.pages.time_scheme

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.LocationTimeGroup
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.overlay.OverlayDialog

/**
 * 地点作息匹配页（`d3.locationMatch`）的**真宿主**：列表 ⇄ 编辑子页切换 + 真数据 + 真动作。
 *
 * ## 为什么要有这个文件
 *
 * 壳里原来的写法是 `LocationTimeMatchPage(model = LocationTimeMatchModel(), …)`：
 * 空模型 ⇒ 永远空列表；`onCreateGroup` / `onEditGroup` / `onDeleteGroup` / `onToggleGroup` /
 * `onApplyActive` 五个回调全是 `{}` ⇒ 整页只有壳、点哪都没反应。本宿主把页面要的三件事补齐：
 *
 * 1. **真数据**：分组、模板名、地点候选都由壳从 `TimetableSnapshot` 传进来（本文件不碰仓储）；
 * 2. **真动作**：新建 / 编辑 / 删除 / 开关全部经 [LocationTimeGroupController] 算出**新整份列表**，
 *    再交给 [onSaveGroups] 落盘；只有回调成功返回才更新本地回显（失败保持旧值并提示）；
 * 3. **列表 + 编辑同宿主切换**：不新增壳路由——编辑子页返回只回到列表，不退出整页。
 *
 * ## 删除确认（照 Dart `_deleteGroup`:327-368）
 *
 * Dart 先 `showAppConfirmDialog(title: deleteTitle, message: deleteMessage(name),
 * confirmLabel: deleteAction, destructiveConfirm: true)`，确认后才删。
 * 本宿主用官方 `OverlayDialog` 做同一个确认框（文案逐字走 ARB 键），删除按钮用主题错误色。
 *
 * ## 「重新匹配当前课表」为什么曾经是「未接入」
 *
 * 那个动作不是改分组，而是一次**整表课程钟点重写 + 释放手动模板 + 落盘**，宿主侧需要仓储/
 * 服务层入口（Dart `TimetableLocationRuleService.applyToActiveProfile`:286-585）。
 * 2026-11-05 补上：纯逻辑落 [LocationTimeApplyLogic]（JVM 可测），写入仍交壳
 * （[onApplyActive]，宿主只负责「确认框 → 执行 → 结果统计 toast」）。
 *
 * 流程照 Dart `_applyToActive`（`location_time_match_screen.dart:166-309`）：
 * 1. 命中课程数 0 → 直接「没有匹配到可套用的课程」，不弹确认框；
 * 2. 否则弹确认框（标题/正文/确认键三件套）；
 * 3. 执行后按「有更新 / 只有越界 / 只有命中且时钟已对齐 / 一门没命中」四档给结果文案，
 *    「有更新 + 有越界」是两段拼接（Dart :259-296）。
 *
 * ## 回显闭合
 *
 * [groups] 是壳的输入；本地 `workingGroups` 只用于「落盘成功后立刻回显」，并在壳推来新快照时
 * 重置。这样编辑保存 → 回列表能马上看到新值，且**不把未落盘的数据当成成功**。
 *
 * @param groups 当前地点组（顺序即展示顺序；壳从 `snapshot.locationTimeGroups` 取）
 * @param schemeNames 模板 id → 名字（**按 `snapshot.timeSchemes` 原顺序**构造，编辑页默认选第一套）
 * @param availableLocations 课表地点（去重；`snapshot.courses.map { it.location }.filter{…}.distinct()`）
 * @param onBack 返回上一页
 * @param onSaveGroups 整份新列表的落盘回调。**必须真的写入，失败要抛异常**（例如仓储写盘抛错），
 *   本宿主据此决定是否回显/提示失败；传空 lambda 等于假成功，不算交付。
 * @param matchedCourseCount 命中当前分组的课程数（确认框正文用）。传入的是**当前生效的分组**，
 *   所以保存失败留下的「界面新、盘上旧」不会算错数。
 * @param onApplyActive 「重新匹配当前课表」的执行入口：入参是**当前列表里的分组**，出参是本次
 *   统计；算与落盘都在壳侧，失败必须抛错。给入参而不是让壳自己读快照，是为了让「确认框里
 *   算的命中数」和「实际执行用的分组」永远是**同一份**（快照要等重组才更新，中间有个窄窗口）。
 *   null = 能力仍未接入，按钮给「不可用」的实话，不假装成功。
 */
@Composable
fun LocationTimeMatchHost(
    groups: List<LocationTimeGroup>,
    schemeNames: Map<String, String>,
    availableLocations: List<String>,
    onBack: () -> Unit,
    onSaveGroups: (List<LocationTimeGroup>) -> Unit,
    matchedCourseCount: (List<LocationTimeGroup>) -> Int = { 0 },
    onApplyActive: ((List<LocationTimeGroup>) -> LocationTimeApplyLogic.Stats)? = null,
) {
    val context = LocalContext.current

    // 壳推来新快照（结构不等）时重置本地回显；等值重组不会冲掉刚保存的结果。
    var workingGroups by remember(groups) { mutableStateOf(groups) }
    var editorTarget by remember { mutableStateOf<LocationTimeEditorTarget?>(null) }
    var pendingDelete by remember { mutableStateOf<LocationTimeGroup?>(null) }
    // 「重新匹配当前课表」的确认框：正文里的候选数在打开那一刻就钉住（执行前用户看不到变化，
    // 执行后又没有意义——Dart 也是点了才现算）。
    var pendingApplyCount by remember { mutableStateOf<Int?>(null) }

    // 模板列表只做「id+name → 两个页面各自的选项类型」的搬运，顺序原样保留（Map 迭代序）。
    val controllerSchemes = remember(schemeNames) {
        schemeNames.entries.map { LocationTimeSchemeOption(id = it.key, name = it.value) }
    }
    val editorSchemes = remember(schemeNames) {
        schemeNames.entries.map { SchemeOption(id = it.key, name = it.value) }
    }
    val controller = remember(workingGroups, controllerSchemes, availableLocations) {
        LocationTimeGroupController(
            groups = workingGroups,
            schemes = controllerSchemes,
            availableLocations = availableLocations,
        )
    }

    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /**
     * 把新整份列表交给壳落盘。
     *
     * **先调回调、成功后才更新本地回显**：回调抛错时列表保持旧值并提示失败，
     * 不会出现「界面显示已保存、盘上还是旧数据」的假成功。
     */
    fun persist(next: List<LocationTimeGroup>, failureMessage: String): Boolean =
        try {
            onSaveGroups(next)
            workingGroups = next
            true
        } catch (_: Exception) {
            toast(failureMessage)
            false
        }

    val target = editorTarget
    if (target != null) {
        val existing = when (target) {
            LocationTimeEditorTarget.Create -> null
            is LocationTimeEditorTarget.Edit -> workingGroups.firstOrNull { it.id == target.groupId }
        }
        if (target is LocationTimeEditorTarget.Edit && existing == null) {
            // 正在编辑的组被别处删了：退回列表，不渲染一个「不知道在编辑哪一组」的空壳。
            LaunchedEffect(target.groupId) { editorTarget = null }
            return
        }
        // `key` 让「新建 → 编辑另一组」重新初始化表单状态，不会把上一组的输入带过来。
        key(target) {
            LocationTimeGroupEditorPage(
                existing = existing,
                schemes = editorSchemes,
                allGroups = workingGroups,
                availableLocations = availableLocations,
                onBack = { editorTarget = null },
                onSave = { name, timeSchemeId, enabled, keywords ->
                    val base = when (target) {
                        LocationTimeEditorTarget.Create -> controller.newDraft()
                        is LocationTimeEditorTarget.Edit -> controller.editDraft(target.groupId)
                    }
                    if (base == null) {
                        // 组在打开表单后消失：别报「已保存」。
                        toast(LocationTimeMatchStrings.saveFailed.text)
                    } else {
                        val result = controller.save(
                            base.copy(
                                name = name,
                                timeSchemeId = timeSchemeId,
                                enabled = enabled,
                                keywords = keywords,
                            ),
                        )
                        when (result) {
                            is LocationTimeGroupChange.Applied -> {
                                if (persist(result.groups, LocationTimeMatchStrings.saveFailed.text)) {
                                    editorTarget = null
                                    toast(LocationTimeMatchStrings.saved.text)
                                }
                            }

                            is LocationTimeGroupChange.Rejected -> toast(result.message)
                            LocationTimeGroupChange.Missing ->
                                toast(LocationTimeMatchStrings.saveFailed.text)
                        }
                    }
                },
            )
        }
        return
    }

    val listModel = controller.model()

    LocationTimeMatchPage(
        model = listModel,
        onBack = onBack,
        onCreateGroup = { editorTarget = LocationTimeEditorTarget.Create },
        onEditGroup = { groupId -> editorTarget = LocationTimeEditorTarget.Edit(groupId) },
        onDeleteGroup = { groupId ->
            // 只把「待确认」记下来；真正删除在确认框里，照 Dart 不先删后提示。
            pendingDelete = workingGroups.firstOrNull { it.id == groupId }
        },
        onToggleGroup = { groupId, enabled ->
            when (val result = controller.setEnabled(groupId, enabled)) {
                is LocationTimeGroupChange.Applied -> {
                    if (result.groups != workingGroups) {
                        persist(result.groups, LocationTimeMatchStrings.saveFailed.text)
                    }
                }

                is LocationTimeGroupChange.Rejected -> toast(result.message)
                LocationTimeGroupChange.Missing -> Unit
            }
        },
        onApplyActive = {
            if (onApplyActive == null) {
                // 能力没接就实话实说，不假装「已重新匹配」（守卫也拦着 `{}` 假成功）。
                toast(LocationTimeMatchStrings.applyUnavailable.text)
            } else {
                val count = matchedCourseCount(workingGroups)
                if (count <= 0) {
                    // Dart `:174-180`：一门都没命中就不弹确认框，直接给结果文案。
                    toast(listModel.applyResultMessage(matched = 0, updated = 0))
                } else {
                    pendingApplyCount = count
                }
            }
        },
    )

    // 删除确认弹层常驻组合，`show` 由实时 pendingDelete 驱动；标题/正文/按钮用
    // remember 钉住的最后一份非空快照渲染——退场动画期间不会闪成空板
    //（2026-11-02 弹层债 #13，与 TimeSchemeManagementDialogs 同配方）。
    var shownDelete by remember { mutableStateOf(pendingDelete) }
    if (pendingDelete != null) {
        shownDelete = pendingDelete
    }
    val deleting = shownDelete
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = pendingDelete != null,
        title = deleting?.let { LocationTimeMatchStrings.deleteTitle.text },
        summary = deleting?.let {
            LocationTimeMatchStrings.deleteMessage.filled("name", it.name)
        },
        onDismissRequest = { pendingDelete = null },
    ) {
        if (deleting != null) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                // Dart 两动作横排等宽、间距 12（`_HyperosDialogActions`）——弹层债 #9。
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 发布版对话框动作**全是实心块钮**（`HyperosButton(expand: true)`）：
                // 取消 = secondary 实心、删除 = destructive 实心红（`hyperos_controls.dart:724-729`，
                // 不吃 `onFrostedPanel`）。只把确认键换成实心会成「灰文字 + 红块」混搭。
                // 形状照 D17 删除课表对话框（`TimetableProfilesPage.kt:740-758`）。
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { pendingDelete = null },
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = LocationTimeMatchStrings.cancelAction.text)
                }
                // S4 口径：实心危险底必须同时给 contentColor。
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        // 动作读实时值（点击只发生在可见期间）；快照只服务退场渲染。
                        val target = pendingDelete
                        pendingDelete = null
                        if (target != null) {
                            when (val result = controller.delete(target.id)) {
                                is LocationTimeGroupChange.Applied -> {
                                    if (persist(result.groups, LocationTimeMatchStrings.deleteFailed.text)) {
                                        toast(LocationTimeMatchStrings.deleted.text)
                                    }
                                }

                                is LocationTimeGroupChange.Rejected -> toast(result.message)
                                LocationTimeGroupChange.Missing -> Unit
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        color = MiuixTheme.colorScheme.error,
                        contentColor = MiuixTheme.colorScheme.onError,
                    ),
                ) {
                    Text(text = LocationTimeMatchStrings.deleteAction.text)
                }
            }
        }
    }

    // 「重新匹配当前课表」确认框（Dart `showAppConfirmDialog`，`location_time_match_screen.dart:181-189`）。
    //
    // 与删除框同配方：`show` 由实时 pendingApplyCount 驱动，标题/正文用当前值渲染；
    // 不做「点完先关框再执行」以外的时序花样——执行是同步的（算 + 落盘都在主调用里，
    // 仓储写盘失败抛异常由这里接住），所以不需要额外的中间态。
    val applyCount = pendingApplyCount
    val applyExecutor = onApplyActive
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = applyCount != null,
        title = applyCount?.let { listModel.applyTitle },
        summary = applyCount?.let { listModel.applyMessage(it) },
        onDismissRequest = { pendingApplyCount = null },
    ) {
        if (applyCount != null && applyExecutor != null) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 与删除框同一形制：发布版对话框动作全是实心块钮（`HyperosButton(expand: true)`，
                // `hyperos_dialog.dart:126-137`）。取消 = secondary 实心（`hyperos_controls.dart:697-711`）。
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { pendingApplyCount = null },
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(text = LocationTimeMatchStrings.cancelAction.text)
                }
                // 非破坏性确认 = primary 实心（`_variantFor` 的 `isPrimary` 分支），不是文字钮。
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        pendingApplyCount = null
                        // 失败**不报成功**：仓储写盘失败会抛错，这里落到「保存失败」。
                        val stats = try {
                            // 传当前列表里的分组（= 最后一次成功落盘的那份），
                            // 与确认框里算命中数用的是同一份，不会出现「说命中 3 门、实际按 2 门算」。
                            applyExecutor(workingGroups)
                        } catch (_: Exception) {
                            null
                        }
                        if (stats == null) {
                            toast(LocationTimeMatchStrings.saveFailed.text)
                        } else {
                            toast(applyResultText(listModel, stats))
                        }
                    },
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = listModel.applyConfirmLabel)
                }
            }
        }
    }
}

/**
 * 「重新匹配当前课表」的结果文案（逐条照 Dart `location_time_match_screen.dart:256-296` 的五档）：
 *
 * | 场景 | 文案 | Dart 的 kind |
 * |---|---|---|
 * | 有更新且**有越界** | 「已重新匹配 M 门，更新 U 门钟点」+「；…N 门已取消套用」+ 越界课程名 | warning |
 * | 只有更新 | 「已重新匹配 M 门，更新 U 门钟点」 | success |
 * | 没更新但**有命中+越界** | 「…N 门已取消套用」+ 越界课程名 | warning |
 * | 只命中、钟点本来就一致 | 「已重新匹配 M 门，钟点无需改写」 | success |
 * | 一门都没命中 | 「没有匹配到可套用的课程」 | info |
 *
 * Kotlin 侧 Toast 只有一行，所以 Dart 放在 `description` 的越界课程名并进正文（第二段拼接），
 * 判据顺序与 Dart 完全一致。
 */
private fun applyResultText(
    model: LocationTimeMatchModel,
    stats: LocationTimeApplyLogic.Stats,
): String = when {
    stats.updated > 0 && stats.sectionOverflow > 0 ->
        model.applyResultMessage(stats.matched, stats.updated) + "；" +
            model.applyOverflowMessage(
                matched = stats.matched,
                overflowCount = stats.sectionOverflow,
                examples = stats.sectionOverflowCourseNames,
            )

    stats.updated > 0 -> model.applyResultMessage(stats.matched, stats.updated)
    stats.sectionOverflow > 0 && stats.matched > 0 ->
        model.applyOverflowMessage(
            matched = stats.matched,
            overflowCount = stats.sectionOverflow,
            examples = stats.sectionOverflowCourseNames,
        )

    stats.matched > 0 -> model.applyResultMessage(matched = stats.matched, updated = 0)
    else -> model.applyResultMessage(matched = 0, updated = 0)
}

/** 列表页当前打开的子页：新建或编辑某一组（编辑 id 找不到时会退回列表）。 */
private sealed interface LocationTimeEditorTarget {
    data object Create : LocationTimeEditorTarget
    data class Edit(val groupId: String) : LocationTimeEditorTarget
}
