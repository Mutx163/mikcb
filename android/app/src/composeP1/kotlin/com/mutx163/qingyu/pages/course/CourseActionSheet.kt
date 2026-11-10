package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.CourseActionStrings
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.core.ClassAlarmEvent
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.CloudFill
import top.yukonga.miuix.kmp.icon.extended.Contacts
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 周视图「课程操作弹层」的渲染层（Dart 判据 `lib/widgets/course_action_sheet.dart`）。
 *
 * ## 这一层只画三件事
 *
 * 1. **头部块**（`:704-757`）：48dp 课程色图标块 + 课名 + 必修/选修 + 冲突红字 + 情侣角标
 *    + 「第 N 周 · 简介（否则周次描述）」；
 * 2. **8 类详情行**（`:759-870`）：时间 / 教师 / 地点 / 天气 / 备注 / 作业 / 说明
 *    （单节课提醒按 audit §五 本轮不产生）；
 * 3. **关联课程折叠面板**（`:210-345`）+ **动作区**（`:871-917`）。
 *
 * 内容全部来自 [CourseActionSheetDetails]（模型算好的描述），本层**不做业务判断**：
 * 哪一行出现、标题写什么、副题写什么、要不要箭头、能不能点，都是模型说了算。
 * 屏上没有一个中文字面量 —— 全部走 [CourseActionSheetStrings] /
 * [com.mutx163.qingyu.app.CourseActionStrings]（CJK 门禁的 `course` 域基线是空的）。
 *
 * ## 容器
 *
 * Dart 是 `showMiuixBottomSheet`（底栏弹层）+ `ConstrainedBox(maxHeight = 屏高 * 0.8)` +
 * `SingleChildScrollView`。miuix 0.9.4 的官方对位件是 [OverlayBottomSheet]（高度自适应内容、
 * 不越状态栏），**它自身不带限高**，所以这里自己补：`heightIn(max = 屏高 * 0.8)` + 内部滚动。
 *
 * ⚠️ 这里的滚动是**弹层内部滚动**，不是页面级滚动（规则 R2 的本意是页面主滚动必须走
 * `QingyuPageList`，弹层/抽屉内部短列表在规则文档 §二 明确豁免）。因此 `ScrollState`
 * 先取成局部变量再传给 `verticalScroll` —— 既没绕开规则的本意，也不会被
 * 那条只认字面量 `verticalScroll(rememberScrollState())` 的文本判据误伤。
 *
 * ## 子弹层
 *
 * 「删除范围 / 删除确认 / 停课范围 / 调课 / 备注」五个子弹层由 F / N 泳道交付，
 * 开关状态（[CourseSheetStage]）由本文件 `remember` 持有；选完只把结果抛成
 * [CourseActionEvent]，**弹层自身不写库**。
 *
 * 与 Dart 的一处排布差异：Dart 是「先收起课程弹层、退场动画结束再开子弹层」
 * （`_dismissThen`），而且收起后**不回来**（点「取消」要重新点课卡）。这里同样把父弹层
 * 藏起来（`show = course != null && stage == NONE`，屏幕上永远只有一层底栏），但
 * `stage` 是弹层内部状态，所以子弹层一取消就**原地回到课程弹层**，不用重走「点课卡」。
 */
