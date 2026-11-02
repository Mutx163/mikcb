package com.mutx163.qingyu.pages.export

import android.app.DatePickerDialog
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.transfer.IcsExportEventKind
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.CheckboxPreference
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate

/**
 * 导出日历页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/ics_export_screen.dart`：
 * 课表下拉 → 日期范围 → 日历内容（含「跳过节假日课程」开关）→ 摘要 → 同步到系统日历
 * → 导出并分享（导出后二选一：分享给别人 / 保存到手机目录）。
 *
 * **不持业务状态**：选哪门课表、日期互相顶、摘要文本、文件名、校验提示全部来自
 * [IcsExportViewState]（模型层 `pages/export/IcsExportModel.kt`）；这里只把回调抛上去。
 */
@Composable
fun IcsExportPage(
    viewState: IcsExportViewState,
    onBack: () -> Unit,
    onSelectProfile: (String) -> Unit,
    onFromDateChange: (LocalDate) -> Unit,
    onToDateChange: (LocalDate) -> Unit,
    onToggleEventKind: (IcsExportEventKind, Boolean) -> Unit,
    onSkipHolidayCoursesChange: (Boolean) -> Unit,
    onExport: () -> Unit,
    onShareExported: () -> Unit,
    onSaveExported: () -> Unit,
    onDismissExportMenu: () -> Unit,
    onSyncCalendar: () -> Unit,
    onRemoveCalendar: () -> Unit,
    /**
     * 「同步到系统日历」的**首次说明**是否展开。
     *
     * Dart 只在第一次同步时弹这段说明（`_calendarSyncNoticePrefsKey`，确认过就不再问），
     * 之后按钮是一键直达。遮挡语义与「每次同步都弹」完全不同，所以状态放在宿主、
     * 显隐交给本页渲染。
     */
    syncNoticeVisible: Boolean,
    onConfirmSyncNotice: () -> Unit,
    onDismissSyncNotice: () -> Unit,
    /** 「移除已同步的日程」的确认弹窗。Dart 每次都要确认（删除是破坏性动作）。 */
    removeConfirmVisible: Boolean,
    onConfirmRemove: () -> Unit,
    onDismissRemoveConfirm: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val options = viewState.options
    // Dart ics_export_screen.dart 的 HyperosSubpage 标题是纯 Text ⇒ 可折叠大标题。
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        topBar = {
            TopAppBar(
                title = ExportStrings.icsExportTitle.zh,
                largeTitle = ExportStrings.icsExportTitle.zh,
                scrollBehavior = scrollBehavior,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = ExportStrings.cancelAction.zh,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        // 不手写 statusBarsPadding()：miuix Scaffold 的 contentWindowInsets
        // 默认含 systemBars 顶部，TopAppBar 自己也会加 systemBars.only(Top)，
        // 再写一次是第三次叠加，标题会下移一个多状态栏高（2026-10-27）。
        Column(modifier = Modifier.fillMaxSize()) {
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                // 官方配方：横向留白由卡片自己带（12dp），滚动条才贴得到屏幕边缘。
                horizontalPadding = QingyuPageCardMargin,
                // 顶部 8dp 与底部 24dp 是页面自己的滚动留白；手势条那段由
                // QingyuPageList 内部按 innerPadding 算，不要重复相加。
                contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // ── 1. 课表选择 ──
                item {
                    QingyuSectionTitle(ExportStrings.icsExportProfileLabel.zh)
                    // 卡里要么是 *Preference 行（自带 16dp），要么是自带 16dp 内边距的提示行，
                    // 所以**不传** insideMargin，避免叠成 32dp。
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        if (viewState.profiles.isEmpty()) {
                            Text(
                                text = ExportStrings.icsExportNoProfiles.zh,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                            )
                        } else {
                            val labels = viewState.profileItems.keys.toList()
                            val values = viewState.profileItems.values.toList()
                            val selectedIndex = values.indexOf(viewState.selectedProfileId)
                                .let { if (it < 0) 0 else it }
                            OverlayDropdownPreference(
                                items = labels,
                                selectedIndex = selectedIndex,
                                title = ExportStrings.icsExportProfileLabel.zh,
                                onSelectedIndexChange = { index ->
                                    values.getOrNull(index)?.let(onSelectProfile)
                                },
                            )
                        }
                    }
                }

                // ── 2. 日期范围 ──
                item {
                    SectionLabel(ExportStrings.icsExportDateRangeTitle.zh, dark)
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        ArrowPreference(
                            title = ExportStrings.icsExportStartDate.zh,
                            summary = IcsExportLogic.formatDate(options.fromDate),
                            onClick = {
                                showDatePicker(context, options.fromDate, onFromDateChange)
                            },
                        )
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 16.dp),
                            color = Color(QingyuTheme.dividerLine(dark)),
                        )
                        ArrowPreference(
                            title = ExportStrings.icsExportEndDate.zh,
                            summary = IcsExportLogic.formatDate(options.toDate),
                            onClick = {
                                showDatePicker(context, options.toDate, onToDateChange)
                            },
                        )
                    }
                }

                // ── 3. 日历内容 ──
                item {
                    SectionLabel(ExportStrings.icsExportTypesTitle.zh, dark)
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        CheckboxPreference(
                            title = ExportStrings.icsExportCourses.zh,
                            checked = options.eventKinds.contains(IcsExportEventKind.COURSE),
                            onCheckedChange = { onToggleEventKind(IcsExportEventKind.COURSE, it) },
                        )
                        CheckboxPreference(
                            title = ExportStrings.icsExportExams.zh,
                            checked = options.eventKinds.contains(IcsExportEventKind.EXAM),
                            onCheckedChange = { onToggleEventKind(IcsExportEventKind.EXAM, it) },
                        )
                        CheckboxPreference(
                            title = ExportStrings.icsExportSchedules.zh,
                            checked = options.eventKinds.contains(IcsExportEventKind.SCHEDULE_ITEM),
                            onCheckedChange = {
                                onToggleEventKind(IcsExportEventKind.SCHEDULE_ITEM, it)
                            },
                        )
                        // 节假日过滤只对课程有意义：没勾课程时不展示（Dart 219-221）。
                        if (viewState.showSkipHolidayCourses) {
                            SwitchPreference(
                                title = ExportStrings.icsExportSkipHolidayCourses.zh,
                                summary = ExportStrings.icsExportSkipHolidayCoursesSubtitle.zh,
                                checked = options.skipHolidayCourses,
                                onCheckedChange = onSkipHolidayCoursesChange,
                            )
                        }
                    }
                }

                // ── 4. 摘要 ──
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = viewState.summary.title,
                            style = MiuixTheme.textStyles.body1
                                .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        for (line in viewState.summary.lines) {
                            Text(
                                text = line.text,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(
                                    if (line.isError) {
                                        QingyuTheme.error(dark)
                                    } else {
                                        QingyuTheme.secondaryText(dark)
                                    },
                                ),
                                modifier = Modifier.padding(vertical = 2.dp),
                            )
                        }
                    }
                }

                // ── 5. 同步到系统日历 / 移除 ──
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            Button(
                                onClick = onSyncCalendar,
                                enabled = !viewState.isSyncing,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                if (viewState.isSyncing) {
                                    CircularProgressIndicator(size = 18.dp)
                                    Spacer(modifier = Modifier.width(8.dp))
                                }
                                Text(ExportStrings.icsExportSyncCalendarButton.zh)
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Button(
                                onClick = onRemoveCalendar,
                                enabled = !viewState.isRemoving,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(ExportStrings.icsExportRemoveCalendarButton.zh)
                            }
                        }
                    }
                }

                // ── 6. 导出并分享 ──
                item {
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        Button(
                            onClick = onExport,
                            enabled = !viewState.isExporting,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            if (viewState.isExporting) {
                                CircularProgressIndicator(size = 18.dp)
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                            Text(ExportStrings.icsExportButton.zh)
                        }
                    }
                }
            }
        }
    }

    // ── 导出成功后的二选一（Dart `_buildExportActionMenu`） ──
    OverlayDialog(
        // 两行 `ArrowPreference` 自带 16dp；框架侧横向归零 ⇒ 文字单边仍是 16。
        // 分割线自己补 start = 16，与行文字左缘对齐（否则从 0 起、比文字长一截）。
        insideMargin = DpSize(0.dp, 16.dp),
        show = viewState.exportActionMenuVisible,
        title = ExportStrings.icsExportButton.zh,
        onDismissRequest = onDismissExportMenu,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            ArrowPreference(
                title = ExportStrings.icsExportActionShare.zh,
                onClick = onShareExported,
            )
            HorizontalDivider(
                modifier = Modifier.padding(start = 16.dp),
                color = Color(QingyuTheme.dividerLine(dark)),
            )
            ArrowPreference(
                title = ExportStrings.icsExportActionSave.zh,
                onClick = onSaveExported,
            )
        }
    }

    // ── 同步前的一次性说明（Dart `_calendarSyncNoticePrefsKey`：确认过就不再问） ──
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = syncNoticeVisible,
        title = ExportStrings.icsExportSyncCalendarTitle.zh,
        onDismissRequest = onDismissSyncNotice,
    ) {
        Text(
            text = ExportStrings.icsExportSyncCalendarBody.filled(
                "calendarName",
                IcsExportLogic.syncCalendarName(viewState.selectedProfile?.name.orEmpty()),
            ),
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(modifier = Modifier.height(16.dp))
        ConfirmRow(
            cancelLabel = ExportStrings.cancelAction.zh,
            confirmLabel = ExportStrings.icsExportSyncCalendarConfirm.zh,
            onCancel = onDismissSyncNotice,
            onConfirm = onConfirmSyncNotice,
        )
    }

    // ── 移除已同步日程的确认（Dart `_removeFromSystemCalendar` 每次都问） ──
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = removeConfirmVisible,
        title = ExportStrings.icsExportRemoveCalendarTitle.zh,
        onDismissRequest = onDismissRemoveConfirm,
    ) {
        Text(
            text = ExportStrings.icsExportRemoveCalendarBody.zh,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(modifier = Modifier.height(16.dp))
        ConfirmRow(
            cancelLabel = ExportStrings.cancelAction.zh,
            confirmLabel = ExportStrings.icsExportRemoveCalendarConfirm.zh,
            onCancel = onDismissRemoveConfirm,
            onConfirm = onConfirmRemove,
            // 移除系统日程页是破坏性操作：确认按钮用实心危险色。
            destructive = true,
        )
    }
}

