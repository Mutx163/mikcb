package com.mutx163.qingyu.pages.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuColorChip
import com.mutx163.qingyu.components.QingyuColorChipSize
import com.mutx163.qingyu.components.QingyuColorPickerDialog
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.task.TaskStrings
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronBackward
import top.yukonga.miuix.kmp.theme.MiuixTheme
import androidx.compose.foundation.layout.imePadding
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.icon.extended.Theme
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import java.time.LocalDate
import java.time.YearMonth
import kotlinx.coroutines.launch

private val kColorPalette = listOf(
    "#6366F1", "#0EA5E9", "#2196F3", "#8B5CF6", "#D946EF",
    "#F97316", "#22C55E", "#14B8A6", "#EF4444", "#F59E0B",
)

/**
 * 新增/编辑日程页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/add_schedule_item_screen.dart`：
 * 快捷模板横条 + 启用开关 + 标题/地点/备注 + 起止日期时间 + 颜色选择 + 重复频率 + 提醒设置。
 */
@Composable
fun AddScheduleItemPage(
    scheduleItem: ScheduleItemData? = null,
    initialDate: String = "2026-10-27",
    occurrenceDate: String? = null,
    onBack: () -> Unit,
    onSave: (ScheduleItemData, applyToAll: Boolean?) -> Unit,
    onDelete: (ScheduleItemData, applyToAll: Boolean?) -> Unit = { _, _ -> },
    /** 选了提醒档位且通知权限不可用时为 true：提醒卡片下显示「检查通知权限」行动作与缺失说明。 */
    reminderPermissionMissing: Boolean = false,
    /** 点击「检查通知权限」行动作（null = 不显示行动作行）。 */
    onRequestNotificationPermission: (() -> Unit)? = null,
    /** 用户点了某个提醒档位（含「关」）；宿主据此刷新权限状态（对齐旧版选择时刷新）。 */
    onReminderSelected: ((Int?) -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    val isEditing = scheduleItem != null
    val isOccurrenceEditing = occurrenceDate != null && (scheduleItem?.isRecurring == true || scheduleItem?.seriesId != null)

    var title by remember { mutableStateOf(scheduleItem?.title ?: "") }
    var location by remember { mutableStateOf(scheduleItem?.location ?: "") }
    var note by remember { mutableStateOf(scheduleItem?.note ?: "") }
    var startDate by remember { mutableStateOf(scheduleItem?.startDate ?: initialDate) }
    var endDate by remember { mutableStateOf(scheduleItem?.endDate ?: initialDate) }
    var startTime by remember { mutableStateOf(scheduleItem?.startTime ?: "09:00") }
    var endTime by remember { mutableStateOf(scheduleItem?.endTime ?: "10:00") }
    var selectedColor by remember { mutableStateOf(scheduleItem?.color ?: kColorPalette.first()) }
    var recurrence by remember { mutableStateOf(scheduleItem?.recurrence ?: ScheduleRecurrence.NONE) }
    var reminderMinutes by remember { mutableStateOf(scheduleItem?.reminderMinutesBefore) }
    var enabled by remember { mutableStateOf(scheduleItem?.enabled ?: true) }
    var appliedPresetId by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var showOccurrenceScopeDialog by remember { mutableStateOf(false) }
    var pendingActionIsDelete by remember { mutableStateOf(false) }
    // 一次性删除的二次确认（Dart `_confirmDelete:961-1019`：标题 + 消息 + 破坏性确认）。
    // 重复日程走下面的「本次 / 全部」范围框，不叠这一层。
    var showDeleteConfirmDialog by remember { mutableStateOf(false) }

    // 日期/时间滚轮弹层：正在选「哪一端」（对应 Dart `_pickDate` / `_pickTime` 的 isStart）。
    var pickingDate by remember { mutableStateOf<ScheduleEndpoint?>(null) }
    var pickingTime by remember { mutableStateOf<ScheduleEndpoint?>(null) }
    // 行尾调色盘入口点开的官方取色弹窗（常驻组合，显隐只由它驱动）。
    var colorPickerOpen by remember { mutableStateOf(false) }
    // Dart 打开滚轮前先收键盘（add_schedule_item_screen.dart:749-751）：
    // 弹层里没有文本框，不收的话键盘会顶在弹层底下。
    val focusManager = LocalFocusManager.current

    // 校验失败必须「看得见」：错误横幅是列表第一项，用户滚在表单底部点顶栏保存时它在屏幕外，
    // 表现成「点了没反应」。miuix 的 `TextField` 没有 error 槽位（不自绘），所以不动横幅本身、
    // 只把列表带回顶部——不加 UI、不改文案，效果等同发布版「必须给出一条可见反馈」。
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    fun revealValidationError(message: String) {
        errorMessage = message
        scope.launch { listState.animateScrollToItem(0) }
    }

    fun validateAndProceed(isDeleting: Boolean) {
        if (isDeleting) {
            if (isOccurrenceEditing) {
                pendingActionIsDelete = true
                showOccurrenceScopeDialog = true
            } else if (scheduleItem != null) {
                // 一次性删除先问一句再删；发布版同样是确认框（Dart `_confirmDelete`）。
                showDeleteConfirmDialog = true
            }
            return
        }

        val trimmedTitle = title.trim()
        if (trimmedTitle.isEmpty()) {
            revealValidationError(ScheduleStrings.scheduleTitleRequired.text)
            return
        }
        if (startDate == endDate) {
            val startMin = ScheduleDateUtils.parseMinutes(startTime)
            val endMin = ScheduleDateUtils.parseMinutes(endTime)
            if (endMin <= startMin) {
                revealValidationError(ScheduleStrings.scheduleTimeRangeInvalid.text)
                return
            }
        }
        if (endDate < startDate) {
            revealValidationError(ScheduleStrings.scheduleDateRangeInvalid.text)
            return
        }

        errorMessage = null

        val draft = ScheduleItemData(
            id = scheduleItem?.id ?: "draft_${System.currentTimeMillis()}",
            title = trimmedTitle,
            location = location.trim().ifEmpty { null },
            note = note.trim().ifEmpty { null },
            startDate = startDate,
            endDate = endDate,
            startTime = startTime,
            endTime = endTime,
            color = selectedColor,
            recurrence = recurrence,
            reminderMinutesBefore = reminderMinutes,
            enabled = enabled,
            seriesId = scheduleItem?.seriesId,
            // 只有「正在编辑某一次发生」才把发生日交给宿主。壳按 `draft.occurrenceDate != null`
            // 判「单次编辑」，无条件带上会让**跨天 / 单日的单次日程**被分派成 `updateOccurrence`
            // ——它会造一条只继承不到列表里的覆盖行，并给原条目打 exception，
            // 用户看到的是「整段日期只改了一天」（发布版只在范围框分支里带 occurrenceDate）。
            occurrenceDate = occurrenceDate.takeIf { isOccurrenceEditing },
        )

        if (isOccurrenceEditing) {
            pendingActionIsDelete = false
            showOccurrenceScopeDialog = true
        } else {
            onSave(draft, null)
        }
    }

    // 顶栏折叠行为：Dart 侧 add_schedule_item_screen.dart:167 走 HyperosSubpage 默认参数
    //（overlayHeader / collapsibleLargeTitle 均 true）。
    val scrollBehavior = MiuixScrollBehavior()
    val pageTitle = if (isEditing) {
        ScheduleStrings.editScheduleTitle.text
    } else {
        ScheduleStrings.addScheduleTitle.text
    }

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，
            // 放进槽位后 Scaffold 不再重复给一份（第一版手搓 Row 时算了两遍）。
            topBar = {
                TopAppBar(
                    title = pageTitle,
                    largeTitle = pageTitle,
                    scrollBehavior = scrollBehavior,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.ChevronBackward,
                                contentDescription = ScheduleStrings.cancelAction.text,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    // Dart 侧右侧是图标：编辑态 delete_outline_rounded + check_rounded。
                    // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
                    actions = {
                        if (isEditing) {
                            QingyuGlassIconButton(
                                onClick = { validateAndProceed(isDeleting = true) },
                                contentDescription = ScheduleStrings.deleteAction.text,
                                icon = MiuixIcons.Delete,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                        QingyuGlassIconButton(
                            onClick = { validateAndProceed(isDeleting = false) },
                            contentDescription = ScheduleStrings.saveAction.text,
                            icon = MiuixIcons.Ok,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    // 表单页必须避让键盘，否则底部输入框被 IME 盖住。
                    .imePadding()
                    // 只吃顶部：底部手势条交给列表的 contentPadding 显式算一次
                    //（QingyuPageList 内部还会再加一次 innerPadding 的 bottom，
                    // 两份都给就会把小白条算两遍）。
                    .padding(top = innerPadding.calculateTopPadding()),
            ) {
            // 2026-10-28：这里原来还留着一版「手搓顶栏」Row（返回图标 + 标题 + 删除/保存按钮），
            // 是顶栏挪进 Scaffold 槽位之前的旧代码——结果标题和按钮在屏幕上出现两遍。
            // 顶栏现在只有 Scaffold 的 topBar 槽那一处。

            // ── 滚动表单 ──
            // 主滚动统一走共享套件（R2）：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
            // 与右侧滚动条；卡片间距由列表的 verticalArrangement 承担。
            // 横向留白按配方由每张卡自己带 QingyuPageCardMargin(12dp)，不放进 contentPadding。
            QingyuPageList(
                innerPadding = PaddingValues(0.dp),
                // 校验失败要把横幅（列表第一项）带进视野，所以列表状态由本页持有。
                state = listState,
                scrollBehavior = scrollBehavior,
                contentPadding = PaddingValues(
                    top = 8.dp,
                    // 底部把系统手势条那段算进去，否则最后一项钻到小白条底下。
                    bottom = innerPadding.calculateBottomPadding() + 8.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // 校验错误横幅
                errorMessage?.let { error ->
                    item(key = "error") {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                            insideMargin = PaddingValues(12.dp),
                        ) {
                            Text(
                                text = error,
                                color = Color(QingyuTheme.error(dark)),
                                style = MiuixTheme.textStyles.body2,
                            )
                        }
                    }
                }

                // 快捷模板选择区（新建 / 编辑都展示：有意保留的超出发布版能力——发布版无模板概念；
                // 模板只回填标题 / 颜色 / 起止时刻，不改日程本身的存在性与重复规则）。
                item(key = "presets") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(12.dp),
                    ) {
                        Column {
                            Text(
                                text = ScheduleStrings.scheduleQuickPresetSectionTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                                modifier = Modifier.padding(bottom = 8.dp),
                            )
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                val activePreset = scheduleQuickPresetActiveId(appliedPresetId, title)
                                for (preset in kScheduleQuickPresets) {
                                    val isSelected = activePreset == preset.id
                                    val presetTitle = scheduleQuickPresetTitle(preset.id)
                                    val chipBg = if (isSelected) {
                                        Color(QingyuTheme.primary(dark = dark))
                                    } else {
                                        Color(QingyuTheme.card(dark))
                                    }
                                    val chipText = if (isSelected) {
                                        Color.White
                                    } else {
                                        Color(QingyuTheme.primaryText(dark))
                                    }

                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(chipBg)
                                            .border(
                                                1.dp,
                                                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                                                RoundedCornerShape(8.dp),
                                            )
                                            .clickable {
                                                if (isSelected) {
                                                    appliedPresetId = null
                                                    // 编辑态取消选中时**不许清用户已填标题**：只有标题仍是这个模板名
                                                    // （= 没被用户改过）才清空；用户手写的标题原样保留。
                                                    if (title == presetTitle) {
                                                        title = ""
                                                    }
                                                } else {
                                                    appliedPresetId = preset.id
                                                    title = presetTitle
                                                    selectedColor = preset.colorHex
                                                    val win = resolveSchedulePresetWindow(
                                                        ScheduleDateUtils.parseMinutes(startTime),
                                                        preset.durationMinutes,
                                                    )
                                                    startTime = ScheduleDateUtils.formatMinutes(win.startMinutes)
                                                    endTime = ScheduleDateUtils.formatMinutes(win.endMinutes)
                                                }
                                            }
                                            .padding(horizontal = 12.dp, vertical = 8.dp),
                                    ) {
                                        Text(text = presetTitle, style = MiuixTheme.textStyles.footnote1, color = chipText)
                                    }
                                }
                            }
                        }
                    }
                }

                // 启用开关卡片
                item(key = "enabled") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(0.dp),
                    ) {
                        // 对齐 Dart `add_schedule_item_screen.dart:468-478` 的 `HyperosSwitchTile`：
                        // 标题 +（关时）副标题 + 右侧开关，整行可点。
                        //
                        // 2026-10-29 修（审核 misc-wiring P1-6）：这里原来是「文字 + 一颗会变字的按钮」，
                        // 按钮文案 `已启用` / `已暂停` 是**渲染层写死的中文**，ARB 里根本没有这两个词；
                        // 且 Dart 是开关、Compose 是按钮 ⇒ 同一功能两岸长得不一样。
                        // 现改回官方 `SwitchPreference`，文案全部来自
                        // `ScheduleStrings.scheduleEnabledTitle` / `scheduleDisabledSubtitle`。
                        SwitchPreference(
                            title = ScheduleStrings.scheduleEnabledTitle.text,
                            summary = if (enabled) null else ScheduleStrings.scheduleDisabledSubtitle.text,
                            checked = enabled,
                            onCheckedChange = { enabled = it },
                        )
                    }
                }

                // 日程信息卡片
                item(key = "info") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleInfoSectionTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            TextField(
                                value = title,
                                onValueChange = { title = it },
                                label = ScheduleStrings.scheduleTitleLabel.text,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            TextField(
                                value = location,
                                onValueChange = { location = it },
                                label = ScheduleStrings.scheduleLocationLabel.text,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            TextField(
                                value = note,
                                onValueChange = { note = it },
                                label = ScheduleStrings.scheduleNoteLabel.text,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }

                // 时间安排与起止设置
                item(key = "time") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleTimeSectionTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )

                            // 起止日期/时间：四行「标签 → 取值」选值行，点行弹滚轮
                            //（Dart `add_schedule_item_screen.dart:331/338` 的 `HyperosPickerField`
                            // + `showMiuixDatePickerSheet` / `showMiuixTimePickerSheet`）。
                            // 原来是四个自由文本框：用户得手输 `2026-10-01` 这种格式，
                            // 还可能输进解析不出来的值。滚轮弹层见本文件底部。
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleStartDateLabel.text,
                                value = formatScheduleDateDisplay(startDate),
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingDate = ScheduleEndpoint.Start
                                },
                            )
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleStartTimeLabel.text,
                                value = startTime,
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingTime = ScheduleEndpoint.Start
                                },
                            )
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleEndDateLabel.text,
                                value = formatScheduleDateDisplay(endDate),
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingDate = ScheduleEndpoint.End
                                },
                            )
                            SchedulePickerField(
                                label = ScheduleStrings.scheduleEndTimeLabel.text,
                                value = endTime,
                                onClick = {
                                    focusManager.clearFocus()
                                    pickingTime = ScheduleEndpoint.End
                                },
                            )

                            // 跨天或重复提示
                            if (recurrence == ScheduleRecurrence.WEEKLY) {
                                Text(
                                    text = ScheduleStrings.scheduleRepeatWeeklyHint.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            } else if (recurrence == ScheduleRecurrence.DAILY) {
                                Text(
                                    text = ScheduleStrings.scheduleRepeatEndDateHint.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            } else if (endDate > startDate) {
                                Text(
                                    text = ScheduleStrings.scheduleCrossDaySpanHint
                                        .filled("start" to "$startDate $startTime", "end" to "$endDate $endTime"),
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }

                            HorizontalDivider(modifier = Modifier.fillMaxWidth())

                            // 颜色快捷行 + 行尾调色盘（发布版形态）
                            Text(
                                text = ScheduleStrings.scheduleAppearanceSectionTitle.text,
                                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            // 发布版 v2.1.4.1 `_buildColorPalette`：32dp 方块 + 8dp 间距的横向滚动
                            // 快捷行，末尾一颗调色盘入口（点开全色取色）。尺寸/圆角/勾都走共享
                            // `QingyuColorChipSize.QuickRow`，不在这里另起一套色块画法。
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                for (hex in kColorPalette) {
                                    QingyuColorChip(
                                        hex = hex,
                                        selected = selectedColor.equals(hex, ignoreCase = true),
                                        onSelect = { selectedColor = it },
                                        dark = dark,
                                        size = QingyuColorChipSize.QuickRow,
                                        showShadow = false,
                                    )
                                }
                                Spacer(modifier = Modifier.width(2.dp))
                                // 行尾调色盘入口：发布版同一颗 32dp 方块（`_buildPaletteSwatch(colorHex = null)`），
                                // 按压面用官方 IconButton（同色块那一套）；图标取语义最近的官方
                                // `MiuixIcons.Theme`（miuix 0.9.4 没有 palette 图标）。
                                IconButton(
                                    onClick = { colorPickerOpen = true },
                                    modifier = Modifier.border(
                                        width = 1.dp,
                                        color = Color(QingyuTheme.outline(dark)),
                                        shape = RoundedCornerShape(8.dp),
                                    ),
                                    backgroundColor = Color(QingyuTheme.surfaceContainer(dark)),
                                    cornerRadius = 8.dp,
                                    minWidth = 32.dp,
                                    minHeight = 32.dp,
                                ) {
                                    Icon(
                                        imageVector = MiuixIcons.Theme,
                                        contentDescription = ScheduleStrings.customPaletteAction.text,
                                        tint = Color(QingyuTheme.secondaryText(dark)),
                                        modifier = Modifier.size(16.dp),
                                    )
                                }
                            }
                        }
                    }
                }

                // 重复规则设置卡片
                item(key = "recurrence") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleRepeatSectionTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                val options = listOf(
                                    ScheduleRecurrence.NONE to ScheduleStrings.scheduleRepeatNone.text,
                                    ScheduleRecurrence.DAILY to ScheduleStrings.scheduleRepeatDaily.text,
                                    ScheduleRecurrence.WEEKLY to ScheduleStrings.scheduleRepeatWeekly.text,
                                )
                                for ((rec, label) in options) {
                                    val isSelected = recurrence == rec
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) {
                                                    Color(QingyuTheme.primary(dark = dark))
                                                } else {
                                                    Color(QingyuTheme.card(dark))
                                                },
                                            )
                                            .border(
                                                1.dp,
                                                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                                                RoundedCornerShape(8.dp),
                                            )
                                            .clickable {
                                                recurrence = rec
                                                if (recurrence != ScheduleRecurrence.NONE && endDate < startDate) {
                                                    endDate = startDate
                                                }
                                            }
                                            .padding(vertical = 10.dp),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text(
                                            text = label,
                                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                                            color = if (isSelected) Color.White else Color(QingyuTheme.primaryText(dark)),
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // 提醒时间设置卡片
                item(key = "reminder") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = ScheduleStrings.scheduleReminderSectionTitle.text,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                // 与 QingyuTheme.sectionLabel(dark) 在主题桥里同值，走语义槽取色（R5/R6）。
                                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
                            )
                            val reminderChoices = listOf(
                                null to ScheduleStrings.scheduleReminderOff.text,
                                5 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "5"),
                                10 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "10"),
                                15 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "15"),
                                30 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "30"),
                                60 to ScheduleStrings.scheduleReminderMinutes.filled("minutes", "60"),
                            )
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                for ((mins, label) in reminderChoices) {
                                    val isSelected = reminderMinutes == mins
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) {
                                                    Color(QingyuTheme.primary(dark = dark))
                                                } else {
                                                    Color(QingyuTheme.card(dark))
                                                },
                                            )
                                            .border(
                                                1.dp,
                                                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                                                RoundedCornerShape(8.dp),
                                            )
                                            .clickable {
                                                reminderMinutes = mins
                                                onReminderSelected?.invoke(mins)
                                            }
                                            .padding(horizontal = 12.dp, vertical = 8.dp),
                                    ) {
                                        Text(
                                            text = label,
                                            style = MiuixTheme.textStyles.footnote1,
                                            color = if (isSelected) Color.White else Color(QingyuTheme.primaryText(dark)),
                                        )
                                    }
                                }
                            }
                            // 通知权限不可用：行动作 + 缺失说明（对齐旧版
                            // add_schedule_item_screen.dart:552-570——选了提醒档位才出现，
                            // 点行动作弹系统框/跳通知设置；文案沿用既有键，零新增）。
                            if (reminderMinutes != null && reminderPermissionMissing && onRequestNotificationPermission != null) {
                                Spacer(modifier = Modifier.height(2.dp))
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(Color(QingyuTheme.card(dark)))
                                        .clickable(onClick = onRequestNotificationPermission)
                                        .padding(horizontal = 12.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = ScheduleStrings.scheduleReminderPermissionAction.text,
                                        style = MiuixTheme.textStyles.body2
                                            .shiftWeight(QingyuWeightDelta.MEDIUM),
                                        color = MiuixTheme.colorScheme.primary,
                                    )
                                }
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = ScheduleStrings.scheduleReminderPermissionMissing.text,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // 重复日程修改/删除范围确认弹框。
    //
    // 原来是一张裸 QingyuCard：没有遮罩、点外部不关、返回键会把整个编辑页退掉
    //（未保存内容一起丢）。现改官方 OverlayDialog 并交给 `show` 驱动：
    // 返回键 / 点外部只关弹窗，不再退页。
    val scopeTitleText = if (pendingActionIsDelete) {
        ScheduleStrings.scheduleDeleteScopeTitle.text
    } else {
        ScheduleStrings.scheduleEditScopeTitle.text
    }
    val thisActionText = if (pendingActionIsDelete) {
        ScheduleStrings.scheduleDeleteScopeThis.text
    } else {
        ScheduleStrings.scheduleEditScopeThis.text
    }
    val allActionText = if (pendingActionIsDelete) {
        ScheduleStrings.scheduleDeleteScopeAll.text
    } else {
        ScheduleStrings.scheduleEditScopeAll.text
    }

    OverlayDialog(
        show = showOccurrenceScopeDialog,
        title = scopeTitleText,
        // 发布版 `_chooseOccurrenceScope`（`add_schedule_item_screen.dart:824-849`）只给**编辑**
        // 范围框带 `scheduleOccurrenceEditHint`，删除范围框的 message 是 null——同一句
        // 「你正在编辑…」摆在删除框里是错话。这里改走官方 summary 槽：居中、次要色，
        // 与发布版 HyperosDialog 的版式一致（原来是一段左对齐 body2 顶在按钮上方）。
        summary = if (pendingActionIsDelete) null else ScheduleStrings.scheduleOccurrenceEditHint.text,
        onDismissRequest = { showOccurrenceScopeDialog = false },
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        // 发布版只把第二个动作设成 `isPrimary`（「全部」），「本次」是次要的灰底按钮；
        // 原来两颗都是主色实心，主次不分。
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ScheduleActionButton(
                text = thisActionText,
                onClick = {
                    showOccurrenceScopeDialog = false
                    val draft = ScheduleItemData(
                        id = scheduleItem?.id ?: "",
                        title = title.trim(),
                        location = location.trim().ifEmpty { null },
                        note = note.trim().ifEmpty { null },
                        startDate = startDate,
                        endDate = endDate,
                        startTime = startTime,
                        endTime = endTime,
                        color = selectedColor,
                        recurrence = recurrence,
                        reminderMinutesBefore = reminderMinutes,
                        enabled = enabled,
                        seriesId = scheduleItem?.seriesId,
                        occurrenceDate = occurrenceDate,
                    )
                    if (pendingActionIsDelete) {
                        onDelete(draft, false)
                    } else {
                        onSave(draft, false)
                    }
                },
                modifier = Modifier.weight(1f),
            )
            ScheduleActionButton(
                text = allActionText,
                onClick = {
                    showOccurrenceScopeDialog = false
                    val draft = ScheduleItemData(
                        id = scheduleItem?.id ?: "",
                        title = title.trim(),
                        location = location.trim().ifEmpty { null },
                        note = note.trim().ifEmpty { null },
                        startDate = startDate,
                        endDate = endDate,
                        startTime = startTime,
                        endTime = endTime,
                        color = selectedColor,
                        recurrence = recurrence,
                        reminderMinutesBefore = reminderMinutes,
                        enabled = enabled,
                        seriesId = scheduleItem?.seriesId,
                        occurrenceDate = occurrenceDate,
                    )
                    if (pendingActionIsDelete) {
                        onDelete(draft, true)
                    } else {
                        onSave(draft, true)
                    }
                },
                modifier = Modifier.weight(1f),
                primary = true,
            )
        }
    }

    // 一次性（非重复）条目的删除确认：官方 `OverlayDialog` + 现成文案键（与日程列表页
    // `ScheduleListPage.kt:219-220` 同一对），确认键走破坏性红色。
    // 发布版此前就是这么问的（Dart `_confirmDelete:1008-1019` → `showHyperosConfirmDialog`），
    // 之前这里直接 `onDelete` ⇒ 误触顶栏垃圾桶就把数据删了，且没有任何撤销途径。
    val deleteConfirmTarget = scheduleItem
    OverlayDialog(
        show = showDeleteConfirmDialog,
        title = ScheduleStrings.deleteScheduleTitle.text,
        summary = deleteConfirmTarget?.let {
            ScheduleStrings.deleteScheduleMessage.filled("title", it.title)
        },
        onDismissRequest = { showDeleteConfirmDialog = false },
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        if (deleteConfirmTarget != null) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 取消与删除用同一颗按钮组件（灰底 / 破坏性红），两颗等宽等字阶；
                // 原来取消是 TextButton（button 17sp）、删除是 ScheduleActionButton
                // （body1 16sp），同一排放着两套字阶，肉眼能看出不齐。
                ScheduleActionButton(
                    text = ScheduleStrings.cancelAction.text,
                    onClick = { showDeleteConfirmDialog = false },
                    modifier = Modifier.weight(1f),
                )
                ScheduleActionButton(
                    text = ScheduleStrings.deleteAction.text,
                    onClick = {
                        showDeleteConfirmDialog = false
                        onDelete(deleteConfirmTarget, null)
                    },
                    modifier = Modifier.weight(1f),
                    destructive = true,
                )
            }
        }
    }

    // 选色弹窗：常驻组合、显隐只由 `show` 驱动（退场动画才播得出来）；
    // 确认才写回 selectedColor，取消不产生任何写入。
    QingyuColorPickerDialog(
        show = colorPickerOpen,
        initialHex = selectedColor,
        title = ScheduleStrings.colorPaletteTitle.text,
        cancelLabel = ScheduleStrings.cancelAction.text,
        confirmLabel = TaskStrings.confirmAction,
        dark = dark,
        onDismiss = { colorPickerOpen = false },
        onConfirm = { hex ->
            selectedColor = hex
            colorPickerOpen = false
        },
    )

    // 起止日期滚轮（年/月/日三列官方 NumberPicker）。选完按 Dart `_pickDate` 归一：
    // 开始 > 结束时把另一端收拢，保证「结束不早于开始」。
    ScheduleDatePickerSheet(
        show = pickingDate != null,
        title = if (pickingDate == ScheduleEndpoint.End) {
            ScheduleStrings.scheduleEndDateLabel.text
        } else {
            ScheduleStrings.scheduleStartDateLabel.text
        },
        initialIso = if (pickingDate == ScheduleEndpoint.End) endDate else startDate,
        onConfirm = { iso ->
            when (pickingDate) {
                ScheduleEndpoint.Start -> {
                    startDate = iso
                    if (endDate < startDate) endDate = startDate
                }
                ScheduleEndpoint.End -> {
                    endDate = iso
                    if (endDate < startDate) startDate = endDate
                }
                null -> {}
            }
            pickingDate = null
        },
        onDismiss = { pickingDate = null },
    )

    // 起止时间滚轮（时/分两列官方 NumberPicker），标题与 Dart `_pickTime` 传的同键。
    ScheduleTimePickerSheet(
        show = pickingTime != null,
        title = if (pickingTime == ScheduleEndpoint.End) {
            ScheduleStrings.selectEndTimeTitle.text
        } else {
            ScheduleStrings.selectStartTimeTitle.text
        },
        initial = if (pickingTime == ScheduleEndpoint.End) endTime else startTime,
        onConfirm = { clock ->
            when (pickingTime) {
                ScheduleEndpoint.Start -> startTime = clock
                ScheduleEndpoint.End -> endTime = clock
                null -> {}
            }
            pickingTime = null
        },
        onDismiss = { pickingTime = null },
    )
    }
}

