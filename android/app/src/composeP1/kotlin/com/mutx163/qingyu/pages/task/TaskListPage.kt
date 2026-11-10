package com.mutx163.qingyu.pages.task

import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.ContactsBook
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 任务清单页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/task_list_screen.dart`（**唯一真值**）。元素与 Dart 出处的对照：
 *
 * | 元素 | Dart 出处 | 本文件控件 |
 * |---|---|---|
 * | 顶栏（返回 + 标题 + 新建） | `:38-47` | 共享骨架 `QingyuPageScaffold`（返回键 `QingyuBackIconButton`、动作键 `QingyuGlassIconButton`） |
 * | 日期分段（全部/今日/本周） | `:51-63` | 官方 `basic.TabRowWithContour`（见 [TaskDateSegmentedControl]） |
 * | 段后 10dp | `:64` | `Spacer(TaskSegmentGap)` |
 * | 课程筛选入口 | `:65` → `:201-218`（`HyperosChoiceTile`） | 官方 `preference.ArrowPreference` |
 * | 段后 16dp | `:66` | `Spacer(TaskSectionGap)` |
 * | 空态（图标 + 标题 + 按钮） | `:67-75` → `hyperos_empty_state.dart:7` | `TaskEmptyState`（图标 48dp、内边距 32/48） |
 * | 分组（标题 + 行卡片） | `:220-267` | `QingyuSectionTitle` + `QingyuCard` |
 * | 任务行 | `:395-523` | 官方 `basic.BasicComponent` + `combinedClickable`（见 [TaskRowItem]） |
 * | 无到期日提示条 | `:81` → `:151-168`（`HyperosNavTile`） | 官方 `ArrowPreference` + 行首图标 |
 * | 课程筛选弹层 | `:269-319` | `TaskCoursePickerSheet`（子弹层，非本文件） |
 * | 删除确认框 | `:364-392` | 官方 `overlay.OverlayDialog` |
 *
 * ## 本轮（2026-10-29 审核 §A）收口项
 *
 * - **A1** 手搓分段 → 官方 `TabRowWithContour`。
 *   Dart `HyperosSegmentedControl` 就是 `HyperosTabRow`，其**默认**风格是 `contour`
 *   （`lib/ui/hyperos/hyperos_tab_row.dart:28`、`:89-98`）→ 上游 `MiuixTabRowWithContour`。
 *   几何/间距与 Compose `TabRowDefaults.TabRowWithContour*` 逐值一致
 *   （高 45 / 圆角 8 / 格宽 62~84 / 间隔 5 / 外圈 5）。审计里写的 `basic.TabRow` 是
 *   Dart 的 `bordered` 那一档（蓝底选中块），与本页原版不同，故取同文件的 `TabRowWithContour`。
 * - **A2/A6** 手搓 `Row` → 官方 `ArrowPreference`（行首图标走 `startAction`，chevron 由组件自带）。
 * - **A3** 空态补图标（Dart `Icons.task_alt_outlined` → `MiuixIcons.Tasks`），版式照 `hyperos_empty_state.dart`。
 * - **A4** 裸 `clickable` → `BasicComponent` ＋ 官方 `LocalIndication`，走 miuix 自己的按压反馈。
 * - **A5** 补**长按删除**（Dart `:446` `onLongPress: onConfirmDelete`）。**侧滑本轮不做**（需用户拍板）。
 * - **A7** 段间距从整页 `spacedBy(12)` 改为 Dart 的 10 / 16。
 * - **A8** 返回键 `contentDescription` 由 `TaskStrings.cancelAction`（「取消」）改为
 *   `CommonUiStrings.back`（「返回」）。Dart 的 `HyperosBackButton` 本身**没有**语义标签
 *   （`lib/ui/hyperos/hyperos_back_button.dart:70-71` 明确写了没加），但读屏必须有个正确的名字，
 *   所以取全站统一的 `CommonUiStrings.back`，而不是沿用错误的「取消」。
 *   2026-11-05 B 组迁移：返回键改由骨架提供（`QingyuBackIconButton` 的默认文案就是
 *   `CommonUiStrings.back`），结论不变、取值处从本文件挪到共享件。
 * - **A11** 删掉冗余参数 `onCourseFilterClick`（弹层是页内行为，壳里永远是空实现）。
 *
 * ## 刻意保留的差异（详见本轮收口报告）
 *
 * - 行尾常驻删除按钮保留（Dart 只有侧滑 + 长按；该按钮比长按易发现，删掉是功能回退）。
 * - `TaskCheckbox`（Dart 自绘）→ 官方 `Checkbox`：A10 已登记为 P3。
 * - 行内没有分隔线：Dart 的 `HyperosListGroup` 也不画（`tiles.dart` 的 `showDivider` 默认 false）。
 */
@Composable
fun TaskListPage(
    viewState: TaskListViewState,
    onBack: () -> Unit,
    onDateFilterChange: (TaskDateFilter) -> Unit,
    onAddTask: () -> Unit,
    onEditTask: (CourseTask) -> Unit,
    onToggleTask: (CourseTask) -> Unit,
    onDeleteTask: (CourseTask) -> Unit,
    onViewCourse: ((CourseTask) -> Unit)? = null,
    // 课程筛选弹层的候选 + 选中回调。候选由 controller.courseOptions() 生成，走同一套 id 口径。
    courseFilterOptions: List<TaskCourseOption> = emptyList(),
    onCourseFilterPicked: ((String?) -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme

    // 课程筛选弹层与「删除确认」对话框的开关（都是页内交互，不需要宿主参与）。
    var showCourseFilter by remember { mutableStateOf(false) }
    var pendingDelete by remember { mutableStateOf<CourseTask?>(null) }

    // 共享骨架（2026-11-05 B 组迁移）：官方顶栏 + 标准返回键 + 顶栏毛玻璃 + actions 槽。
    // 返回键的显隐（从底栏进入的根页不画）与玻璃圆底的出没门控都由骨架注入，
    // 页面不再自己读根页判据、也不再手拼 `TopAppBar`；大标题仍可折叠（Dart `HyperosSubpage` 默认参数）。
    QingyuPageScaffold(
        title = TaskStrings.taskListTitle,
        onBack = onBack,
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
        actions = {
            QingyuGlassIconButton(
                onClick = onAddTask,
                contentDescription = TaskStrings.addTask,
                icon = MiuixIcons.Add,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // Dart `:49` 是 `EdgeInsets.all(12)`：横向留白由卡片自己带（12dp），
            // 滚动条才贴得到屏幕边缘。
            horizontalPadding = QingyuPageCardMargin,
            // 上下同为 Dart 那 12dp；底部手势条那一份由 QingyuPageList 内部按
            // innerPadding 算，不要重复相加。
            contentPadding = PaddingValues(top = TaskPagePadding, bottom = TaskPagePadding),
            // 段间距按 Dart 逐段显式给（10 / 16），不用整页统一 spacedBy。
            verticalArrangement = Arrangement.Top,
        ) {
            // ── 1. 日期分段控制器（Dart `:51-63`） ──
            item {
                TaskDateSegmentedControl(
                    currentFilter = viewState.dateFilter,
                    onFilterSelected = onDateFilterChange,
                )
            }

            // Dart `:64` 的 `SizedBox(height: 10)`。
            item { Spacer(modifier = Modifier.height(TaskSegmentGap)) }

            // ── 2. 课程筛选入口（Dart `:65`、`:201-218`） ──
            item {
                TaskCourseFilterRow(
                    selectedCourseLabel = viewState.selectedCourseLabel,
                    dark = dark,
                    onClick = {
                        if (onCourseFilterPicked != null && courseFilterOptions.isNotEmpty()) {
                            showCourseFilter = true
                        }
                    },
                )
            }

            // Dart `:66` 的 `SizedBox(height: 16)`。
            item { Spacer(modifier = Modifier.height(TaskSectionGap)) }

            if (viewState.isEmpty) {
                // ── 3. 空态（Dart `:67-75`、`hyperos_empty_state.dart:7`） ──
                // 几何/字阶收进共享件（方案 C01）：48dp 图标 + 17sp 标题 + 20dp + 主操作按钮。
                item {
                    QingyuEmptyState(
                        icon = MiuixIcons.Tasks,
                        title = viewState.emptyTitle,
                        action = {
                            // Dart `task_list_screen.dart:71-74`：空态 CTA 是 `HyperosButton` 默认
                            // variant = primary 蓝底实心；官方默认 `buttonColors()` 灰底在页底
                            // #F2F2F2 上对比比 ~1.02（融进背景），主操作必须显式按主操作配色。
                            Button(
                                onClick = onAddTask,
                                colors = ButtonDefaults.buttonColorsPrimary(),
                            ) {
                                Text(text = TaskStrings.addTask)
                            }
                        },
                    )
                }
            } else {
                // ── 4. 任务分组（Dart `:220-267`：段与段之间 16dp） ──
                viewState.sections.forEachIndexed { index, section ->
                    if (index > 0) {
                        item { Spacer(modifier = Modifier.height(TaskSectionGap)) }
                    }
                    // 分组标题走官方 SmallTitle（自带 28dp 左缘）；行文字左缘是
                    // 页面 12 + 行内 16 = 28，两者同一轴线。
                    item { QingyuSectionTitle(section.title) }
                    item {
                        QingyuCard(modifier = Modifier.fillMaxWidth()) {
                            section.items.forEach { row ->
                                TaskRowItem(
                                    item = row,
                                    onToggle = { onToggleTask(row.task) },
                                    onEdit = { onEditTask(row.task) },
                                    onDelete = { pendingDelete = row.task },
                                    onViewCourse = if (row.hasCourse && onViewCourse != null) {
                                        { onViewCourse(row.task) }
                                    } else {
                                        null
                                    },
                                    dark = dark,
                                    colors = colors,
                                )
                            }
                        }
                    }
                }
            }

            // ── 5. 未设到期日被过滤隐藏条目提示条（Dart `:81`、`:151-168`） ──
            // 无截止日期的作业不归属任何一天，在「今日」「本周」里必然被筛掉；
            // 不提示的话，用户在编辑页把日期一关，那条作业就像凭空消失了。
            if (viewState.undatedHiddenCount > 0) {
                // Dart `:154` 的 `Padding(top: 16)`。
                item { Spacer(modifier = Modifier.height(TaskSectionGap)) }
                item {
                    TaskUndatedHintRow(
                        count = viewState.undatedHiddenCount,
                        dark = dark,
                        // 点它就切到「全部」——那是唯一能看到这些作业的档。
                        onClick = { onDateFilterChange(TaskDateFilter.ALL) },
                    )
                }
            }
        }
    }

    // 课程筛选弹层（复用 TaskPickerSheets 的通用选择层，标题改成「课程筛选」）。
    TaskCoursePickerSheet(
        show = showCourseFilter,
        options = courseFilterOptions,
        title = TaskStrings.taskCourseFilter,
        onPick = { picked ->
            showCourseFilter = false
            // 2026-10-29 复核更正（V3）：弹层的取消出口也走这里（点空白 / 系统返回 ⇒
            // `TaskPickerSheets` 里 `onDismissRequest = { onPick(null) }`）。原先把 `null` 也转给
            // 宿主 ⇒ `TaskListController.setCourseFilter(null)`＝「全部课程」，
            // 于是「挑了一门课 → 再开一次弹层随手点掉」会把筛选**静默重置**。
            // Dart `task_list_screen.dart:313-318` 是 `if (!mounted || selected == null) return;`
            // ——取消就是不改。只在真的选中某一项时才回写。
            if (picked != null) {
                onCourseFilterPicked?.invoke(picked)
            }
        },
    )

    // 删除确认对话框（对齐 Dart `_confirmDelete` 的 showHyperosConfirmDialog，`:364-373`）。
    // 常驻组合（2026-11-02 弹层债）：关闭只把 pendingDelete 置空，`show` 驱动官方 260ms
    // 退场动画。原先「pendingDelete?.let { 弹层(show = true) }」的条件挂载会在置空的
    // 一瞬把整棵 OverlayDialog 摘出组合，退场动画一次都播不出去（修法先例：
    // pages/settings 2026-11-02 弹窗审核 P2）。标题/正文均为常量字符串，退场期间没有
    // 会被清空的状态，无需 remember 保底；删除动作在点击时才读 pendingDelete，
    // 退场期间它已为 null，天然不会再触发。
    // 正文走官方 summary 槽：该槽自带居中渲染（miuix DialogContentLayout 里
    // `textAlign = Center`），对齐 Dart `HyperosDialog` 的 message（同居中、同次级墨）。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = pendingDelete != null,
        title = TaskStrings.taskDelete,
        summary = TaskStrings.taskDeleteConfirm,
        onDismissRequest = { pendingDelete = null },
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            // 按钮间距 12：Dart `_HyperosDialogActions` 两按钮 `SizedBox(width: 12)`
            // （`hyperos_dialog.dart:162`）。
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 取消键：官方 secondary 实心按钮——发布版对话框两个动作都是 `HyperosButton`
            // （`_HyperosDialogActions`），不是文字钮。
            Button(
                modifier = Modifier.weight(1f),
                onClick = { pendingDelete = null },
                colors = ButtonDefaults.buttonColors(),
            ) {
                Text(text = TaskStrings.cancelAction)
            }
            // 删除是危险动作：**对话框**里发布版 `destructive: true`
            // （`task_list_screen.dart:297-305`）映射成 `HyperosButtonVariant.destructive`
            // ⇒ **实心 error 底 + onError 字**（`hyperos_controls.dart:724-729`）。
            // 淡红「水洗底」只属磨砂 sheet 按钮（同文件 `:817-846`），对话框别套那套。
            Button(
                modifier = Modifier.weight(1f),
                onClick = {
                    val target = pendingDelete
                    pendingDelete = null
                    if (target != null) onDeleteTask(target)
                },
                colors = ButtonDefaults.buttonColors(
                    color = MiuixTheme.colorScheme.error,
                    contentColor = MiuixTheme.colorScheme.onError,
                ),
            ) {
                Text(text = TaskStrings.deleteAction)
            }
        }
    }
}

/**
 * 日期分段控制器（A1）。
 *
 * Dart `HyperosSegmentedControl`（`task_list_screen.dart:51-63`）＝ `HyperosTabRow`
 * （`lib/ui/hyperos/hyperos_tab_row.dart:21`），默认 `style: HyperosTabRowStyle.contour`
 * （`:28`）→ 上游 `MiuixTabRowWithContour`（`:89-98`）。所以这里用官方同名组件，
 * 而不是审计建议里那个对应「蓝底选中」`bordered` 档的 `TabRow`。
 *
 * Dart 调用点**没有**传 `colors`（走向上游默认三档面），这里同样不传，保持两边取色一致。
 */
@Composable
private fun TaskDateSegmentedControl(
    currentFilter: TaskDateFilter,
    onFilterSelected: (TaskDateFilter) -> Unit,
) {
    TabRowWithContour(
        tabs = listOf(
            TaskStrings.taskAllFilter,
            TaskStrings.taskTodayFilter,
            TaskStrings.taskWeekFilter,
        ),
        // TaskDateFilter 的声明顺序与 Dart `_TaskDateFilter`（`:16`）一致：all / today / week。
        selectedTabIndex = currentFilter.ordinal,
        onTabSelected = { index -> onFilterSelected(TaskDateFilter.fromIndex(index)) },
        modifier = Modifier.fillMaxWidth(),
    )
}

/**
 * 课程筛选入口（A2）。
 *
 * Dart `_buildCourseFilter`（`:201-218`）：`HyperosListGroup` + `HyperosChoiceTile`
 * （行首 20dp 图标 + 标题 + 副标题 + chevron）。对应官方 `ArrowPreference`：
 * 标题、`summary`、`startAction` 放图标，chevron 由组件自己画。
 */
@Composable
private fun TaskCourseFilterRow(
    selectedCourseLabel: String,
    dark: Boolean,
    onClick: () -> Unit,
) {
    // 包偏好行时不传 insideMargin：官方 InsideMargin 是 0，偏好行自带 16dp。
    QingyuCard(modifier = Modifier.fillMaxWidth()) {
        ArrowPreference(
            title = selectedCourseLabel,
            summary = TaskStrings.taskCourseFilter,
            startAction = {
                // Dart `:210` 是 `Icon(Icons.menu_book_outlined, size: 20)`；miuix 里语义最近的是
                // ContactsBook（前轮已登记为替换项），尺寸照 Dart 的 20dp。
                Icon(
                    imageVector = MiuixIcons.ContactsBook,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(20.dp),
                )
            },
            onClick = onClick,
        )
    }
}

/**
 * 无到期日被隐藏的提示条（A6）。
 *
 * Dart `_buildUndatedHint`（`:151-168`）：`HyperosNavTile`（行首图标 `event_busy_outlined`
 * + 标题 + 副标题 + chevron），点了切回「全部」。对应官方 `ArrowPreference`。
 *
 * 图标：Dart 的 `event_busy_outlined` 是「带叉的日历」（＝没有日期），miuix 图标集里
 * 取语义最近的 `MiuixIcons.Months`（日历），已核对存在（`icon/extended/Months.kt:15`），
 * 同族先例 `AddExamPage.kt:276`、`ExamListPage.kt:505`。
 */
@Composable
private fun TaskUndatedHintRow(
    count: Int,
    dark: Boolean,
    onClick: () -> Unit,
) {
    QingyuCard(modifier = Modifier.fillMaxWidth()) {
        ArrowPreference(
            title = TaskStrings.taskUndatedHint(count),
            summary = TaskStrings.taskUndatedHintSubtitle,
            startAction = {
                Icon(
                    imageVector = MiuixIcons.Months,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(20.dp),
                )
            },
            onClick = onClick,
        )
    }
}

/**
 * 单条任务行（A4 / A5）。
 *
 * Dart `_TaskRow`（`:395-523`）：`HyperosPressableRow`（点击进编辑、**长按删**，
 * 按下整行高亮）里装 `hyperosListRowShell`（内边距 16/13、两行最小高 72）
 * ＋ 勾选框 ＋ 双行文字 ＋ 行尾「看课程」按钮。
 *
 * Compose 用官方 `BasicComponent`：行内布局（start 槽 ＋ 内容 ＋ end 槽）、
 * 最小行高、左右 16dp 内边距、指示器（`LocalIndication`）都是官方给的。
 * 官方 `BasicComponent` **没有长按回调**（`basic/Component.kt:126-139` 形参表里只有
 * `onClick`），所以照同族先例（`pages/settings/SettingsPageRenderers.kt:458-485`）：
 * 传 `onClick = null`，由外层 `combinedClickable` 同时接管点击与长按——
 * 仍是官方组件 + 官方按压指示，没有自研控件。
 */
@Composable
private fun TaskRowItem(
    item: TaskItemView,
    onToggle: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onViewCourse: (() -> Unit)?,
    dark: Boolean,
    colors: top.yukonga.miuix.kmp.theme.Colors,
) {
    val interactionSource = remember { MutableInteractionSource() }

    // Dart `:434-440`：逾期行标题/副标题都取 destructive，否则主/次级文字墨。
    val titleColor = if (item.isOverdue) colors.error else Color(QingyuTheme.primaryText(dark))
    val detailColor = if (item.isOverdue) colors.error else Color(QingyuTheme.secondaryText(dark))

    BasicComponent(
        modifier = Modifier.combinedClickable(
            interactionSource = interactionSource,
            indication = LocalIndication.current,
            onClick = onEdit,
            // A5：Dart `:446` `onLongPress: onConfirmDelete`。
            onLongClick = onDelete,
        ),
        // Dart `hyperosRowPadding` = LTRB(16, 13, 16, 13)（`hyperos_miuix_spec.dart:81`）。
        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 13.dp),
        startAction = {
            // Dart `:454` `TaskCheckbox` → 官方 Checkbox（本轮 A10 保留项）。
            Checkbox(
                state = if (item.isCompleted) ToggleableState.On else ToggleableState.Off,
                onClick = onToggle,
            )
        },
        endActions = {
            // Dart `:488-493`：有来源课程才有「看课程」入口。
            if (onViewCourse != null) {
                IconButton(onClick = onViewCourse, modifier = Modifier.size(36.dp)) {
                    Icon(
                        imageVector = MiuixIcons.ContactsBook,
                        contentDescription = TaskStrings.taskViewCourse,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                        modifier = Modifier.size(18.dp),
                    )
                }
                // 两颗 36dp 图标按钮紧贴时「看课程 / 删任务」只差一两个像素，容易误删。
                Spacer(modifier = Modifier.width(4.dp))
            }
            // 刻意保留：Dart 没有这颗常驻删除按钮（它靠侧滑 + 长按），
            // 但它比长按易发现，本轮不删以免功能回退。见收口报告的诚实清单。
            IconButton(onClick = onDelete, modifier = Modifier.size(36.dp)) {
                Icon(
                    imageVector = MiuixIcons.Delete,
                    contentDescription = TaskStrings.taskDelete,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(18.dp),
                )
            }
        },
    ) {
        // Dart `:461-466`：标题（`HyperosTypography.listTitle` = 17sp 常规字重 ⇒ headline1），
        // 已完成划掉、最多两行。
        Text(
            text = item.title,
            style = MiuixTheme.textStyles.headline1,
            color = titleColor,
            textDecoration = if (item.isCompleted) TextDecoration.LineThrough else null,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        // Dart `:467-473`：标题与副标题之间 3dp；副标题是「课程 · 周次 · 日期」拼串
        // （14sp，`HyperosTypography.listDetail` ⇒ body2）。
        Text(
            text = item.detailText,
            style = MiuixTheme.textStyles.body2,
            color = detailColor,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 3.dp),
        )
        // Dart `:474-484`：备注（有才显示，间隔 2dp，14sp 次级墨）。
        if (!item.note.isNullOrBlank()) {
            Text(
                text = item.note,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

/** Dart `task_list_screen.dart:49` 的 `EdgeInsets.all(12)`：整页四边 12dp。 */
private val TaskPagePadding: Dp = 12.dp

/** Dart `task_list_screen.dart:64`：分段控件与课程筛选入口之间 10dp。 */
private val TaskSegmentGap: Dp = 10.dp

/** Dart `task_list_screen.dart:66` / `:238` / `:154`：段与段之间 16dp。 */
private val TaskSectionGap: Dp = 16.dp

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照抄 about/ContributorsPage.kt 的样板）
//
// 只给实现阶段看效果，不进业务路径。本页数据形态由三个分组（已逾期 / 任务清单 /
// 已完成）+ 整页空态组成，这里铺：三分组都有内容 / 整页空态，再叠亮色 / 暗色 /
// 大字号 1.3 三档外观。
//
// 固定写法（与样板一致，别自己改）：
//   • 主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }：页面取色走
//     isSystemInDarkTheme()，只有它会改写 LocalConfiguration 的 uiMode，预览才和真机同口径；
//   • 字号用 QingyuPageTheme(textScale = …)，不要用 @Preview(fontScale = …)；
//   • 宽度按 400dp（本仓折行实测口径），高度给一屏多，避免列表被截断看不清。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：一条任务行。`detailText` 由模型层拼好，这里直接给成品的形状。 */
private fun previewTaskItem(
    id: String,
    title: String,
    detailText: String,
    isCompleted: Boolean = false,
    isOverdue: Boolean = false,
    courseName: String? = null,
): TaskItemView {
    val stamp = java.time.LocalDateTime.of(2026, 11, 6, 9, 0)
    return TaskItemView(
        id = id,
        title = title,
        detailText = detailText,
        note = null,
        isCompleted = isCompleted,
        isOverdue = isOverdue,
        courseId = if (courseName != null) "course-gaoshu" else null,
        hasCourse = courseName != null,
        task = CourseTask(
            id = id,
            title = title,
            createdAt = stamp,
            updatedAt = stamp,
        ),
    )
}

/** 非空态：三个分组各给几行，覆盖「逾期红字 / 关联课程 / 已完成删除线」三种行样式。 */
private fun previewTaskListState(): TaskListViewState = TaskListViewState(
    dateFilter = TaskDateFilter.ALL,
    courseFilter = null,
    selectedCourseLabel = TaskStrings.taskAllCourses,
    sections = listOf(
        TaskSectionView(
            title = "已逾期",
            items = listOf(
                previewTaskItem(
                    id = "task-1",
                    title = "交高数第三章习题",
                    detailText = "昨天 21:00 · 高等数学",
                    isOverdue = true,
                    courseName = "高等数学",
                ),
            ),
        ),
        TaskSectionView(
            title = "任务清单",
            items = listOf(
                previewTaskItem(
                    id = "task-2",
                    title = "背四级单词第 12 单元",
                    detailText = "明天 08:00",
                ),
                previewTaskItem(
                    id = "task-3",
                    title = "整理实验报告数据",
                    detailText = "11月12日 18:00 · 大学物理实验",
                    courseName = "大学物理实验",
                ),
            ),
        ),
        TaskSectionView(
            title = "已完成",
            items = listOf(
                previewTaskItem(
                    id = "task-4",
                    title = "打印课程表",
                    detailText = "11月05日",
                    isCompleted = true,
                ),
            ),
        ),
    ),
    emptyTitle = "还没有任务",
    undatedHiddenCount = 1,
    totalTasksCount = 3,
)

/** 整页空态：`sections` 为空即走页面里的居中提示分支。 */
private fun previewTaskListEmptyState(): TaskListViewState = TaskListViewState(
    dateFilter = TaskDateFilter.ALL,
    courseFilter = null,
    selectedCourseLabel = TaskStrings.taskAllCourses,
    sections = emptyList(),
    emptyTitle = "还没有任务",
    undatedHiddenCount = 0,
    totalTasksCount = 0,
)

/** 一档预览的公共身体：数据形态 + 外观档位。 */
@Composable
private fun PreviewTaskListPage(
    viewState: TaskListViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        TaskListPage(
            viewState = viewState,
            onBack = {},
            onDateFilterChange = {},
            onAddTask = {},
            onEditTask = {},
            onToggleTask = {},
            onDeleteTask = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 三个分组", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewTaskListSections() {
    PreviewTaskListPage(previewTaskListState())
}

@Suppress("unused")
@Preview(name = "2 整页空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewTaskListEmpty() {
    PreviewTaskListPage(previewTaskListEmptyState())
}

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewTaskListDark() {
    PreviewTaskListPage(previewTaskListState(), dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewTaskListLargeText() {
    PreviewTaskListPage(previewTaskListState(), textScale = 1.3f)
}