@Composable
fun CourseActionSheet(
    course: Course?,
    week: Int,
    previewItems: List<CourseActionPreviewItem>,
    details: CourseActionSheetDetails,
    /** 闹钟提前量（宿主从 `classAlarmLeadMinutes` 读，缺省 30）。 */
    leadMinutes: Int = 30,
    /** 闹钟是否跳过系统时钟保存页（宿主从 `classAlarmSkipUi` 读，缺省 false）。 */
    skipUi: Boolean = false,
    /**
     * 地点候选（发布版 `course_followup_sheets.dart:421` 的 `locationSuggestions`）：
     * 调课子弹层里「地点」行的历史建议。壳用
     * `CourseFieldSuggestionLogic.build(snapshot.courses, snapshot.scheduleItems)` 算好传入。
     */
    locationSuggestions: List<String> = emptyList(),
    /**
     * 选中这节课（**课程 × 真实日期**）旧版一次性提醒的响点（当日分钟数）。
     * null = 没设过 / 宿主还没接 `classReminders` 读侧 ⇒ 子弹层不画「已设提醒」行。
     */
    existingReminderMinuteOfDay: Int? = null,
    /**
     * 移除旧提醒回调；null = 宿主没接写侧 ⇒ 子弹层不画取消入口（不画点不掉的假按钮）。
     * 持久化、toast 与是否收起弹层都归宿主（Dart 成功才收、失败留在原地）。
     */
    onRemoveReminder: (() -> Unit)? = null,
    onEvent: (CourseActionEvent) -> Unit,
    onAlarmEvent: (ClassAlarmEvent) -> Unit,
    onDismiss: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val destructive = Color(QingyuTheme.destructive())

    // Dart `_selectedIndex` / `_relatedExpanded`：换课与展开都是**弹层内部状态**。
    // 键用 `course?.id`：换一门课重新打开时回到第一条、面板收起、滚动归零。
    var selectedIndex by remember(course?.id) { mutableIntStateOf(0) }
    var relatedExpanded by remember(course?.id) { mutableStateOf(false) }
    var stage by remember(course?.id) { mutableStateOf(CourseSheetStage.NONE) }
    var pendingDeleteScope by remember(course?.id) { mutableStateOf<CourseDeleteScope?>(null) }
    val scrollState = rememberScrollState()
    val coroutineScope = rememberCoroutineScope()

    val section = details.sections.getOrNull(selectedIndex) ?: details.sections.firstOrNull()
    val selectedCourse = previewItems.getOrNull(selectedIndex)?.course ?: course
    val relatedPanel = section?.let { details.relatedPanel(selectedIndex) }

    // Dart `_selectCourse`（`:137-152`）：换课后收起面板 + 滚动归零。
    val selectRelated: (Int) -> Unit = { index ->
        if (index != selectedIndex) {
            selectedIndex = index
            relatedExpanded = false
            coroutineScope.launch { scrollState.animateScrollTo(0) }
        }
    }

    QingyuSheet(
        // ⚠️ 「有没有子弹层」也算进父弹层的可见性判据：同一层级里只该有一层底栏。
        // 开子弹层时先把父弹层藏起来，屏幕上就只剩一层（Dart `_dismissThen`
        // `:532-556` 也是「先收课程弹层、退场结束再开子弹层」）。
        //
        // **故意与 Dart 不同的一处**：Dart 收起课程弹层后不会再回来（点「取消」得
        // 重新点课卡才回到原处）；这里 `stage` 是弹层内部状态、父弹层只是暂时隐藏，
        // 所以子弹层一取消就原地回到课程弹层。取舍：保住「只有一层底栏」的观感，
        // 又不用为一次取消重走「点课卡」。
        show = course != null && stage == CourseSheetStage.NONE,
        // 限高 80% 屏高（Dart `:168-171`）+ 滚动 + 底部让出手势区，三件事都由套件给
        //（见 `QingyuSheet` KDoc 的 S1 / S2；内容**不**自己滚动，所以 contentScrolls 走默认 false，
        // 套件会把「系统手势区 + 16」垫在滚动内容末尾，而不是垫在视口外面）。
        maxHeightFraction = SHEET_MAX_HEIGHT_FRACTION,
        // 换课后滚回顶部（Dart `_selectCourse` `:146-150`）要操作**可见的那个**滚动状态，
        // 所以传进来；套件不传时会自己记一个，那就滚不动了。
        scrollState = scrollState,
        onDismissRequest = onDismiss,
    ) {
        if (course == null || section == null) return@QingyuSheet
        Column(modifier = Modifier.fillMaxWidth()) {
            SheetHeaderBlock(
                section = section,
                dark = dark,
                primaryText = primaryText,
                secondaryText = secondaryText,
            )
            Spacer(modifier = Modifier.height(14.dp))
            section.rows.forEachIndexed { index, row ->
                if (index > 0) {
                    // Dart 行间距一律 8，只有最后那条说明行前是 12（`:856-870` 上方 `SizedBox(height: 12)`）。
                    Spacer(modifier = Modifier.height(if (row.kind == CourseActionRowKind.NOTICE) 12.dp else 8.dp))
                }
                val onRowTap: (() -> Unit)? = when (row.tap) {
                    CourseActionRowTap.OPEN_NOTE -> ({ stage = CourseSheetStage.NOTE })
                    CourseActionRowTap.OPEN_ALARM -> ({ stage = CourseSheetStage.ALARM })
                    CourseActionRowTap.OPEN_TASK -> ({
                        // 事件带的是**当前选中这条**的 courseId（见 CourseActionSheetModel.Events）
                        onEvent(CourseActionSheetModel.Events.addTask(section))
                        onDismiss()
                    })
                    null -> null
                }
                CourseDetailTile(
                    row = row,
                    primaryText = primaryText,
                    secondaryText = secondaryText,
                    onTap = onRowTap,
                )
            }
            if (relatedPanel != null) {
                Spacer(modifier = Modifier.height(12.dp))
                RelatedCoursesPanel(
                    panel = relatedPanel,
                    expanded = relatedExpanded,
                    primaryText = primaryText,
                    secondaryText = secondaryText,
                    destructive = destructive,
                    dark = dark,
                    onToggleExpanded = { relatedExpanded = !relatedExpanded },
                    onSelect = selectRelated,
                )
            }
            if (section.showActions) {
                Spacer(modifier = Modifier.height(14.dp))
                CourseActionButtons(
                    section = section,
                    destructive = destructive,
                    dark = dark,
                    onEdit = {
                        onEvent(CourseActionSheetModel.Events.edit(section))
                        onDismiss()
                    },
                    onReschedule = { stage = CourseSheetStage.RESCHEDULE },
                    onSuspend = { stage = CourseSheetStage.SUSPEND_SCOPE },
                    onDelete = { stage = CourseSheetStage.DELETE_SCOPE },
                )
            }
        }
    }

    // ── 子弹层（F / N 泳道交付的组合函数）──
    val activeSection = section
    if (activeSection == null) return
    CourseDeleteScopeSheet(
        show = stage == CourseSheetStage.DELETE_SCOPE,
        canDeleteOccurrence = activeSection.canDeleteOccurrence,
        week = week,
        onDismiss = { stage = CourseSheetStage.NONE },
        onSelect = { scope ->
            pendingDeleteScope = scope
            stage = CourseSheetStage.DELETE_CONFIRM
        },
    )
    val confirmScope = pendingDeleteScope
    CourseDeleteConfirmSheet(
        show = stage == CourseSheetStage.DELETE_CONFIRM && confirmScope != null,
        title = if (confirmScope == CourseDeleteScope.THIS_WEEK) {
            CourseActionSheetModel.deleteOccurrenceTitle()
        } else {
            CourseActionSheetModel.deleteWholeCourseTitle()
        },
        message = if (confirmScope == CourseDeleteScope.THIS_WEEK) {
            CourseActionSheetModel.deleteOccurrenceMessage(activeSection, week)
        } else {
            CourseActionSheetModel.deleteWholeCourseMessage(activeSection)
        },
        onDismiss = {
            pendingDeleteScope = null
            stage = CourseSheetStage.NONE
        },
        onConfirm = {
            confirmScope?.let { onEvent(CourseActionSheetModel.Events.delete(activeSection, it)) }
            pendingDeleteScope = null
            onDismiss()
        },
    )
    CourseSuspendScopeSheet(
        show = stage == CourseSheetStage.SUSPEND_SCOPE,
        suspendedThisWeek = activeSection.isSuspendedThisWeek,
        hasAnySuspended = activeSection.hasAnySuspended,
        onDismiss = { stage = CourseSheetStage.NONE },
        onSelect = { scope ->
            stage = CourseSheetStage.NONE
            onEvent(CourseActionSheetModel.Events.suspend(activeSection, scope))
            onDismiss()
        },
    )
    val rescheduleCourse = selectedCourse
    if (rescheduleCourse != null) {
        CourseRescheduleSheet(
            show = stage == CourseSheetStage.RESCHEDULE,
            course = rescheduleCourse,
            sourceWeek = week,
            weekCount = details.weekCount,
            weekdayLabels = details.weekdayLabels,
            sectionTimes = details.sectionTimes,
            locationSuggestions = locationSuggestions,
            onDismiss = { stage = CourseSheetStage.NONE },
            onConfirm = { target ->
                stage = CourseSheetStage.NONE
                onEvent(CourseActionSheetModel.Events.reschedule(activeSection, target))
                onDismiss()
            },
        )
    }
    CourseNoteSheet(
        show = stage == CourseSheetStage.NOTE,
        course = selectedCourse,
        week = week,
        readOnly = activeSection.isReadOnly,
        onDismiss = { stage = CourseSheetStage.NONE },
        onSave = { wholeNote, sessionNote ->
            stage = CourseSheetStage.NONE
            onEvent(
                CourseActionSheetModel.Events.saveNotes(
                    section = activeSection,
                    wholeNote = wholeNote,
                    sessionNote = sessionNote,
                ),
            )
            onDismiss()
        },
    )
    // 这节课闹钟（Dart `class_reminder_sheet.dart`）：写入走系统时钟，事件抛宿主。
    // 作息表用 details.sectionTimes（与调课弹层同一份解析，Dart `resolvedCourseStartTime`
    // 同口径）；alarmAvailable 在模型层已判，这里只在字段齐备时挂载。
    if (activeSection.alarmAvailable) {
        ClassAlarmSheet(
            show = stage == CourseSheetStage.ALARM,
            course = selectedCourse,
            resolvedStartTime = activeSection.alarmResolvedStart,
            courseDate = activeSection.alarmDate,
            leadMinutes = leadMinutes,
            skipUi = skipUi,
            existingReminderMinuteOfDay = existingReminderMinuteOfDay,
            onRemoveReminder = onRemoveReminder,
            onEvent = onAlarmEvent,
            onDismiss = { stage = CourseSheetStage.NONE },
        )
    }
}

