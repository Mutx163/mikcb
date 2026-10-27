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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.transfer.IcsExportEventKind
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
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
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val options = viewState.options

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            TopAppBar(
                title = ExportStrings.icsExportTitle.zh,
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

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // ── 1. 课表选择 ──
                item {
                    SectionLabel(ExportStrings.icsExportProfileLabel.zh, dark)
                    Card(modifier = Modifier.fillMaxWidth()) {
                        if (viewState.profiles.isEmpty()) {
                            Text(
                                text = ExportStrings.icsExportNoProfiles.zh,
                                fontSize = 14.sp,
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
                    Card(modifier = Modifier.fillMaxWidth()) {
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
                    Card(modifier = Modifier.fillMaxWidth()) {
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
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = viewState.summary.title,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        for (line in viewState.summary.lines) {
                            Text(
                                text = line.text,
                                fontSize = 13.sp,
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
                    Card(modifier = Modifier.fillMaxWidth()) {
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
                    Card(modifier = Modifier.fillMaxWidth()) {
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
        show = viewState.exportActionMenuVisible,
        title = ExportStrings.icsExportButton.zh,
        onDismissRequest = onDismissExportMenu,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            ArrowPreference(
                title = ExportStrings.icsExportActionShare.zh,
                onClick = onShareExported,
            )
            HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
            ArrowPreference(
                title = ExportStrings.icsExportActionSave.zh,
                onClick = onSaveExported,
            )
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
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
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