/** 滚轮正在选起止的哪一端（对应 Dart `_pickDate` / `_pickTime` 的 `isStart` 参数）。 */
private enum class ScheduleEndpoint { Start, End }

/** 日期滚轮可选范围：与 Dart `add_schedule_item_screen.dart:755-756` 的 firstDate/lastDate 同口径。 */
private const val SCHEDULE_DATE_FIRST_YEAR = 2020
private const val SCHEDULE_DATE_LAST_YEAR = 2100

/**
 * 日期/时间选值行：Dart `HyperosPickerField` 的等价物。
 *
 * 用官方 `BasicComponent`（标题 + 行尾取值 + 整行可点 + 官方按压反馈）承载，
 * 与 `SettingsHolidayHost.DatePickerField` / `TimeSchemeQuickGenerateSheet.TimeField` 同一先例。
 * 与 Dart 的差异只有外观：Dart 是一个「像输入框」的选值框（带图标），
 * 这里是一行「标签 → 取值」——点哪儿、点了会弹什么，两者一致。
 */
@Composable
private fun SchedulePickerField(label: String, value: String, onClick: () -> Unit) {
    BasicComponent(
        title = label,
        endActions = {
            Text(
                text = value,
                style = MiuixTheme.textStyles.body2,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        onClick = onClick,
    )
}

/**
 * 起止日期滚轮弹层：年 / 月 / 日三列官方 `NumberPicker` + 取消 / 确认。
 *
 * Dart 侧是月历弹层（`showMiuixDatePickerSheet`），Kotlin 侧 miuix 0.9.4 没有
 * DatePicker，只有 `NumberPicker`——沿用 `SettingsSemesterHost` 的既定等价做法
 * （三列滚轮，交互结果一致）。年不循环、月/日循环；年/月改动后「日」的上界跟着
 * 变并就地收拢，避免确认写进一个不存在的日期（Dart `_YearMonthWheelDialog` 同口径）。
 *
 * 滚轮样式逐条照发布版那张年月日卡片：高 180dp、`title3`（w400）、每列文案「N年/N月/N日」、
 * 取消 = 次要灰底 + 确认 = 主色实心、间距 12dp。两处刻意不同：
 * - 发布版先弹月历，点标题才叠出这张滚轮卡；miuix 0.9.4 Kotlin 没有月历组件，这里直接出滚轮
 *   （`SettingsSemesterHost` 同款等价做法）；
 * - 标题用字段自己的「开始日期 / 结束日期」：发布版 `showMiuixDatePickerSheet` 调用没传
 *   title，弹出来写的是默认值「开学日期」——那是发布版的一处串台，不复制。
 */
@Composable
private fun ScheduleDatePickerSheet(
    show: Boolean,
    title: String,
    initialIso: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val initial = remember(initialIso) {
        ScheduleDateUtils.parseDate(initialIso) ?: LocalDate.now()
    }
    var year by remember(show, initialIso) { mutableIntStateOf(initial.year) }
    var month by remember(show, initialIso) { mutableIntStateOf(initial.monthValue) }
    var day by remember(show, initialIso) { mutableIntStateOf(initial.dayOfMonth) }

    val maxDay = YearMonth.of(year, month).lengthOfMonth()
    val safeDay = day.coerceAtMost(maxDay)

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 内容根 Column 自己给了左右 16（三列滚轮 + 按钮行都不通栏）⇒ 框架侧横向归零，
        // 单边就是 16，不再叠成 32（与 SettingsSemesterHost 的日期滚轮同口径）。
        contentPadsHorizontally = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = year,
                    onValueChange = {
                        year = it
                        day = day.coerceAtMost(YearMonth.of(it, month).lengthOfMonth())
                    },
                    range = SCHEDULE_DATE_FIRST_YEAR..SCHEDULE_DATE_LAST_YEAR,
                    label = { "$it${TaskStrings.datePickerYear}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = month,
                    onValueChange = {
                        month = it
                        day = day.coerceAtMost(YearMonth.of(year, it).lengthOfMonth())
                    },
                    range = 1..12,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerMonth}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = safeDay,
                    onValueChange = { day = it },
                    range = 1..maxDay,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerDay}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 取消 = 次要灰底、确认 = 主色实心（发布版 `miuix_date_picker_sheet.dart`
                // 的年月日滚轮是 HyperosButton secondary + primary）。两颗都走共享按钮，
                // 字阶/高度/圆角天然一致；原来取消是 TextButton（17sp）、确认是裸 Button（16sp）。
                ScheduleActionButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.text,
                    onClick = onDismiss,
                )
                ScheduleActionButton(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        onConfirm(ScheduleDateUtils.formatDate(LocalDate.of(year, month, safeDay)))
                    },
                    text = TaskStrings.confirmAction,
                    primary = true,
                )
            }
        }
    }
}