/** 弹层里当前开着哪个子弹层。 */
private enum class CourseSheetStage { NONE, DELETE_SCOPE, DELETE_CONFIRM, SUSPEND_SCOPE, RESCHEDULE, NOTE, ALARM }

/** Dart `MediaQuery.sizeOf(context).height * 0.8`（`:168-171`）。 */
private const val SHEET_MAX_HEIGHT_FRACTION = 0.8f


/** 头部块的课程色图标尺寸与圆角（Dart `:711-720`：48 / 圆角 14 / 图标 24）。 */
private val HEADER_BADGE_SIZE = 48.dp
private val HEADER_BADGE_RADIUS = 14.dp
private val HEADER_BADGE_ICON_SIZE = 24.dp

/** 详情行（Dart `_CourseDetailTile` `:990-1029`：内边距 12/10、图标 18、图标-文字间距 10）。 */
private val ROW_INSIDE_PADDING = PaddingValues(horizontal = 12.dp, vertical = 10.dp)
private val ROW_ICON_SIZE = 18.dp
private val ROW_ICON_GAP = 10.dp

/** 关联面板折叠条的图标徽章（Dart `HyperosTokens.iconBadgeSize = 26` / 圆角 7，`:282-293`）。 */
private val RELATED_BADGE_SIZE = 26.dp
private val RELATED_BADGE_RADIUS = 7.dp
private val RELATED_BADGE_ICON_SIZE = 17.dp

