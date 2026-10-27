package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Sort
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课程总览与编辑页 · Compose 渲染层（Phase 3 · P3-D1）。
 *
 * 对应 Flutter `lib/screens/course_overview_screen.dart`（324 行）：
 * 顶栏（返回 / 排序 / 添加）＋ 冲突详情入口（有冲突时）＋ 同名课程聚合行
 * ＋ 空态；「排序」是常驻挂载、按 `sortPopupOpen` 切显示的选择弹层。
 *
 * ## 本页不做任何业务计算
 *
 * 排序、同名聚合、冲突标记、行标题/副标题拼装、弹层三项与选中态**全部**在
 * 模型层 [CourseOverviewLogic.buildViewState] 里算好，本文件只做三件事：
 * 1. 把 [CourseOverviewViewState] 的字段摆上屏；
 * 2. 持有**纯 UI 状态** `sortPopupOpen`（Dart 侧同样放在 State 里，不是业务状态）；
 * 3. 把点击回调按语义转给壳层（onOpenGroup 带整行，onOpenConflictDetail 不带参数）。
 *
 * ## 与 Dart 的渲染层差异（都记在这里，不进别的文件）
 *
 * - **排序弹层**：Dart 用 `HyperosSelectPopup`（常驻挂载 + 锚定矩形 + 切 show）。
 *   Miuix 0.9.4 没有「任意锚点的选择弹层」这种组件——`WindowDropdownPreference` /
 *   `OverlayDropdownPreference` 都是**设置行**形态（自带标题行），不能挂到顶栏图标下。
 *   所以这里用官方 [Card] + [Text] 行组合出弹层，弹层容器用 Compose 原生 [Popup]
 *   （`focusable = true`，点空白/返回键即关，对齐 Dart `onDismiss` 语义）。没有自绘
 *   任何「官方已有」的组件形态，只是在官方容器里摆官方文字行。
 * - **冲突入口图标**：Dart 用 `Icons.warning_amber_rounded` + `HyperosIconColors.orange`
 *   （`0xFFFF6B00`）。Miuix 0.9.4 的 extended 图标里**没有**警告类字形（实测 AAR
 *   只有 Info/Kind 等），取最接近的官方 [MiuixIcons.Info]，颜色沿用 Dart 的橙色。
 * - **空态**：Dart 是「56dp 校徽图标 + 提示 + 按钮」。Miuix 无学校字形，按
 *   `ScheduleListPage` 已交付空态的先例（卡片 + 提示 + 按钮，不带图标），避免自绘图标。
 *
 * @param viewState 整页视图状态（模型层产出，见 [CourseOverviewViewState]）
 * @param onBack 返回（Dart `onBack: Navigator.pop`）
 * @param onAddCourse 顶栏「+」与空态按钮（Dart 两处都进 `/course/create`）
 * @param onOpenGroup 点课程组行进编辑页（Dart `AddCourseScreen(courseGroup: group)`，
 *   按 Catalog 契约该页收的是 `CourseFormPayload(courseGroup = …)`）
 * @param onOpenConflictDetail 冲突详情入口（Dart 进 `/course/conflicts`）
 * @param onSortModeSelected 弹层选中一档（Dart `_onSortSelected`：改档 + 关弹层，
 *   两件事都由壳/模型侧完成，本页只上报选择）
 */