/**
 * 起止时间滚轮弹层：时 0-23 / 分 0-59（步长 1），官方 `NumberPicker` 两列。
 *
 * 与 Dart `showMiuixTimePickerSheet`（`miuix_time_picker_sheet.dart`）同口径：
 * 分钟不分档（这个页面 Dart 就是一分钟一档，区别于作息页的 5 分钟一档）、
 * `_twoDigits` 两位数字标签、滚轮高 220dp、title3 + w600。
 */
@Composable
private fun ScheduleTimePickerSheet(
    show: Boolean,
    title: String,
    initial: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val parsedMinutes = remember(initial) { ScheduleDateUtils.parseMinutes(initial) }
    var hour by remember(show, initial) { mutableIntStateOf(parsedMinutes / 60) }
    var minute by remember(show, initial) { mutableIntStateOf(parsedMinutes % 60) }

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 与日期滚轮同一个口径（见上）。
        contentPadsHorizontally = true,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = hour,
                    onValueChange = { hour = it },
                    range = 0..23,
                    wrapAround = true,
                    label = { it.toString().padStart(2, '0') },
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = minute,
                    onValueChange = { minute = it },
                    range = 0..59,
                    wrapAround = true,
                    label = { it.toString().padStart(2, '0') },
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 与日期滚轮同一个口径（见上）：取消灰底 + 确认主色，同组件同字阶。
                ScheduleActionButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.text,
                    onClick = onDismiss,
                )
                ScheduleActionButton(
                    modifier = Modifier.weight(1f),
                    onClick = { onConfirm(ScheduleDateUtils.formatMinutes(hour * 60 + minute)) },
                    text = TaskStrings.confirmAction,
                    primary = true,
                )
            }
        }
    }
}