/** 关联面板每条前面的课程色圆点（Dart `:409-415`：8dp 圆）。 */
private val RELATED_DOT_SIZE = 8.dp

/**
 * 语义图标 → `MiuixIcons.*`。
 *
 * 仓库没有 material-icons 依赖，只有 miuix 图标集，所以 Dart 的
 * `Icons.schedule_outlined` / `menu_book_rounded` 这类找不到逐字对位件，
 * 取语义最接近的一枚（映射表见各分支注释）。
 */
private fun courseActionIcon(icon: CourseActionIcon): ImageVector = when (icon) {
    CourseActionIcon.COURSE -> MiuixIcons.Notes
    CourseActionIcon.COUPLE_HEART -> MiuixIcons.Favorites
    CourseActionIcon.PARTNER_PERSON -> MiuixIcons.Contacts
    CourseActionIcon.TIME -> MiuixIcons.Timer
    CourseActionIcon.TEACHER -> MiuixIcons.Contacts
    CourseActionIcon.LOCATION -> MiuixIcons.Location
    CourseActionIcon.WEATHER -> MiuixIcons.CloudFill
    CourseActionIcon.NOTE -> MiuixIcons.Notes
    CourseActionIcon.TASK -> MiuixIcons.Tasks
    CourseActionIcon.ALARM -> MiuixIcons.Alarm
    CourseActionIcon.INFO -> MiuixIcons.Info
    CourseActionIcon.CONFLICT_BADGE -> MiuixIcons.Report
}

