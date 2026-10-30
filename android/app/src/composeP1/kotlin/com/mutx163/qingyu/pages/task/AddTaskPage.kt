package com.mutx163.qingyu.pages.task

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 添加 / 编辑任务表单页 · Compose 渲染层（Phase 3）。
 *
 * 逐元素对照 Flutter `lib/screens/add_task_screen.dart`（行号均指该文件）：
 * - 顶栏：返回 + 标题（添加任务 / 编辑任务）+ 删除（仅编辑态，线框图标）+ 保存（对勾）
 * - 卡片 1 `HyperosControlCard(title: 任务清单)`（`:186-228`）：卡头 + 标题框 + 备注框
 * - 卡片 2 `HyperosListGroup`（`:230-270`）：来源课程 → 截止日期开关 → 截止日期取值（仅开启时）
 *   → 已完成开关
 * - 页内留白 12、卡间 10（`:184`、`:229`）
 *
 * **对齐口径（2026-10-29 W2 收口，缺口矩阵 B1–B12/B15）**
 * - 行控件一律用官方 `ArrowPreference` / `SwitchPreference`（MIUIX-FIRST），不再手搓 `Row` + `Switch`；
 * - 文案一律走 `TaskStrings`（渲染层不许新增中文字面量，`CjkLiteralGateTest` 棘轮）；
 * - Dart 侧 `HyperosTextField` 的 `hint` 在渲染时被丢弃（`hyperos_text_field.dart:55-56` 的
 *   `label ?? hint` + `label == null && hint != null` 才用占位，且 flutter_miuix 的
 *   `MiuixTextField` 根本没有 hint 形参，见 `miuix_textfield.dart:66-124`），
 *   所以这里与 Dart **实际渲染**一致：只用 `label` 走 Miuix 的浮动标签，不额外造占位文字。
 */