/**
 * 确认弹窗底部的「取消 / 确认」一行（与 `SettingsHost` 里主题弹窗同一套摆法：
 * 两个等宽按钮、间距 12dp、取消在左）。
 */
@Composable
private fun ConfirmRow(
    cancelLabel: String,
    confirmLabel: String,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
    destructive: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TextButton(
            modifier = Modifier.weight(1f),
            text = cancelLabel,
            onClick = onCancel,
        )
        Button(
            modifier = Modifier.weight(1f),
            onClick = onConfirm,
            // 危险操作：红底 + onError 字（`color` 是底色、`contentColor` 才是字色）。
            colors = if (destructive) {
                ButtonDefaults.buttonColors(
                    color = Color(QingyuTheme.error(dark)),
                    contentColor = Color(QingyuTheme.onError(dark)),
                )
            } else {
                ButtonDefaults.buttonColorsPrimary()
            },
        ) {
            Text(confirmLabel)
        }
    }
}

/** 小节标题（Dart `HyperosSectionLabel`）。 */
@Composable
private fun SectionLabel(text: String, dark: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1
                .shiftWeight(QingyuWeightDelta.MEDIUM),
            color = Color(QingyuTheme.sectionLabel(dark)),
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
        )
    }
}

/** 系统日期选择器（Dart `HyperosDateTile` + `showDatePicker`）。 */
private fun showDatePicker(
    context: android.content.Context,
    initial: LocalDate,
    onPicked: (LocalDate) -> Unit,
) {
    DatePickerDialog(
        context,
        { _, year, month, dayOfMonth -> onPicked(LocalDate.of(year, month + 1, dayOfMonth)) },
        initial.year,
        initial.monthValue - 1,
        initial.dayOfMonth,
    ).show()
}