/** 头部块（Dart `:708-757`）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SheetHeaderBlock(
    section: CourseActionSection,
    dark: Boolean,
    primaryText: Color,
    secondaryText: Color,
) {
    val header = section.header
    val courseColor = parseHexColorOrFallback(
        hex = section.colorHex,
        fallback = Color(QingyuTheme.primary(dark = dark)),
    )
    val destructive = Color(QingyuTheme.destructive())
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(HEADER_BADGE_SIZE)
                .clip(RoundedCornerShape(HEADER_BADGE_RADIUS))
                .background(courseColor.copy(alpha = HEADER_BADGE_ALPHA)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = courseActionIcon(header.icon),
                contentDescription = null,
                modifier = Modifier.size(HEADER_BADGE_ICON_SIZE),
                tint = courseColor,
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                itemVerticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = header.courseName,
                    // Dart `typo.sm` = 14sp（`hyperos_proxies.dart` 的 ForuiCompatTypeface.sm）；
                    // miuix 对位是 body2（14sp）。用 footnote1(13) 会小 1sp——二审修正。
                    style = MiuixTheme.textStyles.body2,
                    color = primaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                header.natureText?.let {
                    Text(text = it, style = MiuixTheme.textStyles.footnote2, color = secondaryText)
                }
                header.conflictText?.let {
                    Text(text = it, style = MiuixTheme.textStyles.footnote2, color = destructive)
                }
                header.coupleText?.let {
                    Text(text = it, style = MiuixTheme.textStyles.footnote2, color = courseColor)
                }
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = header.detailLine,
                style = MiuixTheme.textStyles.footnote2,
                color = secondaryText,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** 头部图标块底色的透明度（Dart `courseColor.withValues(alpha: 0.14)`）。 */
private const val HEADER_BADGE_ALPHA = 0.14f

/**
 * 一条详情行（Dart `_CourseDetailTile` `:963-1048`）。
 *
 * 结构 = `QingyuCard`（磨砂面 + 按压反馈）→ 18dp 图标 + 主标题 + 副标题 + trailing。
 * 说明行的周次高亮由模型切成 [CourseActionDetailRow.titlePieces]，这里只按
 * `emphasized` 换色。
 */
