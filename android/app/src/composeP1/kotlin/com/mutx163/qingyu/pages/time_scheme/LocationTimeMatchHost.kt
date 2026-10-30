package com.mutx163.qingyu.pages.time_scheme

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.TextButton
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
 * ## 「重新匹配当前课表」为什么可能是「未接入」
 *
 * 那个动作不是改分组，而是一次**整表课程钟点重写 + 释放手动模板 + 落盘**，宿主侧需要仓储/
 * 服务层入口（Dart `TimetableLocationRuleService.applyToActiveProfile`:286-585）。本批写作用域
 * 不含 `main/.../app/`，仓储也没有该写入口。因此：
 * - 壳能在拿到入口后通过 [onApplyActive] 接入（传入即调用，不再自己写 UI）；
 * - 没接（默认 null）时按钮**不伪造成功**，只给一句实话「尚未接入」。
 *
 * 「候选数 → 不弹框/弹确认 → 结果文案」的纯判据已经在
 * [LocationTimeGroupController.applyDecision] / [LocationTimeGroupController.applyToast] 里备好，
 * 接入口的批次应复用它们，不要另写一套 Dart 分支。
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
 * @param onApplyActive 可选的「重新匹配当前课表」执行入口（已含确认与 toast 的完整流程）。
 *   为 null 时按钮给「尚未接入」的实话，不假装成功。
 */
@Composable
fun LocationTimeMatchHost(
    groups: List<LocationTimeGroup>,
    schemeNames: Map<String, String>,
    availableLocations: List<String>,
    onBack: () -> Unit,
    onSaveGroups: (List<LocationTimeGroup>) -> Unit,
    onApplyActive: (() -> Unit)? = null,
) {
    val context = LocalContext.current

    // 壳推来新快照（结构不等）时重置本地回显；等值重组不会冲掉刚保存的结果。
    var workingGroups by remember(groups) { mutableStateOf(groups) }
    var editorTarget by remember { mutableStateOf<LocationTimeEditorTarget?>(null) }
    var pendingDelete by remember { mutableStateOf<LocationTimeGroup?>(null) }

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
                        toast(LocationTimeMatchStrings.saveFailed.zh)
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
                                if (persist(result.groups, LocationTimeMatchStrings.saveFailed.zh)) {
                                    editorTarget = null
                                    toast(LocationTimeMatchStrings.saved.zh)
                                }
                            }

                            is LocationTimeGroupChange.Rejected -> toast(result.message)
                            LocationTimeGroupChange.Missing ->
                                toast(LocationTimeMatchStrings.saveFailed.zh)
                        }
                    }
                },
            )
        }
        return
    }

    LocationTimeMatchPage(
        model = controller.model(),
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
                        persist(result.groups, LocationTimeMatchStrings.saveFailed.zh)
                    }
                }

                is LocationTimeGroupChange.Rejected -> toast(result.message)
                LocationTimeGroupChange.Missing -> Unit
            }
        },
        onApplyActive = {
            val apply = onApplyActive
            if (apply != null) {
                apply()
            } else {
                // 实话：能力没接就不假装「已重新匹配」。文案取 ARB 的 `aboutUnavailable`
                // （清单 §1.2 点名的先例），不写死中文字面量。接入口见文件头说明。
                toast(LocationTimeMatchStrings.applyUnavailable.zh)
            }
        },
    )

    val deleting = pendingDelete
    // 与 `TimeSchemeDeleteSheet` 同姿势：弹层实例常驻、`show` 控制显隐，
    // 关闭时才有退出动画；内容用非空判断守住。
    OverlayDialog(
        show = deleting != null,
        title = deleting?.let { LocationTimeMatchStrings.deleteTitle.zh },
        summary = deleting?.let {
            LocationTimeMatchStrings.deleteMessage.filled("name", it.name)
        },
        onDismissRequest = { pendingDelete = null },
    ) {
        if (deleting != null) {
            val dark = isSystemInDarkTheme()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = LocationTimeMatchStrings.cancelAction.zh,
                    onClick = { pendingDelete = null },
                )
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = LocationTimeMatchStrings.deleteAction.zh,
                    // 危险色只染**字**（`color` 是底色，传错就是「红底 + 默认灰字」）。
                    colors = ButtonDefaults.textButtonColors(textColor = Color(QingyuTheme.error(dark))),
                    onClick = {
                        pendingDelete = null
                        when (val result = controller.delete(deleting.id)) {
                            is LocationTimeGroupChange.Applied -> {
                                if (persist(result.groups, LocationTimeMatchStrings.deleteFailed.zh)) {
                                    toast(LocationTimeMatchStrings.deleted.zh)
                                }
                            }

                            is LocationTimeGroupChange.Rejected -> toast(result.message)
                            LocationTimeGroupChange.Missing -> Unit
                        }
                    },
                )
            }
        }
    }
}

/** 列表页当前打开的子页：新建或编辑某一组（编辑 id 找不到时会退回列表）。 */
private sealed interface LocationTimeEditorTarget {
    data object Create : LocationTimeEditorTarget
    data class Edit(val groupId: String) : LocationTimeEditorTarget
}