/**
 * 选值行里的日期显示：与 Dart `_formatCompactDateLabel`（`add_schedule_item_screen.dart:735-741`）
 * 同口径——今年内只显示「M月d日」，跨年才带年份。单位词复用 ARB 既有键
 * （`datePickerYear/Month/Day`），不新增写死文案。
 */
private fun formatScheduleDateDisplay(iso: String): String {
    val date = ScheduleDateUtils.parseDate(iso) ?: return iso
    return if (date.year == LocalDate.now().year) {
        "${date.monthValue}${TaskStrings.datePickerMonth}${date.dayOfMonth}${TaskStrings.datePickerDay}"
    } else {
        "${date.year}${TaskStrings.datePickerYear}" +
            "${date.monthValue}${TaskStrings.datePickerMonth}${date.dayOfMonth}${TaskStrings.datePickerDay}"
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 about/ContributorsPage.kt 样板铺）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 3 档：新建空表单 / 编辑已有日程 / 提醒权限缺失；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 暗色 —— 历史上出现过「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()）；这一档就是防它复发；
//   · 大字号 —— 快捷模板横条与「19:00 - 21:00」这类行内值最先被挤掉；
//   · 新建 / 编辑 —— 标题、右上动作与顶部说明两套文案，且编辑多了删除入口；
//   · 权限缺失 —— 提醒卡片下多一行「检查通知权限」，只在真机权限被拒时出现。
//
// 固定写法：主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }；
// 字号用 QingyuPageTheme(textScale = …)，不用 @Preview(fontScale = …)；
// 宽度按 400dp（本仓折行实测口径），高度给一屏多。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：编辑态打开的一条每周重复日程。 */
private fun previewScheduleItem(): ScheduleItemData = ScheduleItemData(
    id = "schedule_preview_edit",
    title = "高等数学辅导",
    location = "示例大学 · 三教 204",
    note = "带习题册，讲第 5 章",
    startDate = "2026-11-09",
    endDate = "2026-12-28",
    startTime = "19:00",
    endTime = "21:00",
    color = "#6366F1",
    recurrence = ScheduleRecurrence.WEEKLY,
    reminderMinutesBefore = 15,
    enabled = true,
)

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewAddScheduleItemPage(
    scheduleItem: ScheduleItemData? = null,
    reminderPermissionMissing: Boolean = false,
    onRequestNotificationPermission: (() -> Unit)? = null,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        AddScheduleItemPage(
            scheduleItem = scheduleItem,
            initialDate = "2026-11-09",
            onBack = {},
            onSave = { _, _ -> },
            reminderPermissionMissing = reminderPermissionMissing,
            onRequestNotificationPermission = onRequestNotificationPermission,
        )
    }
}

// ── 单档：数据三态 × 亮色 ──────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 新建空表单", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewCreate() {
    PreviewAddScheduleItemPage()
}