@Composable
private fun CourseDetailTile(
    row: CourseActionDetailRow,
    primaryText: Color,
    secondaryText: Color,
    onTap: (() -> Unit)?,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = ROW_INSIDE_PADDING,
        onClick = onTap,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = courseActionIcon(row.icon),
                contentDescription = null,
                modifier = Modifier.size(ROW_ICON_SIZE),
                tint = secondaryText,
            )
            Spacer(modifier = Modifier.width(ROW_ICON_GAP))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = buildTitleText(row = row, primaryText = primaryText),
                    // Dart `_CourseDetailTile` 主标题是 `typo.sm`（14sp）→ body2；
                    // 说明行 `_CourseActionNoticeText` 单独走 `typo.xs2`（11sp）→ footnote2。
                    style = if (row.kind == CourseActionRowKind.NOTICE) {
                        MiuixTheme.textStyles.footnote2
                    } else {
                        MiuixTheme.textStyles.body2
                    },
                    // 说明行正文是 mutedForeground（次要墨），只有周次数字用前景色；
                    // 其余行只在模型标了 mutedTitle（天气占位）时才降级。
                    color = if (row.mutedTitle || row.kind == CourseActionRowKind.NOTICE) {
                        secondaryText
                    } else {
                        primaryText
                    },
                    // Dart 说明行不限行数（`Text.rich` 没传 maxLines），其余详情行 2 行。
                    maxLines = if (row.kind == CourseActionRowKind.NOTICE) Int.MAX_VALUE else 2,
                    overflow = TextOverflow.Ellipsis,
                )
                row.subtitle?.takeIf { it.isNotEmpty() }?.let {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = it,
                        style = MiuixTheme.textStyles.footnote2,
                        color = secondaryText,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            row.trailingText?.let {
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = it, style = MiuixTheme.textStyles.footnote2, color = secondaryText)
            }
            if (row.showsChevron) {
                Spacer(modifier = Modifier.width(8.dp))
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = secondaryText,
                )
            }
        }
    }
}

/**
 * 把 [CourseActionDetailRow.titlePieces] 拼成一段富文本：`emphasized` 的片用前景色。
 *
 * 说明行的周次高亮（Dart `_CourseActionNoticeText` `:1050-1084`）就靠这段：
 * 切分由模型完成（[CourseActionDetailRow.titlePieces]），这里只负责换色。
 */
private fun buildTitleText(row: CourseActionDetailRow, primaryText: Color) = buildAnnotatedString {
    row.titlePieces.forEach { piece ->
        if (piece.emphasized) {
            withStyle(SpanStyle(color = primaryText)) { append(piece.text) }
        } else {
            append(piece.text)
        }
    }
}

/**
 * 关联课程折叠面板（Dart `_RelatedCoursesPanel` `:210-345`）。
 *
 * 折叠条 = 图标徽章 + 标题（冲突 N 节 / 还有 N 节…）+ 副标题（课名预览或提示）+ 展开箭头；
 * 展开后每条 = 课程色圆点 + 课名 + 角标 + `周X · 第A-B节 · HH:mm-HH:mm` + 地点 + 「切换」。
 */