@Composable
fun AddTaskPage(
    viewState: AddTaskViewState,
    onBack: () -> Unit,
    onTitleChange: (String) -> Unit,
    onNoteChange: (String) -> Unit,
    onHasDueDateChange: (Boolean) -> Unit,
    onCompletedChange: (Boolean) -> Unit,
    onSave: () -> Unit,
    onDelete: (() -> Unit)? = null,
    // ---- task-18 追加：两个子弹层的入参 ----
    // ⚠️ 回调故意用**可空**默认值：宿主没接之前，这两行保持「点了不动」的旧行为，
    // 而不是弹出一个空弹层（那等于把「死入口」伪装成「活入口」，比不弹更糟）。
    // 宿主接上 `onCourseOptionPicked` / `onDueDatePicked` 之后才会弹。
    //
    // 2026-10-29（B15）：原先还有 `onPickCourseClick` / `onPickDueDateClick` 两个参数，
    // 它们只做「通知宿主我点了」，而两个弹层本来就在本页内部（Dart 同款行为），
    // 壳里永远是空实现 ⇒ 已删除，弹层开关只看下面的候选/回调是否就绪。
    /** 选课程弹层的候选项（`AddTaskFormReducer.coursePickerOptions` 生成）。 */
    courseOptions: List<TaskCourseOption> = emptyList(),
    /** 选中项 id（`AddTaskFormReducer.NO_COURSE_OPTION_ID` 或某条课程 id）；`null` = 取消。 */
    onCourseOptionPicked: ((String?) -> Unit)? = null,
    /** 选日期弹层确认。 */
    onDueDatePicked: ((java.time.LocalDateTime) -> Unit)? = null,
    /** 选日期弹层「无到期日」。 */
    onDueDateCleared: (() -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme

    val pageTitle = if (viewState.isEditing) TaskStrings.editTask else TaskStrings.addTask

    // 顶栏折叠行为：与 Dart 侧 HyperosSubpage（overlayHeader + collapsibleLargeTitle
    // 均为默认 true）的可折叠大标题一致。必须同时传给 TopAppBar 和内容的 nestedScroll。
    val scrollBehavior = MiuixScrollBehavior()

    // task-18：两个子弹层由页面自己持有开关（判据仍在宿主的 reducer 里）。
    var showCoursePicker by remember { mutableStateOf(false) }
    var showDueDatePicker by remember { mutableStateOf(false) }
    // 删除确认（仅编辑态）：对齐 Dart `_confirmDelete` 的 showHyperosConfirmDialog。
    var showDeleteConfirm by remember { mutableStateOf(false) }

    // 两行的「可点性」先算好：宿主没接选中回调（或课程候选还没来）时不假装可点
    // ——弹一个空列表等于把死入口伪装成活入口，让行看起来可点更糟。
    val courseRowClick: (() -> Unit)? =
        if (onCourseOptionPicked != null && courseOptions.isNotEmpty()) {
            { showCoursePicker = true }
        } else {
            null
        }
    val dueDateRowClick: (() -> Unit)? =
        if (onDueDatePicked != null) {
            { showDueDatePicker = true }
        } else {
            null
        }

    // ── B4：纯新建时把光标放进标题框（Dart `autofocus: _shouldAutofocusTitle`，`:201`）──
    // 判据在模型层（`TaskModel.kt:99-103` `TaskFormDefaults.shouldAutofocusTitle`）：
    // 只有「纯新建」为 true；从课程进入或编辑态为 false，弹键盘会挡住下面三行。
    val titleFocus = remember { FocusRequester() }
    val noteFocus = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        if (viewState.shouldAutofocusTitle) {
            // 焦点请求要等首帧布局完成：节点还没挂上树时 requestFocus 会抛
            // IllegalStateException（Modifier 尚未附着）。只请求一次，之后不再抢。
            withFrameNanos { }
            runCatching { titleFocus.requestFocus() }
        }
    }

    TaskCoursePickerSheet(
        show = showCoursePicker,
        options = courseOptions,
        onPick = { optionId ->
            showCoursePicker = false
            onCourseOptionPicked?.invoke(optionId)
        },
    )
    TaskDueDatePickerSheet(
        show = showDueDatePicker,
        initial = viewState.dueDate,
        onPick = { date ->
            showDueDatePicker = false
            onDueDatePicked?.invoke(date)
        },
        onClear = {
            showDueDatePicker = false
            onDueDateCleared?.invoke()
        },
        onDismiss = { showDueDatePicker = false },
    )

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，
            // 放进槽位后 Scaffold 不再重复给这份内边距（第一版就是在这里算了两遍）。
            topBar = {
                TopAppBar(
                    title = pageTitle,
                    largeTitle = pageTitle,
                    scrollBehavior = scrollBehavior,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = TaskStrings.cancelAction,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    actions = {
                        if (viewState.isEditing && onDelete != null) {
                            // B11：Dart 是线框 `Icons.delete_outline_rounded`（`:171`）。
                            // 解包核对：0.9.4 的 `MiuixIcons.Delete` 本身就是线框——
                            // 路径是 5 条闭合轮廓（.kt 里 5×MoveTo/Close）+ EvenOdd 填充，
                            // 不是什么实心色块；没有比它更接近的线框变体，故保留。
                            IconButton(onClick = { showDeleteConfirm = true }) {
                                Icon(
                                    imageVector = MiuixIcons.Delete,
                                    contentDescription = TaskStrings.taskDelete,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                        }
                        // 2026-10-29 复核更正（V1）：这里原先 `enabled = viewState.canSave`，
                        // 把 Dart 的**报错路径整条封死**了。Dart `add_task_screen.dart:175-179`
                        // 的保存键**没有禁用态**：标题空着点下去，`_save()` 走
                        // `_formKey.currentState!.validate()` → 标题框下出现
                        // `helper: field.errorText`＝「请输入任务标题」（`:195-206`）。
                        // 禁用键只能让用户看到「点不动」，永远等不到那句话，也看不出缺了什么。
                        // 现在恒可点：空标题点它 ⇒ 壳里的 `AddTaskFormReducer.validate` 落
                        // `titleError`，框下红字出现。
                        IconButton(onClick = onSave) {
                            // B10：Dart 是 `Icons.check_rounded`（`:176`）。
                            // `MiuixIcons.SelectAll`（勾 + 两条横线）语义是「全选」，不对。
                            // 改 `MiuixIcons.Ok`（`icon/extended/Ok.kt:15`，= Regular 权重）：
                            // 与课程表单保存键 `AddCoursePage.kt:233` 同形，同族「保存」只有一种长相。
                            // 附：`miuix-icons` 里对勾类确实只有 `Ok`；更粗的圆头勾在 `miuix-ui` 的
                            // `icon/basic/Check.kt`（仓库先例 `SettingsPageRenderers.kt:531` 用过
                            // `MiuixIcons.Basic.*`），形状更贴 check_rounded，但为了族内一致不采用。
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = TaskStrings.saveTask,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    // 表单页必须避让键盘：底部输入框被 IME 盖住的话没法填。
                    // Dart 侧靠 resizeToAvoidBottomInset: true 达到同一效果。
                    .imePadding(),
            ) {
                QingyuPageList(
                    innerPadding = innerPadding,
                    scrollBehavior = scrollBehavior,
                    // 官方配方：横向留白由卡片自己带（12dp），滚动条才贴得到屏幕边缘。
                    horizontalPadding = QingyuPageCardMargin,
                    // 顶部/底部 12：Dart `HyperosListView(padding: EdgeInsets.all(12))`
                    // （`add_task_screen.dart:184`）。底部手势条那段由 QingyuPageList
                    // 内部按 innerPadding 算（等价于原先手写的
                    // innerPadding.calculateBottomPadding()），不要重复相加。
                    contentPadding = PaddingValues(top = 12.dp, bottom = 12.dp),
                    // 卡间 10：Dart 两卡之间 `SizedBox(height: 10)`（`:229`）。
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    // ── 1. 标题与备注卡片（Dart `HyperosControlCard(title: 任务清单)` :186-228）──
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.fillMaxWidth()) {
                                // B1：卡头标题。Dart 卡头 = 内边距 LTRB(16,16,16,0)
                                // （`hyperos_controls.dart:122-124`）+ 字号 **17 / w400** / primaryText
                                // （`hyperos_theme.dart:512-520` 的 `HyperosTypography.title`
                                //   → `HyperosTokens.titleSize` → `HyperosMiuixSpec.preferenceTitleSize`
                                //   = 17.0，`hyperos_miuix_spec.dart:80`）。miuix 的 `main` 就是 17sp 常规档。
                                //
                                // 2026-10-29 复核更正（V2）：这里原先写 `title3`（20sp）并声称 Dart 卡头
                                // 是 20sp —— 那是把 `HyperosMiuixNestedHeader.titleSize`（毛玻璃子页的
                                // 居中大标题）当成了 `HyperosTokens.titleSize`。差 3sp，偏大一眼可见。
                                Text(
                                    text = TaskStrings.taskListTitle,
                                    style = MiuixTheme.textStyles.main,
                                    color = Color(QingyuTheme.primaryText(dark)),
                                    modifier = Modifier.padding(
                                        start = 16.dp,
                                        top = 16.dp,
                                        end = 16.dp,
                                    ),
                                )
                                // 卡头 → 正文间距 12（`hyperos_controls.dart:149`），正文横向 16、
                                // 底部 12（`HyperosControlCardInset`：16/0/16/12，
                                // 见 `hyperos_controls.dart:34-43` + `layout.dart:60-65`）。
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(
                                            start = 16.dp,
                                            top = 12.dp,
                                            end = 16.dp,
                                            bottom = 12.dp,
                                        ),
                                    // 两框之间 8：Dart `SizedBox(height: 8)`（`:210`）。
                                    verticalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Column(modifier = Modifier.fillMaxWidth()) {
                                        TextField(
                                            value = viewState.title,
                                            onValueChange = onTitleChange,
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .focusRequester(titleFocus),
                                            label = TaskStrings.taskTitleLabel,
                                            singleLine = true,
                                            // B5：Dart `textInputAction: next`，提交后把焦点
                                            // 交给备注框（`:205-206`）。
                                            keyboardOptions = KeyboardOptions(
                                                imeAction = ImeAction.Next,
                                            ),
                                            keyboardActions = KeyboardActions(
                                                onNext = { noteFocus.requestFocus() },
                                            ),
                                        )
                                        if (!viewState.titleError.isNullOrBlank()) {
                                            // Dart `helper: field.errorText` 排在框下
                                            // `SizedBox(height: 6)` 处、与框左缘对齐
                                            // （`hyperos_text_field.dart:107-116`）。
                                            Text(
                                                text = viewState.titleError,
                                                style = MiuixTheme.textStyles.footnote1,
                                                color = colors.error,
                                                modifier = Modifier.padding(top = 6.dp),
                                            )
                                        }
                                    }

                                    TextField(
                                        value = viewState.note,
                                        onValueChange = onNoteChange,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .focusRequester(noteFocus),
                                        label = TaskStrings.taskNoteLabel,
                                        singleLine = false,
                                        minLines = 1,
                                        maxLines = 4,
                                        // B5：备注是表单里最后一个输入框，Dart 用 `done` +
                                        // `onSubmitted: (_) => _save()` 直接保存（`:222-223`），
                                        // 不再把焦点推到开关上（开关不可输入，停在那里什么也不会发生）。
                                        keyboardOptions = KeyboardOptions(
                                            imeAction = ImeAction.Done,
                                        ),
                                        keyboardActions = KeyboardActions(
                                            onDone = { onSave() },
                                        ),
                                    )
                                }
                            }
                        }
                    }

                    // ── 2. 来源课程 / 截止日期 / 已完成（Dart `HyperosListGroup` :230-270）──
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth()) {
                            // 官方配方（`QingyuCard.kt:48-58`）：包 Preference 行时**不传**
                            // `insideMargin`——行组件自带 16dp，再给会变成 32dp。
                            // Dart 这三行的横向内边距同样是 16（`hyperos_miuix_spec.dart:81`）。
                            //
                            // 行间不画分隔线：Dart 的 `HyperosListGroup` 只做首/末行标记、
                            // 不插分隔线（`layout.dart:191-216`），`HyperosChoiceTile.showDivider`
                            // 默认 false，`add_task_screen.dart:230-269` 一处都没传。
                            // B6：来源课程行（`:232-237`）→ title=课程名/无关联课程，
                            // summary=来源课程，chevron 由 ArrowPreference 自带。
                            ArrowPreference(
                                title = viewState.selectedCourseName,
                                summary = TaskStrings.taskCourseLabel,
                                onClick = courseRowClick,
                            )
                            // B7：截止日期开关（`:238-255`）。subtitle 只在关闭时显示
                            // ——不设日期的作业不会出现在日视图待办带、也不进「今日」档，
                            // 而新建时这个开关默认是关的，用户很容易存完就再也找不到。
                            SwitchPreference(
                                checked = viewState.hasDueDate,
                                onCheckedChange = onHasDueDateChange,
                                title = TaskStrings.taskDueDateLabel,
                                summary = if (viewState.hasDueDate) {
                                    null
                                } else {
                                    TaskStrings.taskDueDateHint
                                },
                            )
                            // B8：截止日期取值行（Dart `if (_hasDueDate)`，`:256-261`）。
                            // Dart 这行只有标题（日期文本）+ chevron，没有 subtitle。
                            if (viewState.hasDueDate) {
                                ArrowPreference(
                                    title = viewState.dueDateFormatted.ifEmpty {
                                        TaskStrings.taskDueDateLabel
                                    },
                                    onClick = dueDateRowClick,
                                )
                            }
                            // B9：已完成开关（`:262-268`）。
                            SwitchPreference(
                                checked = viewState.isCompleted,
                                onCheckedChange = onCompletedChange,
                                title = TaskStrings.taskCompletedSection,
                            )
                        }
                    }
                }
            }
        }
    }

    if (showDeleteConfirm && onDelete != null) {
        OverlayDialog(
            insideMargin = DpSize(16.dp, 16.dp),
            show = true,
            title = TaskStrings.taskDelete,
            onDismissRequest = { showDeleteConfirm = false },
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = TaskStrings.taskDeleteConfirm,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = TaskStrings.cancelAction,
                        onClick = { showDeleteConfirm = false },
                    )
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = TaskStrings.deleteAction,
                        colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.textButtonColors(
                            // 危险色只染**字**：`color` 是底色，传错会变成「红底 + 默认灰字」
                            //（对比度坏，也不是 Dart `destructive` 变体的观感）。
                            textColor = Color(QingyuTheme.error(dark)),
                        ),
                        onClick = {
                            showDeleteConfirm = false
                            onDelete?.invoke()
                        },
                    )
                }
            }
        }
    }
}
