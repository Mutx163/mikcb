package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.DropdownImpl
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.ListPopupColumn
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.PopupPositionProvider
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.ContactsBook
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Sort
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.window.WindowListPopup

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
 * 2. 持有**纯 UI 状态** `sortPopupOpen`（Dart 侧同样放在 State 里，不是业务状态：
 *    `_sortPopupOpen`）；锚点不再手写状态——官方弹层以父级 Box 为锚（见下）；
 * 3. 把点击回调按语义转给壳层（onOpenGroup 带整组，onOpenConflictDetail 不带参数）。
 *
 * ## 视觉对齐 Flutter 原页（2026-10-28 逐项核对）
 *
 * - **同名课程行是「一整张卡片里的多行」**，不是一行一张卡：Dart 用
 *   `HyperosListView > HyperosListGroup(children = [for group in sorted _CourseGroupTile])`，
 *   一张 `HyperosAdaptiveCard` 里竖排全部课程行（无行间分割线）。本页照此把全部课程行放进
 *   **同一个** [QingyuCard]，行内边距 16/13、两行行高下限 72dp（对齐
 *   `HyperosTokens.chevronRowPadding` / `listRowTwoLineMinHeight`）。
 * - **冲突入口单独一张卡**：Dart 是独立的单行 `HyperosListGroup`，其后再接
 *   `HyperosSectionGap`（12dp）到课程卡，与 [QingyuPageList] 的 `spacedBy(12.dp)` 同值。
 * - **字号**对齐 Dart `HyperosTypography`：标题 17sp（`textStyles.main`）/ 副标题与课程性质
 *   14sp（`textStyles.body2`）/ 冲突标签 11sp（`textStyles.footnote2`）；标题↔副标题间距 3dp
 *   （`titleCaptionGap`）。
 * - **空态**对齐 Dart `_buildEmptyState`：居中 56dp 图标 + 提示句 + 主按钮（图标见差异说明）。
 *
 * ## 与 Dart 的渲染层差异（都记在这里，不进别的文件）
 *
 * - **排序弹层**：Dart 用 `HyperosSelectPopup`（常驻挂载 + 锚定矩形 + 切 show）。
 *   这里用官方窗口级列表弹层 [WindowListPopup] + [ListPopupColumn] + [DropdownImpl]
 *   （2026-11-02 弹窗审核 S6：旧版是裸 `androidx.compose.ui.window.Popup` + 自拼三行，
 *   已换成官方件并从例外表「待核」移除）。**锚点 = 包裹排序图标的父级 Box**（官方 demo
 *   同款写法），`Align.End` 右对齐到图标、贴其下方；菜单类弹层不压暗背景
 *   （`enableWindowDim = false`）。弹层常驻组合、`show` 驱动，选中态（主色字 + 对勾）
 *   由官方条目行自带，不再自绘。
 * - **冲突入口图标**：Dart 用 `Icons.warning_amber_rounded` + `HyperosIconColors.orange`
 *   （`0xFFFF6B00`）。Miuix 0.9.4 的 extended 图标里**没有**警告类字形，取最接近的官方
 *   [MiuixIcons.Info]，颜色沿用 Dart 的橙色（语义由橙色 + 行内标题承载，不靠字形）。
 * - **空态图标**：Dart 用 `Icons.school_outlined`，Miuix 无学校字形，取官方
 *   [MiuixIcons.ContactsBook]（全站「课程」语义已用它，见任务页「查看课程」按钮），
 *   尺寸 / 颜色与 Dart 同（56dp / secondaryText）。
 *
 * @param viewState 整页视图状态（模型层产出，见 [CourseOverviewViewState]）
 * @param onBack 返回（Dart `onBack: Navigator.pop`）
 * @param onAddCourse 顶栏「+」与空态按钮（Dart 两处都进 `/course/create`）
 * @param onOpenGroup 点课程组行进**组编辑**页（Dart `AddCourseScreen(courseGroup: group)`）
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

    // 「排序」弹层的显示开关：**纯 UI 状态**（Dart `_sortPopupOpen` 的对应物）。
    var sortPopupOpen by remember { mutableStateOf(false) }

    QingyuPageTheme {
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
                            // 排序弹层以这层 Box 为锚（官方 WindowListPopup demo 同款写法）：
                            // 弹层与触发件包在同一个 Box 里，右对齐贴图标下方。
                            // 弹层常驻组合、只翻 `show`（与全仓弹层口径一致）。
                            Box {
                                IconButton(onClick = { sortPopupOpen = true }) {
                                    Icon(
                                        imageVector = MiuixIcons.Sort,
                                        contentDescription = CourseOverviewStrings.sortAction.zh,
                                        tint = Color(QingyuTheme.actionIcon(dark)),
                                    )
                                }
                                CourseOverviewSortPopup(
                                    show = sortPopupOpen,
                                    options = viewState.sortOptions,
                                    onSelect = { option ->
                                        onSortModeSelected(option.mode)
                                        sortPopupOpen = false
                                    },
                                    onDismiss = { sortPopupOpen = false },
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
                    // 主滚动统一走共享套件：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
                    // 与右侧滚动条。横向留白按配方由每个块自己带 12dp，**不**放进
                    // contentPadding —— 放进去滚动条会跟着内缩、也偏离 28dp 轴线。
                    QingyuPageList(
                        innerPadding = innerPadding,
                        scrollBehavior = scrollBehavior,
                        contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // 冲突入口：只有一条，详情在独立页（对齐 Dart「单入口」注释）。
                        // 它是**独立的单行卡片**，与课程卡之间由 spacedBy(12dp) 隔开
                        // （= Dart 的 HyperosSectionGap）。
                        if (viewState.conflictCount > 0) {
                            item(key = "conflict_entry") {
                                CourseConflictEntryCard(
                                    title = viewState.conflictEntryTitle,
                                    detail = viewState.conflictEntryDetail,
                                    dark = dark,
                                    modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                                    onClick = onOpenConflictDetail,
                                )
                            }
                        }
                        // 同名课程聚合行：**全部行放进同一张卡片**（Dart 的一个 HyperosListGroup）。
                        item(key = "course_list") {
                            CourseGroupListCard(
                                rows = viewState.rows,
                                dark = dark,
                                modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                                onOpenGroup = onOpenGroup,
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 空态：全屏居中，图标 + 提示句 + 添加入口（对齐 Dart `_buildEmptyState`）。
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
        modifier = modifier.padding(32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                imageVector = MiuixIcons.ContactsBook,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(56.dp),
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = hint,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(20.dp))
            CourseOverviewActionButton(
                text = actionLabel,
                onClick = onAddCourse,
            )
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
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 72.dp)
                .padding(horizontal = 16.dp, vertical = 13.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Dart `HyperosListTile(icon: warning_amber, iconAccent: orange)` 走的是
            // `HyperosIconBadge`：26dp 实色圆角方块 + 14dp 白色字形（tiles.dart:155-164）。
            Box(
                modifier = Modifier
                    .size(26.dp)
                    .background(COURSE_OVERVIEW_WARNING_ORANGE, RoundedCornerShape(7.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = MiuixIcons.Info,
                    // Dart 侧该图标是装饰性的（行内有标题），不带语义标签。
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = detail,
                    style = MiuixTheme.textStyles.body2,
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
 * 同名课程聚合卡：**一整张卡片里竖排全部课程行**（Dart 的一个 `HyperosListGroup`）。
 *
 * 行内点击进组编辑页；行间没有分割线（Dart 原页即如此，靠 26dp 纵向留白 + 两行内容分隔）。
 */
@Composable
private fun CourseGroupListCard(
    rows: List<CourseGroupRow>,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onOpenGroup: (CourseGroup) -> Unit,
) {
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        // 行自己带 16/13 内边距，卡片不再额外给内边距（对齐 Dart HyperosListGroup）。
        insideMargin = PaddingValues(0.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            rows.forEach { row ->
                CourseGroupRow(
                    row = row,
                    dark = dark,
                    onClick = { onOpenGroup(row.group) },
                )
            }
        }
    }
}

/**
 * 单条课程组行（Dart `_CourseGroupTile`）：
 * - 第一行：显示名（名称 /「名称 (短名)」）+ 冲突标签；
 * - 第二行：教师 · 课表摘要（多时段点号分隔）；
 * - 尾部：课程性质（必修/选修）+ 右箭头。
 *
 * 全部字符串由模型层 [CourseGroupRow] 提供，本函数不拼串（对齐「渲染层不做计算」）。
 */
@Composable
private fun CourseGroupRow(
    row: CourseGroupRow,
    dark: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            // 两行行高下限 72dp（Dart HyperosTokens.listRowTwoLineMinHeight）；
            // heightIn 在 padding 之前 → 约束的是「内容 + 内边距」的总高。
            .heightIn(min = 72.dp)
            .padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = row.displayName,
                    // Dart listTitle = 17sp（textStyles.main）。
                    style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
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
                        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
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
            // Dart titleCaptionGap = 3dp。
            Spacer(modifier = Modifier.height(3.dp))
            Text(
                text = row.subtitle,
                // Dart listDetail = 14sp（textStyles.body2）。
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            text = row.natureLabel,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
        )
    }
}

/**
 * 「排序」选择弹层（Dart `HyperosSelectPopup` 的三项 + 当前档）。
 *
 * 官方窗口级列表弹层 [WindowListPopup]（窗口层级渲染，不需要 Scaffold 宿主），
 * 锚点是调用处包裹排序图标的父级 Box（官方 demo 同款写法），`Align.End` 右对齐到
 * 图标、贴其下方。三项文案与顺序来自 [CourseOverviewViewState.sortOptions]
 * （added → name → schedule）；条目行用官方 [DropdownImpl]，当前档由它自带的
 * 主色字 + 对勾标出（对应旧自绘行的 17sp / 主题色 / `MiuixIcons.Ok` 配方）。
 * 菜单不压暗背景（`enableWindowDim = false`，对齐旧裸 Popup 与 Dart 的表现）。
 */
@Composable
private fun CourseOverviewSortPopup(
    show: Boolean,
    options: List<CourseSortOption>,
    onSelect: (CourseSortOption) -> Unit,
    onDismiss: () -> Unit,
) {
    WindowListPopup(
        show = show,
        alignment = PopupPositionProvider.Align.End,
        enableWindowDim = false,
        minWidth = 180.dp,
        onDismissRequest = onDismiss,
    ) {
        ListPopupColumn {
            options.forEachIndexed { index, option ->
                DropdownImpl(
                    text = option.label,
                    optionSize = options.size,
                    isSelected = option.isSelected,
                    index = index,
                    onSelectedIndexChange = { onSelect(options[it]) },
                )
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
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = MiuixTheme.colorScheme.onPrimary,
        )
    }
}

/** 冲突入口图标色：走 `HyperosIconColors.orange` 的 Compose 端口（0xFFFF6B00，与 Dart 同值）。 */
private val COURSE_OVERVIEW_WARNING_ORANGE = Color(QingyuIconColors.ORANGE)

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