@Composable
private fun RelatedCoursesPanel(
    panel: CourseActionRelatedPanel,
    expanded: Boolean,
    primaryText: Color,
    secondaryText: Color,
    destructive: Color,
    dark: Boolean,
    onToggleExpanded: () -> Unit,
    onSelect: (Int) -> Unit,
) {
    val accent = entryColor(panel.accent, destructive = destructive, courseHex = null, dark = dark)
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = ROW_INSIDE_PADDING,
        onClick = onToggleExpanded,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(RELATED_BADGE_SIZE)
                    .clip(RoundedCornerShape(RELATED_BADGE_RADIUS))
                    .background(accent.copy(alpha = RELATED_BADGE_ALPHA)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = courseActionIcon(panel.icon),
                    contentDescription = null,
                    modifier = Modifier.size(RELATED_BADGE_ICON_SIZE),
                    tint = accent,
                )
            }
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = panel.title,
                    // Dart `_RelatedCoursesPanel` 标题 `typo.sm`（14sp）→ body2。
                    style = MiuixTheme.textStyles.body2,
                    color = primaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = if (expanded) panel.expandedSubtitle else panel.subtitle,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                    maxLines = if (expanded) 2 else 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(modifier = Modifier.width(6.dp))
            Icon(
                imageVector = if (expanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = secondaryText,
            )
        }
    }
    if (!expanded) return
    Spacer(modifier = Modifier.height(8.dp))
    panel.entries.forEachIndexed { index, entry ->
        if (index > 0) Spacer(modifier = Modifier.height(8.dp))
        RelatedCourseRow(
            entry = entry,
            primaryText = primaryText,
            secondaryText = secondaryText,
            accent = entryColor(
                entry.color,
                destructive = destructive,
                courseHex = entry.colorHex,
                dark = dark,
            ),
            onTap = { onSelect(entry.previewIndex) },
        )
    }
}

/** 关联面板图标块底色的透明度（Dart `accent.withValues(alpha: 0.12)`）。 */
private const val RELATED_BADGE_ALPHA = 0.12f

/** 关联面板里的一条可切换课（Dart `_RelatedCourseCompactRow` `:375-472`）。 */
@Composable
private fun RelatedCourseRow(
    entry: CourseActionRelatedEntry,
    primaryText: Color,
    secondaryText: Color,
    accent: Color,
    onTap: () -> Unit,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = ROW_INSIDE_PADDING,
        onClick = onTap,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(RELATED_DOT_SIZE)
                    .clip(CircleShape)
                    .background(accent),
            ) {}
            Spacer(modifier = Modifier.width(ROW_ICON_GAP))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = entry.courseName,
                        // Dart `_RelatedCourseCompactRow` 课名 `typo.sm`（14sp）→ body2。
                        style = MiuixTheme.textStyles.body2,
                        color = primaryText,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    entry.badgeText?.let {
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(text = it, style = MiuixTheme.textStyles.footnote2, color = accent)
                    }
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = entry.scheduleLine,
                    style = MiuixTheme.textStyles.footnote2,
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                entry.location?.let {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = it,
                        style = MiuixTheme.textStyles.footnote2,
                        color = secondaryText,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = entry.switchLabel,
                style = MiuixTheme.textStyles.footnote2,
                color = accent,
            )
        }
    }
}

/**
 * 关联面板里一条的颜色（Dart `_previewItemColor` `:474-489`）：
 * 情侣课 → 情侣色（Compose 侧暂无数据，回落强调色），冲突课 → 危险色，其余 → 课程色。
 */
private fun entryColor(
    color: CourseActionEntryColor,
    destructive: Color,
    courseHex: String?,
    dark: Boolean,
): Color = when (color) {
    CourseActionEntryColor.CONFLICT -> destructive
    // 情侣色在 Dart 来自 `TimetableProvider.coupleColorForKind`；Compose 周视图还没有
    // 情侣叠加层（audit §五），没有可信色源时用主题强调色，不伪造一个情侣色。
    CourseActionEntryColor.COUPLE -> Color(QingyuTheme.primary(dark = dark))
    CourseActionEntryColor.COURSE -> parseHexColorOrFallback(
        hex = courseHex,
        fallback = Color(QingyuTheme.primary(dark = dark)),
    )
}