@Composable
fun CourseOverviewPage(
    viewState: CourseOverviewViewState,
    onBack: () -> Unit,
    onAddCourse: () -> Unit,
    onOpenGroup: (CourseGroup) -> Unit,
    onOpenConflictDetail: () -> Unit,
    onSortModeSelected: (CourseOverviewSortMode) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    // 顶栏折叠行为：Dart 侧 course_overview_screen.dart:46 走 HyperosSubpage，
    // overlayHeader / collapsibleLargeTitle 均为默认 true（可折叠大标题）。
    val scrollBehavior = MiuixScrollBehavior()

    // 「排序」弹层的显示开关：**纯 UI 状态**（Dart `_sortPopupOpen`）。锚点矩形在
    // Compose 侧由弹层自身的 TopEnd 对齐表达，不需要 Dart 那套 GlobalKey 取矩形。
    var sortPopupOpen by remember { mutableStateOf(false) }

    QingyuPageTheme {
        // 弹层要锚在「整个页面坐标系」的右上，所以 Scaffold 外面再包一层 Box。
        Box(modifier = Modifier.fillMaxSize()) {
            Scaffold(
                containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
                // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，放进槽位后
                // Scaffold 不再重复给一份（ScheduleListPage 第一版踩过）。
                topBar = {
                    TopAppBar(
                        title = CourseOverviewStrings.courseOverviewTitle.zh,
                        largeTitle = CourseOverviewStrings.courseOverviewTitle.zh,
                        scrollBehavior = scrollBehavior,
                        navigationIcon = {
                            IconButton(onClick = onBack) {
                                Icon(
                                    imageVector = MiuixIcons.Back,
                                    contentDescription = CourseOverviewStrings.cancelAction.zh,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                        },
                        // Dart 侧两个后缀都是 FHeaderAction 图标按钮：排序 + 添加。
                        actions = {
                            IconButton(onClick = { sortPopupOpen = true }) {
                                Icon(
                                    imageVector = MiuixIcons.Sort,
                                    contentDescription = CourseOverviewStrings.sortAction.zh,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                            IconButton(onClick = onAddCourse) {
                                Icon(
                                    imageVector = MiuixIcons.Add,
                                    contentDescription = CourseOverviewStrings.addNewCourseTooltip.zh,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
                        },
                    )
                },
            ) { innerPadding ->
                if (viewState.isEmpty) {
                    CourseOverviewEmptyState(
                        hint = viewState.emptyHint,
                        actionLabel = viewState.addCourseAction,
                        dark = dark,
                        onAddCourse = onAddCourse,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(innerPadding),
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(innerPadding)
                            .nestedScroll(scrollBehavior.nestedScrollConnection),
                        contentPadding = PaddingValues(
                            start = 16.dp,
                            end = 16.dp,
                            top = 8.dp,
                            // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                            bottom = innerPadding.calculateBottomPadding() + 24.dp,
                        ),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // 冲突入口：只有一条，详情在独立页（对齐 Dart「单入口」注释）。
                        if (viewState.conflictCount > 0) {
                            item(key = "conflict_entry") {
                                CourseConflictEntryCard(
                                    title = viewState.conflictEntryTitle,
                                    detail = viewState.conflictEntryDetail,
                                    dark = dark,
                                    onClick = onOpenConflictDetail,
                                )
                            }
                        }
                        items(viewState.rows, key = { "group_${it.group.name}" }) { row ->
                            CourseGroupRowCard(
                                row = row,
                                dark = dark,
                                onClick = { onOpenGroup(row.group) },
                            )
                        }
                    }
                }
            }

            if (sortPopupOpen) {
                CourseOverviewSortPopup(
                    options = viewState.sortOptions,
                    dark = dark,
                    onSelect = { option ->
                        onSortModeSelected(option.mode)
                        sortPopupOpen = false
                    },
                    onDismiss = { sortPopupOpen = false },
                )
            }
        }
    }
}

/**
 * 空态：全屏居中，提示句 + 添加入口（Dart `_buildEmptyState` 的正文与按钮）。
 *
 * 图标缺口见文件头「与 Dart 的渲染层差异」第三条。
 */
@Composable
private fun CourseOverviewEmptyState(
    hint: String,
    actionLabel: String,
    dark: Boolean,
    onAddCourse: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier.padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = PaddingValues(24.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = hint,
                    fontSize = 16.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                CourseOverviewActionButton(
                    text = actionLabel,
                    onClick = onAddCourse,
                )
            }
        }
    }
}

/**
 * 冲突详情入口行（Dart `HyperosListTile` 单入口）：橙色信息图标 + 标题 + 冲突节数 + 箭头。
 */
@Composable
private fun CourseConflictEntryCard(
    title: String,
    detail: String,
    dark: Boolean,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = MiuixIcons.Info,
                // Dart 侧该图标是装饰性的（行内有标题），不带语义标签。
                contentDescription = null,
                // HyperosIconColors.orange = 0xFFFF6B00（lib/ui/hyperos/hyperos_tokens.dart:128）。
                tint = COURSE_OVERVIEW_WARNING_ORANGE,
                modifier = Modifier.size(20.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = detail,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        }
    }
}

/**
 * 课程组行（Dart `_CourseGroupTile`）：
 * - 第一行：显示名（名称 /「名称 (短名)」）+ 冲突标签；
 * - 第二行：教师 · 课表摘要（多时段点号分隔）；
 * - 尾部：课程性质（必修/选修）+ 右箭头。
 *
 * 全部字符串由模型层 [CourseGroupRow] 提供，本函数不拼串（对齐「渲染层不做计算」）。
 */
@Composable
private fun CourseGroupRowCard(
    row: CourseGroupRow,
    dark: Boolean,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = row.displayName,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color(QingyuTheme.primaryText(dark)),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    if (row.hasConflict) {
                        Spacer(modifier = Modifier.width(6.dp))
                        // Dart HyperosTag：destructive 12% 底色 + 11sp w500。
                        Text(
                            text = CourseOverviewStrings.conflictLabel.zh,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(QingyuTheme.destructive()),
                            modifier = Modifier
                                .background(
                                    Color(QingyuTheme.destructive()).copy(alpha = 0.12f),
                                    RoundedCornerShape(4.dp),
                                )
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = row.subtitle,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = row.natureLabel,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        }
    }
}

/**
 * 「排序」选择弹层（Dart `HyperosSelectPopup` 的三项 + 当前档）。
 *
 * 形态差异见文件头第一条：官方 Card 容器的弹层，锚在页面右上、顶栏之下。
 * 三项文案与顺序来自 [CourseOverviewViewState.sortOptions]（added → name → schedule），
 * 当前档由 `isSelected` 标出（尾部落一个对勾）。
 */
@Composable
private fun CourseOverviewSortPopup(
    options: List<CourseSortOption>,
    dark: Boolean,
    onSelect: (CourseSortOption) -> Unit,
    onDismiss: () -> Unit,
) {
    val density = LocalDensity.current
    // 顶栏之下落弹层：系统状态栏高度 + 顶栏高度。TopAppBar 的小标题行标准高度
    // 约 60dp（与 ScheduleListPage 顶栏同款），这里按 60dp 估位；
    // 精确贴合留给真机逐页对照（L4）调。
    val statusBarPx = WindowInsets.statusBars.getTop(density)
    val offsetY = statusBarPx + with(density) { 60.dp.roundToPx() }

    Popup(
        alignment = Alignment.TopEnd,
        offset = IntOffset(x = with(density) { (-12).dp.roundToPx() }, y = offsetY),
        onDismissRequest = onDismiss,
        properties = PopupProperties(focusable = true),
    ) {
        Card(
            modifier = Modifier.widthIn(min = 160.dp),
            insideMargin = PaddingValues(vertical = 6.dp),
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                options.forEach { option ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            text = option.label,
                            fontSize = 15.sp,
                            fontWeight = if (option.isSelected) FontWeight.Medium else FontWeight.Normal,
                            color = if (option.isSelected) {
                                Color(QingyuTheme.primary(dark = dark))
                            } else {
                                Color(QingyuTheme.primaryText(dark))
                            },
                        )
                        if (option.isSelected) {
                            Spacer(modifier = Modifier.width(12.dp))
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = null,
                                tint = Color(QingyuTheme.primary(dark = dark)),
                                modifier = Modifier.size(16.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 主行动胶囊按钮（miuix 0.9.4 的 `Button` 只收 `content: @Composable RowScope.() -> Unit`，
 * 不认 `text`；这里包一层保持「只给文案」的调用形状，与 ScheduleListPage 的
 * `MiuixActionButton` 同款，避免每处按钮正文都重写一遍）。
 */
@Composable
private fun CourseOverviewActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(onClick = onClick, modifier = modifier, enabled = enabled) {
        Text(
            text = text,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = MiuixTheme.colorScheme.onPrimary,
        )
    }
}

/** HyperosIconColors.orange（lib/ui/hyperos/hyperos_tokens.dart:128）。 */
private val COURSE_OVERVIEW_WARNING_ORANGE = Color(0xFFFF6B00)

// ============================================================================
// 表单页目录的渲染侧接线（`lib/screens/timetable_form_pages_impl.dart` 的 Compose 形态）
// ============================================================================
//
// Catalog 本体（[TimetableFormPagesCatalog]）在 main 源集、是纯数据：每种表单页 =
// 类型标识 + 载荷 + 软校验，六个具名参数逐个透传、不做「取默认值」的简化。
// 落到渲染侧还差最后一步：**壳层拿到载荷之后，怎么变成一次页面展示**。
// Dart 侧这一步是 `kTimetableFormPages`：widgets 层声明 `TimetableFormPages` 接口，
// screens 层注入六个 builder，builder 里 new 出真正的页面。Kotlin/Compose 侧不需要
// register/get 与 StateError（页面可被壳直接引用），但**接口 + 注入**这层语义仍然
// 需要保留，理由有两条：
//
// 1. **本文件（course 域）不该 import 别的域的表单页**。考试页在 exam 域、日程/作业页在
//    各自的域、作息与更新详情页在别的批次——直接引用等于把本页的编译期绑到四条泳道
//    的在途进度上：对方签名一改、文件一挪，本页就编不过，挂载后还会把共享的 L1
//    （`compileComposeUiDebugKotlin`）一起拖红。那是台账 §7.2 明令要避免的局面。
// 2. 对齐 Dart 原始设计的依赖方向：页面构造由**上层**（screens/壳）持有，
//    widgets 层只认「载荷进来、页面出去」的接口。
//
// 所以这里用**组合函数参数注入**表达同一个契约：请求是六种载荷的一一对应联合，
// 页面本体由壳层按域接进来。课程表单（本域同批交付的 `AddCoursePage`）的接线就是
// `courseForm = { payload -> AddCoursePage(initialCourse = payload.initialCourse, …) }`
// ——六个字段与 [CourseFormPayload] 一一对应，逐字段透传（对照 Dart `_buildCourseForm`）。

/**
 * 表单页目录的渲染侧请求：与 [TimetableFormPageType] 的六种类型一一对应，
 * 每种携带各自的载荷（载荷字段由 Catalog 的契约测试钉死，这里原样装包）。
 */
sealed interface TimetableFormPageRequest {
    data class CourseForm(val payload: CourseFormPayload) : TimetableFormPageRequest

    data class ExamForm(val payload: ExamFormPayload) : TimetableFormPageRequest

    data class ScheduleItemForm(val payload: ScheduleItemFormPayload) : TimetableFormPageRequest

    data class TaskForm(val payload: TaskFormPayload) : TimetableFormPageRequest

    data class TimeSchemeManagement(val payload: TimeSchemeManagementPayload) : TimetableFormPageRequest

    data class AboutUpdate(val payload: AboutUpdatePayload) : TimetableFormPageRequest

    companion object {
        /**
         * 载荷 → 请求。目录外扩出的新类型返回 null（壳层按「不认识就不导航」处理），
         * 不在这里做任何字段改写。
         */
        fun fromPayload(payload: Any?): TimetableFormPageRequest? = when (payload) {
            is CourseFormPayload -> CourseForm(payload)
            is ExamFormPayload -> ExamForm(payload)
            is ScheduleItemFormPayload -> ScheduleItemForm(payload)
            is TaskFormPayload -> TaskForm(payload)
            is TimeSchemeManagementPayload -> TimeSchemeManagement(payload)
            is AboutUpdatePayload -> AboutUpdate(payload)
            else -> null
        }
    }
}

/**
 * 表单页目录的渲染侧入口：壳层把请求（由 [TimetableFormPageRequest.fromPayload] 转换）
 * 与各域页面本体一起传进来，本函数只做「请求 → 页面」的一一转发。
 *
 * 六个槽位与 Dart `TimelineFormPages` 的六个 builder 同序同名；未接线的槽位给空实现
 * （渲染空白）而不是抛异常——多会话并行期间，某一域页面尚未落地是常态，
 * 不该让宿主页崩溃。
 *
 * @param courseForm 课程表单（本域 `AddCoursePage`；六字段逐字段透传）
 * @param examForm 考试表单（exam 域）
 * @param scheduleItemForm 日程表单（schedule 域；`initialDate` / `occurrenceDate` 各归各，
 *   不许互相顶替——由 Catalog 的校验契约保证，本层原样转发两个字段）
 * @param taskForm 作业/任务表单（task 域）
 * @param timeSchemeManagement 作息方案管理页（time_scheme 域）
 * @param aboutUpdate 更新详情页（about 域）
 */
@Composable
fun TimetableFormPageEntry(
    request: TimetableFormPageRequest,
    courseForm: @Composable (CourseFormPayload) -> Unit,
    examForm: @Composable (ExamFormPayload) -> Unit = {},
    scheduleItemForm: @Composable (ScheduleItemFormPayload) -> Unit = {},
    taskForm: @Composable (TaskFormPayload) -> Unit = {},
    timeSchemeManagement: @Composable (TimeSchemeManagementPayload) -> Unit = {},
    aboutUpdate: @Composable (AboutUpdatePayload) -> Unit = {},
) {
    when (request) {
        is TimetableFormPageRequest.CourseForm -> courseForm(request.payload)
        is TimetableFormPageRequest.ExamForm -> examForm(request.payload)
        is TimetableFormPageRequest.ScheduleItemForm -> scheduleItemForm(request.payload)
        is TimetableFormPageRequest.TaskForm -> taskForm(request.payload)
        is TimetableFormPageRequest.TimeSchemeManagement -> timeSchemeManagement(request.payload)
        is TimetableFormPageRequest.AboutUpdate -> aboutUpdate(request.payload)
    }
}
