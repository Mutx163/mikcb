package com.mutx163.qingyu.pages.export

import android.app.DatePickerDialog
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import com.mutx163.qingyu.transfer.IcsExportEventKind
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
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

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃；大标题可折叠
    // （Dart ics_export_screen.dart 的 HyperosSubpage 标题是纯 Text）。
    QingyuPageScaffold(title = ExportStrings.icsExportTitle.text, onBack = onBack) {
        // 不手写 statusBarsPadding()：官方 TopAppBar 自带系统栏顶部内边距，
        // 再写一次是叠加，标题会下移一个多状态栏高（2026-10-27）。
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
                    QingyuSectionTitle(ExportStrings.icsExportProfileLabel.text)
                    // 卡里要么是 *Preference 行（自带 16dp），要么是自带 16dp 内边距的提示行，
                    // 所以**不传** insideMargin，避免叠成 32dp。
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        if (viewState.profiles.isEmpty()) {
                            Text(
                                text = ExportStrings.icsExportNoProfiles.text,
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
                                title = ExportStrings.icsExportProfileLabel.text,
                                onSelectedIndexChange = { index ->
                                    values.getOrNull(index)?.let(onSelectProfile)
                                },
                            )
                        }
                    }
                }

                // ── 2. 日期范围 ──
                item {
                    SectionLabel(ExportStrings.icsExportDateRangeTitle.text, dark)
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        ArrowPreference(
                            title = ExportStrings.icsExportStartDate.text,
                            summary = IcsExportLogic.formatDate(options.fromDate),
                            onClick = {
                                showDatePicker(context, options.fromDate, onFromDateChange)
                            },
                        )
                        ArrowPreference(
                            title = ExportStrings.icsExportEndDate.text,
                            summary = IcsExportLogic.formatDate(options.toDate),
                            onClick = {
                                showDatePicker(context, options.toDate, onToDateChange)
                            },
                        )
                    }
                }

                // ── 3. 日历内容 ──
                item {
                    SectionLabel(ExportStrings.icsExportTypesTitle.text, dark)
                    QingyuCard(modifier = Modifier.fillMaxWidth()) {
                        CheckboxPreference(
                            title = ExportStrings.icsExportCourses.text,
                            checked = options.eventKinds.contains(IcsExportEventKind.COURSE),
                            onCheckedChange = { onToggleEventKind(IcsExportEventKind.COURSE, it) },
                        )
                        CheckboxPreference(
                            title = ExportStrings.icsExportExams.text,
                            checked = options.eventKinds.contains(IcsExportEventKind.EXAM),
                            onCheckedChange = { onToggleEventKind(IcsExportEventKind.EXAM, it) },
                        )
                        CheckboxPreference(
                            title = ExportStrings.icsExportSchedules.text,
                            checked = options.eventKinds.contains(IcsExportEventKind.SCHEDULE_ITEM),
                            onCheckedChange = {
                                onToggleEventKind(IcsExportEventKind.SCHEDULE_ITEM, it)
                            },
                        )
                        // 节假日过滤只对课程有意义：没勾课程时不展示（Dart 219-221）。
                        if (viewState.showSkipHolidayCourses) {
                            SwitchPreference(
                                title = ExportStrings.icsExportSkipHolidayCourses.text,
                                summary = ExportStrings.icsExportSkipHolidayCoursesSubtitle.text,
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
                                Text(ExportStrings.icsExportSyncCalendarButton.text)
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Button(
                                onClick = onRemoveCalendar,
                                enabled = !viewState.isRemoving,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(ExportStrings.icsExportRemoveCalendarButton.text)
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
                            Text(ExportStrings.icsExportButton.text)
                        }
                    }
                }
        }
    }

    // ── 导出成功后的二选一（Dart `_buildExportActionMenu`） ──
    // 拍板 #8：改底部 `QingyuSheet`，去标题、去右箭头（Dart 是按钮锚点菜单，
    // 本仓统一收成底部动作弹层，两个动作铺满整宽）。#7 的 42dp 顶部空档按拍板保留。
    QingyuSheet(
        show = viewState.exportActionMenuVisible,
        onDismissRequest = onDismissExportMenu,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = ExportStrings.icsExportActionShare.text,
                onClick = onShareExported,
            )
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = ExportStrings.icsExportActionSave.text,
                onClick = onSaveExported,
            )
        }
    }

    // ── 同步前的一次性说明（Dart `_calendarSyncNoticePrefsKey`：确认过就不再问） ──
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = syncNoticeVisible,
        title = ExportStrings.icsExportSyncCalendarTitle.text,
        onDismissRequest = onDismissSyncNotice,
    ) {
        Text(
            text = ExportStrings.icsExportSyncCalendarBody.filled(
                "calendarName",
                IcsExportLogic.syncCalendarName(viewState.selectedProfile?.name.orEmpty()),
            ),
            // Flutter 弹窗正文居中（hyperos_dialog.dart:52 `textAlign: TextAlign.center`）。
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(modifier = Modifier.height(16.dp))
        ConfirmRow(
            cancelLabel = ExportStrings.cancelAction.text,
            confirmLabel = ExportStrings.icsExportSyncCalendarConfirm.text,
            onCancel = onDismissSyncNotice,
            onConfirm = onConfirmSyncNotice,
        )
    }

    // ── 移除已同步日程的确认（Dart `_removeFromSystemCalendar` 每次都问） ──
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = removeConfirmVisible,
        title = ExportStrings.icsExportRemoveCalendarTitle.text,
        onDismissRequest = onDismissRemoveConfirm,
    ) {
        Text(
            text = ExportStrings.icsExportRemoveCalendarBody.text,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(modifier = Modifier.height(16.dp))
        ConfirmRow(
            cancelLabel = ExportStrings.cancelAction.text,
            confirmLabel = ExportStrings.icsExportRemoveCalendarConfirm.text,
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

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照抄 about/ContributorsPage.kt 的样板）
//
// 只给实现阶段看效果，不进业务路径。本页是三个弹层 + 一张摘要卡的组合，铺四档：
// 正常（两门课表可选） / 没有课表（`profiles` 为空，下拉退化成一行提示） /
// 正在导出（按钮进加载态）/ 导出完成待二选一（分享还是保存）；再叠暗色与大字号。
//
// 固定写法（与样板一致，别自己改）：
//   • 主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }：页面取色走
//     isSystemInDarkTheme()，只有它会改写 LocalConfiguration 的 uiMode，预览才和真机同口径；
//   • 字号用 QingyuPageTheme(textScale = …)，不要用 @Preview(fontScale = …)；
//   • 宽度按 400dp（本仓折行实测口径），高度给一屏多。
//
// 弹层（同步说明 / 移除确认 / 导出后菜单）在预览里一律关着：那是交互中间态，
// 点下去才出现，静态截图看不出真假。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：两门课表，日期范围按 2026 秋季学期给。 */
private fun previewIcsExportView(): IcsExportViewState = IcsExportViewState(
    profiles = listOf(
        IcsExportProfile(
            id = "profile-autumn",
            name = "2026 秋季学期",
            semesterStartDate = LocalDate.of(2026, 9, 1),
            semesterWeekCount = 20,
        ),
        IcsExportProfile(
            id = "profile-spring",
            name = "2027 春季学期",
            semesterStartDate = LocalDate.of(2027, 2, 23),
            semesterWeekCount = 18,
        ),
    ),
    selectedProfileId = "profile-autumn",
    options = IcsExportOptions(
        fromDate = LocalDate.of(2026, 9, 1),
        toDate = LocalDate.of(2027, 1, 15),
    ),
)

/** 没有课表：`profiles` 为空时下拉退化成一行提示，摘要卡也跟着空。 */
private fun previewIcsExportNoProfileView(): IcsExportViewState = previewIcsExportView().copy(
    profiles = emptyList(),
    selectedProfileId = null,
)

/** 一档预览的公共身体：数据形态 + 外观档位。 */
@Composable
private fun PreviewIcsExportPage(
    viewState: IcsExportViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        IcsExportPage(
            viewState = viewState,
            onBack = {},
            onSelectProfile = {},
            onFromDateChange = {},
            onToDateChange = {},
            onToggleEventKind = { _, _ -> },
            onSkipHolidayCoursesChange = {},
            onExport = {},
            onShareExported = {},
            onSaveExported = {},
            onDismissExportMenu = {},
            onSyncCalendar = {},
            onRemoveCalendar = {},
            syncNoticeVisible = false,
            onConfirmSyncNotice = {},
            onDismissSyncNotice = {},
            removeConfirmVisible = false,
            onConfirmRemove = {},
            onDismissRemoveConfirm = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 正常", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewIcsExportNormal() {
    PreviewIcsExportPage(previewIcsExportView())
}

@Suppress("unused")
@Preview(name = "2 没有课表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewIcsExportNoProfile() {
    PreviewIcsExportPage(previewIcsExportNoProfileView())
}

@Suppress("unused")
@Preview(name = "3 正在导出", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewIcsExportExporting() {
    PreviewIcsExportPage(previewIcsExportView().copy(isExporting = true))
}

@Suppress("unused")
@Preview(name = "4 导出后二选一", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewIcsExportMenu() {
    PreviewIcsExportPage(
        previewIcsExportView().copy(exportActionMenuVisible = true, pendingEventCount = 42),
    )
}

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewIcsExportDark() {
    PreviewIcsExportPage(previewIcsExportView(), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewIcsExportLargeText() {
    PreviewIcsExportPage(previewIcsExportView(), textScale = 1.3f)
}