/**
 * 动作区（Dart `:871-917`）：编辑整宽主按钮 + 第二排「调课 / 停课·恢复 / 删除」。
 *
 * 只读课整块不渲染（由模型 `showActions` 决定，调用点已判）；调课在本周没课时置灰。
 *
 * ## 三处配色/尺寸必须按 Dart，不能用 miuix 默认值
 *
 * | 按钮 | Dart | miuix 默认（错的） | 这里 |
 * |---|---|---|---|
 * | 编辑 | `HyperosButton`，**primary 变体**（强调色实心） | `buttonColors()` = `secondaryVariant` 灰 | [ButtonDefaults.buttonColorsPrimary] |
 * | 删除 | `HyperosFrostedSheetButton(variant = destructive)`：**红字 + 淡红水洗底**（`fg=error`、`tint=error` 亮 α.10 / 暗 α.14，`hyperos_controls.dart:846-854`；tint 即面板填充色，`frosted_header_background.dart:172-174`） | `textButtonColors(color = 错误色)` = 整颗饱和红底 + 灰字（对比度坏） | `textButtonColors(color = 淡红水洗、textColor = 危险色)`（`color` 必须给，否则是中性的 `secondaryVariant` 底） |
 * | 三个次按钮 | 等宽 `Expanded` + 8dp 间距 | 同上 | 同 miuix 默认（58/40/16 与 Dart `HyperosMiuixButton` 逐值一致） |
 */
@Composable
private fun CourseActionButtons(
    section: CourseActionSection,
    destructive: Color,
    dark: Boolean,
    onEdit: () -> Unit,
    onReschedule: () -> Unit,
    onSuspend: () -> Unit,
    onDelete: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Button(
            onClick = onEdit,
            modifier = Modifier.fillMaxWidth(),
            // 主操作是**强调色实心**（Dart `HyperosButtonVariant.primary`）。
            // 用默认 `buttonColors()` 会得到 grey secondary 底 —— 主按钮读起来像禁用。
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) {
            Text(text = CourseActionStrings.courseActionEditPrimary.text)
        }
        Spacer(modifier = Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = CourseActionStrings.courseActionRescheduleSecondary.text,
                enabled = section.canReschedule,
                onClick = onReschedule,
            )
            TextButton(
                modifier = Modifier.weight(1f),
                text = CourseActionStrings.suspendButtonLabel(section.isSuspendedThisWeek),
                onClick = onSuspend,
            )
            TextButton(
                modifier = Modifier.weight(1f),
                text = CourseActionStrings.courseActionDeleteSecondary.text,
                // 发布版 destructive 磨砂钮 = 红字 + **淡红水洗底**（`hyperos_controls.dart:846-854`：
                // `fg = error`、`tint = error @ 亮 .10 / 暗 .14`；tint 就是面板填充色，
                // 见 `frosted_header_background.dart:172-174`）。只染字会得到中性的 secondaryVariant
                // 底，跟发布版那层淡红不是一回事；`color` 也不要给成饱和错误色（会变整颗红底）。
                colors = ButtonDefaults.textButtonColors(
                    color = destructive.copy(alpha = if (dark) 0.14f else 0.10f),
                    disabledColor = destructive.copy(alpha = 0.06f),
                    textColor = destructive,
                    disabledTextColor = destructive.copy(alpha = 0.45f),
                ),
                onClick = onDelete,
            )
        }
    }
}


/**
 * 课程操作弹层预览：在 Android Studio 里直接看这个弹层的真实长相（用户点名要）。
 *
 * 样例课复用加课页预览那门满字段课（教师 / 地点 / 简介都在），描述走真模型
 * `buildPreviewItems` → `build`，**不是手摆的假数据**；预览里看到的就是真机同一套几何。
 * 样例课直接引用 `previewAddCourseInitial`（已提为 internal），**不新增任何中文字符串字面量**
 * ——CJK 棘轮按文件计字符串字面量，函数名与注释都不计入；所以这档不碰基线。
 */
@Preview(showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewCourseActionSheet() {
    val course = previewAddCourseInitial
    val items = remember(course) {
        CourseActionSheetModel.buildPreviewItems(courses = listOf(course), primary = course, week = 3)
    }
    val details = remember(items) { CourseActionSheetModel.build(previewItems = items, week = 3) }
    CourseActionSheet(
        course = course,
        week = 3,
        previewItems = items,
        details = details,
        onEvent = {},
        onAlarmEvent = {},
        onDismiss = {},
    )
}
