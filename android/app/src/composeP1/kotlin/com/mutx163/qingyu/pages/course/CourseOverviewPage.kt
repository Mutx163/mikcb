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
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.roundToInt
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.DropdownImpl
import top.yukonga.miuix.kmp.basic.DropdownItem
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.ListPopupColumn
import top.yukonga.miuix.kmp.basic.PopupPositionProvider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.ContactsBook
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Sort
import top.yukonga.miuix.kmp.overlay.OverlayListPopup
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
 * 2. 持有**纯 UI 状态** `sortPopupOpen` 与排序图标的屏幕坐标（Dart 侧同样放在 State 里，
 *    不是业务状态：`_sortPopupOpen` / `_sortAnchorRect`）；
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
 *   Compose 侧用官方 [OverlayListPopup] + [ListPopupColumn] + [DropdownImpl]（遮罩、
 *   进出场、返回键与点空白关闭都是官方组件自带；2026-11-03 弹窗审计收尾，弃裸
 *   `androidx.compose.ui.window.Popup` + [QingyuCard] 手拼）。**锚点位置按排序图标实测的
 *   屏幕矩形动态计算**（`onGloballyPositioned` 取 `boundsInWindow()`，经官方
 *   [PopupPositionProvider] 扩展点右对齐、贴图标下方 4dp），不再写死「状态栏 + 60dp」
 *   ——大标题折叠态下也贴得住。
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

    // 「排序」弹层的显示开关与锚点：**纯 UI 状态**（Dart `_sortPopupOpen` /
    // `_sortAnchorRect` 的对应物）。锚点在排序图标 `onGloballyPositioned` 时实测。
    var sortPopupOpen by remember { mutableStateOf(false) }
    var sortAnchorBounds by remember { mutableStateOf<Rect?>(null) }

    // 共享骨架（2026-11-05 B 组迁移）：官方顶栏 + 标准返回键 + 顶栏毛玻璃 + actions 槽。
    // 返回键的显隐（根页不画）与玻璃圆底的出没门控都由骨架注入；大标题仍可折叠
    //（Dart `course_overview_screen.dart:46` 走 HyperosSubpage 默认参数）。
    // 外层 Box 保留：排序弹层（`OverlayListPopup`）挂在 Scaffold 的 content 末尾，
    // 官方 Overlay 系弹层的宿主由 Scaffold 注入，这里只维持原来的根容器层级。
    Box(modifier = Modifier.fillMaxSize()) {
        QingyuPageScaffold(
            title = CourseOverviewStrings.courseOverviewTitle.text,
            onBack = onBack,
            // Dart 侧两个后缀都是 FHeaderAction 图标按钮：排序 + 添加。
            // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
            actions = {
                QingyuGlassIconButton(
                    onClick = { sortPopupOpen = true },
                    contentDescription = CourseOverviewStrings.sortAction.text,
                    icon = MiuixIcons.Sort,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    // 记下排序图标的屏幕矩形，弹层据此右对齐、贴其下方。
                    // 圆底外径 44dp（比原 IconButton 大 4dp），弹层跟着走 2dp，属预期。
                    modifier = Modifier.onGloballyPositioned { coords ->
                        sortAnchorBounds = coords.boundsInWindow()
                    },
                )
                QingyuGlassIconButton(
                    onClick = onAddCourse,
                    contentDescription = CourseOverviewStrings.addNewCourseTooltip.text,
                    icon = MiuixIcons.Add,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            },
        ) {
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
            // 排序弹层：常驻组合、按 show 切显示（官方 OverlayListPopup 内部驱动进出场、
            // 遮罩与返回/点空白关闭）。必须挂在 Scaffold 子树里——官方 Overlay 系的弹层
            // 宿主由 Scaffold 注入，挂到 Scaffold 外面弹不出来。
            CourseOverviewSortPopup(
                show = sortPopupOpen,
                options = viewState.sortOptions,
                anchor = sortAnchorBounds,
                onSelect = { option ->
                    onSortModeSelected(option.mode)
                    sortPopupOpen = false
                },
                onDismiss = { sortPopupOpen = false },
            )
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
                        text = CourseOverviewStrings.conflictLabel.text,
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
 * 官方 [OverlayListPopup] + [ListPopupColumn] + [DropdownImpl]：行内边距（首/末 20dp、
 * 中间 12dp、横向 20dp，官方默认值恰是 Dart `HyperosMiuixDropdown` 的口径）、选中态
 * （主题色字 + 尾部对勾）、遮罩、进出场动画、返回键与点空白关闭全部是官方组件自带
 *（2026-11-03 弹窗审计收尾，弃裸 `androidx.compose.ui.window.Popup` + [QingyuCard] 手拼）。
 *
 * 定位走官方 [PopupPositionProvider] 扩展点：**右对齐到排序图标、贴其下方 4dp**——
 * [anchor] 由调用方在排序图标的 `onGloballyPositioned` 实测传入（`boundsInWindow()`）。
 * 官方组件自带的锚是弹层的父布局（整页内容区），覆盖不到顶栏图标，所以按官方参数
 * 自定义定位；大标题折叠态下也贴得住。
 */
@Composable
private fun CourseOverviewSortPopup(
    show: Boolean,
    options: List<CourseSortOption>,
    anchor: Rect?,
    onSelect: (CourseSortOption) -> Unit,
    onDismiss: () -> Unit,
) {
    val density = LocalDensity.current
    val positionProvider = remember(anchor, density) {
        val gapPx = with(density) { 4.dp.roundToPx() }
        object : PopupPositionProvider {
            override fun calculatePosition(
                anchorBounds: IntRect,
                windowBounds: IntRect,
                layoutDirection: LayoutDirection,
                popupContentSize: IntSize,
                popupMargin: IntRect,
                alignment: PopupPositionProvider.Align,
            ): IntOffset {
                // 右对齐到排序图标、贴其下方；锚点还没测到时退回窗口右上角。
                // 第一个参数是「弹层父布局」的矩形（整页内容区），锚定一律用实测的 anchor。
                val x = (anchor?.right?.roundToInt() ?: windowBounds.right) - popupContentSize.width
                val y = (anchor?.bottom?.roundToInt() ?: windowBounds.top) + gapPx
                return IntOffset(
                    x = x.coerceIn(
                        windowBounds.left,
                        (windowBounds.right - popupContentSize.width).coerceAtLeast(windowBounds.left),
                    ),
                    y = y.coerceIn(
                        windowBounds.top,
                        (windowBounds.bottom - popupContentSize.height).coerceAtLeast(windowBounds.top),
                    ),
                )
            }

            override fun getMargins(): PaddingValues = PaddingValues(0.dp)
        }
    }

    // 常驻组合、按 show 切显示：进出场由官方组件内部驱动，退场动画能播完。
    OverlayListPopup(
        show = show,
        popupPositionProvider = positionProvider,
        alignment = PopupPositionProvider.Align.End,
        onDismissRequest = onDismiss,
    ) {
        ListPopupColumn {
            options.forEachIndexed { index, option ->
                DropdownImpl(
                    item = DropdownItem(text = option.label, selected = option.isSelected),
                    optionSize = options.size,
                    isSelected = option.isSelected,
                    index = index,
                    onSelectedIndexChange = { onSelect(option) },
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

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 分组、排序、冲突标记全部由真模型函数算：课程是普通 [com.mutx163.qingyu.core.Course]，
// 装配走 `CourseOverviewLogic.buildViewState(...)`（内部再走 `CourseGroup.buildFrom`），
// 预览里不手写一份假的组行。
//
// `Course` / `CourseNature` 用全限定名：本文件的 import 块按预览约定只允许动三行
// （`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览用课表：三门课（高数两个时段 + 物理 + 艺术）。 */
private val previewOverviewCourses = listOf(
    previewOverviewCourse("高等数学", "张明", "示例大学 A101", 1, 1, 2, "08:00", "09:40"),
    previewOverviewCourse("高等数学", "张明", "示例大学 A101", 3, 3, 4, "10:00", "11:40"),
    previewOverviewCourse("大学物理", "李海", "示例大学 B203", 2, 3, 4, "10:00", "11:40"),
    previewOverviewCourse(
        id = "course-art",
        name = "艺术鉴赏",
        teacher = "陈静",
        location = "艺术楼 201",
        dayOfWeek = 5,
        startSection = 7,
        endSection = 8,
        startTime = "16:00",
        endTime = "17:40",
        elective = true,
    ),
)

private fun previewOverviewCourse(
    name: String,
    teacher: String,
    location: String,
    dayOfWeek: Int,
    startSection: Int,
    endSection: Int,
    startTime: String,
    endTime: String,
    id: String = "course-$name-$dayOfWeek-$startSection",
    elective: Boolean = false,
) = com.mutx163.qingyu.core.Course(
    id = id,
    name = name,
    teacher = teacher,
    location = location,
    dayOfWeek = dayOfWeek,
    startSection = startSection,
    endSection = endSection,
    startTime = startTime,
    endTime = endTime,
    endWeek = 20,
    courseNature = if (elective) {
        com.mutx163.qingyu.core.CourseNature.ELECTIVE
    } else {
        com.mutx163.qingyu.core.CourseNature.REQUIRED
    },
)

private fun previewOverviewState(name: String): CourseOverviewViewState = when (name) {
    "空课表" -> CourseOverviewLogic.buildViewState(courses = emptyList(), conflictMap = emptyMap())
    "有冲突" -> CourseOverviewLogic.buildViewState(
        courses = previewOverviewCourses,
        conflictMap = mapOf("course-高等数学-1-1" to listOf(previewOverviewCourses[0])),
        sortMode = CourseOverviewSortMode.NAME,
    )
    else -> CourseOverviewLogic.buildViewState(
        courses = previewOverviewCourses,
        conflictMap = emptyMap(),
        sortMode = CourseOverviewSortMode.ADDED,
    )
}

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewOverviewBody(
    state: CourseOverviewViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        CourseOverviewPage(
            viewState = state,
            onBack = {},
            onAddCourse = {},
            onOpenGroup = {},
            onOpenConflictDetail = {},
            onSortModeSelected = {},
        )
    }
}

// ── 单档：三态 × 亮色 ─────────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有课", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewOverviewData() {
    PreviewOverviewBody(previewOverviewState("有课"))
}

@Suppress("unused")
@Preview(name = "2 空课表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewOverviewEmpty() {
    PreviewOverviewBody(previewOverviewState("空课表"))
}

@Suppress("unused")
@Preview(name = "3 有冲突", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewOverviewConflict() {
    PreviewOverviewBody(previewOverviewState("有冲突"))
}

// ── 单档：外观两档（以「有课」为基准）─────────────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewOverviewDark() {
    PreviewOverviewBody(previewOverviewState("有课"), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewOverviewLargeText() {
    PreviewOverviewBody(previewOverviewState("有课"), textScale = 1.3f)
}

// ── 总览：三态并排，一屏比结构差异 ───────────────────────────────────────────

/**
 * 一屏总览：三种状态横向并排，用来一眼比结构差异（谁多了 / 少了哪一块）。
 *
 * 3 × 400dp = 1200dp，画布给 1200dp；Studio 等比缩小显示，**缩放后字看不清是正常的**
 * ——要看细节点上面 1~5 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·三态并排", showBackground = true, widthDp = 1200, heightDp = 900)
@Composable
private fun PreviewOverviewStates() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (name in listOf("有课", "空课表", "有冲突")) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewOverviewBody(previewOverviewState(name))
            }
        }
    }
}