@Suppress("unused")
@Preview(name = "2 编辑已有日程", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewEdit() {
    PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem())
}

@Suppress("unused")
@Preview(name = "3 提醒权限缺失", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewReminderPermissionMissing() {
    PreviewAddScheduleItemPage(
        scheduleItem = previewScheduleItem(),
        reminderPermissionMissing = true,
        onRequestNotificationPermission = {},
    )
}

// ── 单档：外观两档（以「编辑已有日程」为基准）──────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewDark() {
    PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem(), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewLargeText() {
    PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem(), textScale = 1.3f)
}

/**
 * 「6 整页」：整页高度档。
 *
 * 900 那几档只画一屏，页面下半截（重复规则 / 提醒时间 / 颜色）会被画布裁掉；
 * 这一档按整页高度给画布（1300dp），AS 里等比缩小能看全页、切「实际大小」可滚。
 */
@Suppress("unused")
@Preview(name = "6 整页 1300", showBackground = true, widthDp = 400, heightDp = 1300)
@Composable
private fun AddScheduleItemPagePreviewFullPage() {
    PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem())
}

/**
 * 「7 编辑态 + 快捷模板」：编辑已有日程时**也**显示快捷模板横条。
 *
 * 有意保留的超出发布版能力（发布版 `add_schedule_item_screen.dart` 没有模板概念）：
 * 模板只回填标题 / 颜色 / 起止时刻，不改日程本身的存在性与重复规则，与编辑不冲突。
 */
@Suppress("unused")
@Preview(name = "7 编辑态 + 快捷模板", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewEditWithPresets() {
    PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem())
}

// ── 总览：三态并排，一屏看完 ─────────────────────────────────────────────────

/**
 * 一屏总览：新建 / 编辑 / 暗色 横向并排，用来一眼比结构差异。
 *
 * 3 × 400dp + 2 × 16dp 间距 = 1232dp，所以画布给 1280dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~5 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·三态并排", showBackground = true, widthDp = 1280, heightDp = 900)
@Composable
private fun AddScheduleItemPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewAddScheduleItemPage()
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem())
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewAddScheduleItemPage(scheduleItem = previewScheduleItem(), dark = true)
        }
    }
}
