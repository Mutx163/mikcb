package com.mutx163.qingyu.pages.transfer

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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.pages.export.ExportStrings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.CheckboxPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 数据备份与迁移页 · Compose 渲染层。
 *
 * 逐项对照 `lib/screens/data_transfer_screen.dart`（838 行）复刻，审核记录见
 * `docs/plans/2026-10-29-datatransfer-audit.md`。
 *
 * ## 页面骨架（Dart 出处）
 *
 * `HyperosSubpage`（可折叠大标题）→ `HyperosListView`，children 恰好 13 项
 * （`data_transfer_screen.dart:53-195`）：
 *
 * 1. section「完整导出」+ 卡（3 个按钮，`Wrap spacing/runSpacing = 8`）
 * 2. 日历组（**无 section label**，源码注释说标签已删）+ 单行导航
 * 3. section「完整导入」+ 卡（1 个通栏按钮）
 * 4. section「二维码面对面传输」+ 卡（说明句 → 红字警告 → 3 个按钮）
 * 5. section「当前可迁移内容」+ 卡（7 行概览，行距 10、末行 0）
 *
 * **全页没有分割线、没有页面级空态、没有常驻「撤销」按钮**（撤销只在成功提示的尾部动作里），
 * 三条都是 2026-10-29 审核从 Dart 侧确认过的「不存在元素」，旧版 Compose 三样都自造了。
 *
 * ## 不持业务状态
 *
 * 概览行、按钮忙碌、选课科目组都来自 [DataTransferViewState]；打包/写文件/选文件/应用
 * 全在宿主（`DataTransferHost`）与模型层，这里只把回调抛上去。
 * 页面自持的只有两个弹层的可见性与选课集合——它们是纯界面状态，Dart 也是在 State 里。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DataTransferPage(
    viewState: DataTransferViewState,
    onBack: () -> Unit,
    onExportCurrent: () -> Unit,
    onExportAllData: () -> Unit,
    onExportTimeTemplate: () -> Unit,
    onOpenIcsExport: () -> Unit,
    onChooseFileAndImport: () -> Unit,
    onQrSend: (TransferScope, Set<String>) -> Unit,
    onQrSendAll: () -> Unit,
    onQrScan: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    // ── 两个弹层的界面状态（Dart `_chooseQrScope` / `_chooseCoursesForQr`） ──
    var qrScopeDialogVisible by remember { mutableStateOf(false) }
    var courseSheetVisible by remember { mutableStateOf(false) }
    var pendingScope by remember { mutableStateOf<TransferScope?>(null) }
    var selectedCourseIds by remember { mutableStateOf(emptySet<String>()) }

    QingyuPageScaffold(
        title = TransferStrings.dataTransferTitle.zh,
        onBack = onBack,
    ) {
        QingyuPageList(
            // 与官方骨架同配方：innerPadding 只取 top（顶栏已吃系统栏），底部手势条自己加。
            innerPadding = PaddingValues(top = innerPadding.calculateTopPadding()),
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = innerPadding.calculateBottomPadding() + 24.dp),
            // Dart 的分组间距是 `HyperosSectionGap` = 12（`hyperos_miuix_spec.dart:78`）。
            verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
        ) {
            // ── 1. 完整导出 ────────────────────────────────────────────
            item(key = "full-export") {
                QingyuSectionTitle(TransferStrings.fullExportTitle.zh)
                QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = TransferCardInsideMargin) {
                    // Dart `Wrap(spacing: 8, runSpacing: 8)`：放不下就换行，不是固定两行。
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        TransferButton(
                            label = TransferStrings.exportCurrentTimetable.zh,
                            onClick = onExportCurrent,
                            primary = true,
                            loading = viewState.isExporting,
                            enabled = !viewState.isExporting,
                        )
                        TransferButton(
                            label = TransferStrings.exportAllData.zh,
                            onClick = onExportAllData,
                            enabled = !viewState.isExporting,
                        )
                        // 没有时间模板时按钮**仍在**，只是禁用（Dart `:76-78` 的 enabled 判据）。
                        TransferButton(
                            label = TransferStrings.exportTimeTemplate.zh,
                            onClick = onExportTimeTemplate,
                            enabled = !viewState.isExporting && viewState.canExportTimeTemplate,
                        )
                    }
                }
            }

            // ── 2. 导出日历（分组标签已删，组里唯一那行标题就是它） ──────
            item(key = "ics-export") {
                QingyuCard(modifier = Modifier.fillMaxWidth()) {
                    ArrowPreference(
                        title = ExportStrings.icsExportSectionTitle.zh,
                        onClick = onOpenIcsExport,
                    )
                }
            }

            // ── 3. 完整导入 ────────────────────────────────────────────
            item(key = "full-import") {
                QingyuSectionTitle(TransferStrings.fullImportTitle.zh)
                QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = TransferCardInsideMargin) {
                    // Dart 参数上没写 `expand: true`，但父级是 stretch ⇒ 视觉上就是通栏。
                    TransferButton(
                        label = TransferStrings.chooseFileAndImport.zh,
                        onClick = onChooseFileAndImport,
                        loading = viewState.isImporting,
                        enabled = !viewState.isImporting,
                        fillWidth = true,
                    )
                }
            }

            // ── 4. 二维码面对面传输 ─────────────────────────────────────
            item(key = "qr-transfer") {
                QingyuSectionTitle(TransferStrings.qrTransferSectionTitle.zh)
                QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = TransferCardInsideMargin) {
                    Text(
                        text = TransferStrings.qrTransferSectionSubtitle.zh,
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    // 明文警告：Dart 用 error 色（`data_transfer_screen.dart:120-125`）。
                    Text(
                        text = TransferStrings.qrTransferPlaintextWarning.zh,
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.error(dark)),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        TransferButton(
                            label = TransferStrings.qrTransferSendCurrent.zh,
                            onClick = { qrScopeDialogVisible = true },
                            primary = true,
                            enabled = !viewState.isExporting,
                        )
                        TransferButton(
                            label = TransferStrings.qrTransferSendAll.zh,
                            onClick = onQrSendAll,
                            enabled = !viewState.isExporting,
                        )
                        // 扫码只看 `_isImporting`，不看 `_isExporting`（Dart `:143`）。
                        TransferButton(
                            label = TransferStrings.qrTransferScanReceive.zh,
                            onClick = onQrScan,
                            enabled = !viewState.isImporting,
                        )
                    }
                }
            }

            // ── 5. 当前可迁移内容（7 行，无分割线） ─────────────────────
            item(key = "overview") {
                QingyuSectionTitle(TransferStrings.transferOverviewTitle.zh)
                QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = TransferCardInsideMargin) {
                    val rows = viewState.overviewRows
                    rows.forEachIndexed { index, row ->
                        // Dart：普通行 marginBottom 10、末行 0（`data_transfer_screen.dart:227`）。
                        val bottom = if (index == rows.lastIndex) 0.dp else 10.dp
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = bottom),
                            verticalAlignment = Alignment.Top,
                        ) {
                            // 左右两栏**同一套**样式（listDetail = body2/14/次级灰），只有对齐方式不同。
                            Text(
                                text = row.label,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.weight(1f),
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = row.value,
                                style = MiuixTheme.textStyles.body2,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                textAlign = TextAlign.End,
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }
                }
            }
        }
    }

    // ── 二维码发送范围（Dart `_chooseQrScope`：5 个动作竖排，最后一个 primary） ──
    QrScopeDialog(
        show = qrScopeDialogVisible,
        dark = dark,
        onDismiss = { qrScopeDialogVisible = false },
        onScopeChosen = { scope ->
            qrScopeDialogVisible = false
            when {
                scope == null -> Unit
                DataTransferLogic.requiresCourseSelection(scope) -> {
                    // 需要先勾课：弹层打开，勾完才真正发送。
                    pendingScope = scope
                    selectedCourseIds = emptySet()
                    courseSheetVisible = true
                }
                else -> onQrSend(scope, emptySet())
            }
        },
    )

    // ── 选课弹层（Dart `_chooseCoursesForQr`：按科目聚合、整组勾选、空态、完成） ──
    CoursePickerSheet(
        show = courseSheetVisible,
        dark = dark,
        groups = viewState.courseGroups,
        selected = selectedCourseIds,
        onToggle = { group -> selectedCourseIds = DataTransferLogic.toggleCourseGroup(selectedCourseIds, group) },
        onDismiss = {
            courseSheetVisible = false
            pendingScope = null
        },
        onConfirm = {
            courseSheetVisible = false
            val scope = pendingScope
            pendingScope = null
            // Dart：返回 null 或空集合 ⇒ 整条发送直接 return，不提示错误（`:457-465`）。
            if (scope != null && selectedCourseIds.isNotEmpty()) {
                onQrSend(scope, selectedCourseIds)
            }
        },
    )
}

/**
 * 二维码范围弹窗。
 *
 * 复刻 `data_transfer_screen.dart:696-736` 的两处口径：
 * 1. 正文用**主文本墨色**（源码注释：默认的次级灰在液态玻璃弹窗上几乎看不见）；
 * 2. 5 个动作**竖排**（Dart `HyperosDialog` 在 ≥3 个动作时走 Column + 12dp 间距），
 *    最后一个「二维码发送当前课表」是 primary。
 */
@Composable
private fun QrScopeDialog(
    show: Boolean,
    dark: Boolean,
    onDismiss: () -> Unit,
    onScopeChosen: (TransferScope?) -> Unit,
) {
    OverlayDialog(
        show = show,
        // 本仓/Dart 的对话框横向口径是 16dp（官方默认 24 偏大，审核报告 P2 旧 :303）。
        insideMargin = DpSize(16.dp, 16.dp),
        title = TransferStrings.qrTransferSendCurrent.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = TransferStrings.qrTransferSectionSubtitle.zh,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            for (action in DataTransferLogic.qrScopeDialogActions()) {
                TransferButton(
                    label = action.label,
                    onClick = { onScopeChosen(action.scope) },
                    modifier = Modifier.fillMaxWidth(),
                    primary = action.isPrimary,
                    fillWidth = true,
                )
            }
        }
    }
}

/**
 * 选课弹层（按科目聚合）。
 *
 * Dart 的硬约束（`data_transfer_screen.dart:742-833`）：
 * - 列表区最大高 = 屏高 × 0.52（`:753`）；
 * - 空态：上下各 32dp 留白 + `noCoursesInCurrentProfile`（`:766-774`）；
 * - 每一行是「科目名 + 可选老师」的整组勾选（`:783-812`），勾选判据是「组里任一课被勾」；
 * - 底部「完成」整宽（`:818-825`），回传选中集合。
 *
 * 列表用 `LazyColumn`（弹层内的短列表，Dart 原版是 `SingleChildScrollView`）。
 */
@Composable
private fun CoursePickerSheet(
    show: Boolean,
    dark: Boolean,
    groups: List<TransferCourseGroup>,
    selected: Set<String>,
    onToggle: (TransferCourseGroup) -> Unit,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val maxListHeight = (LocalConfiguration.current.screenHeightDp * 0.52f).dp
    // 底部是通栏 `TransferButton(fillMaxWidth)` ⇒ 走套件的 16dp 框架内边距；
    // 列表自己有 LazyColumn ⇒ `contentScrolls = true`，底部让位补在按钮**之后**
    //（塞进列表会在按钮上方造一截空白）。
    QingyuSheet(
        show = show,
        title = TransferStrings.qrTransferShareSelectedCourses.zh,
        contentScrolls = true,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            if (groups.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 32.dp),
                ) {
                    Text(
                        text = TransferStrings.noCoursesInCurrentProfile.zh,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            } else {
                LazyColumn(modifier = Modifier.heightIn(max = maxListHeight)) {
                    items(groups, key = { it.name }) { group ->
                        CheckboxPreference(
                            title = group.name,
                            // 没有老师就不给 summary，行高从 72 回到 56（Dart `:786-792`）。
                            summary = group.teacher.takeIf { it.isNotEmpty() },
                            checked = DataTransferLogic.isCourseGroupSelected(selected, group),
                            onCheckedChange = { onToggle(group) },
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            TransferButton(
                label = TransferStrings.qrTransferSelectCoursesDone.zh,
                onClick = onConfirm,
                primary = true,
                modifier = Modifier.fillMaxWidth(),
                fillWidth = true,
            )
            // 底部让位（系统手势区 + 16dp）：套件只在「内容自己不滚」时替我们补，
            // 这里内容自己滚，所以补在最后一块固定件之后。
            Spacer(modifier = Modifier.height(bottomInset))
        }
    }
}

/**
 * 页面内动作按钮（Dart `HyperosButton`）。
 *
 * 三处口径来自 `hyperos_controls.dart:657-818`：
 * - primary = 主题色底 + 自动黑白字；secondary = `#E6E6E6` 底 + 主文本字
 *   （对应 [QingyuTheme.secondary] / [QingyuTheme.primaryText]）；
 * - `loading: true` 时**标签被 18×18 转圈整个替换**（`:745-753`）——Dart 的两个「忙碌文案」
 *   因此永远上不了屏，这里照抄，不另外画「文案 + 转圈」；
 * - `enabled = onPressed != null && !loading`（`:683`），禁用不隐藏。
 */
@Composable
internal fun TransferButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
    loading: Boolean = false,
    enabled: Boolean = true,
    fillWidth: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    val actualModifier = if (fillWidth) modifier.fillMaxWidth() else modifier
    val content: @Composable () -> Unit = {
        if (loading) {
            CircularProgressIndicator(size = 18.dp)
        } else {
            Text(label)
        }
    }
    if (primary) {
        Button(
            onClick = onClick,
            modifier = actualModifier,
            enabled = enabled && !loading,
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) { content() }
    } else {
        Button(
            onClick = onClick,
            modifier = actualModifier,
            enabled = enabled && !loading,
            colors = ButtonDefaults.buttonColors(
                color = Color(QingyuTheme.secondary(dark)),
                contentColor = Color(QingyuTheme.primaryText(dark)),
            ),
        ) { content() }
    }
}

/**
 * 卡片内容外边距。
 *
 * Dart 的无 header 卡内边距是 `LTRB 16 / 16 / 16 / **12**`
 * （`hyperos_controls.dart:78-83`：`defaultBodyBottomInset = 12`），
 * 不是四边等 16——底部少 4dp 是有意的，和 `QingyuCardDefaults.ContentInsideMargin` 的 16 不同。
 */
private val TransferCardInsideMargin = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 12.dp)

/**
 * 导入方式预览弹窗（`lib/screens/transfer_preview_dialog.dart`）。
 *
 * - 正文是**多行纯文本**（段间空行），居中显示，样式 listDetail（14/次级灰）；
 * - 三个动作竖排：取消 / 合并更改 / 覆盖当前课表（最后一个 primary）；
 * - 关闭（点遮罩 / 返回键）回传 null = 不导入。
 */
@Composable
fun TransferPreviewDialog(
    content: TransferPreviewContent?,
    canMerge: Boolean = true,
    onChoose: (TransferApplyMode?) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 退场动画期间保留最后一份非空 content：content 置 null 触发关闭时，标题若直接
    // 跟着读 null 会切到兜底文案、正文清空，面板先「变空」再消失（审核报告 P3
    // 旧 :479 的「空板退场」）。可见性仍由 content 驱动。
    var shown by remember { mutableStateOf(content) }
    if (content != null) shown = content
    val current = shown
    // 4 行头信息 + merge/overwrite 两段差异摘要可能很长：正文限高 + 可滚，动作按钮留在滚动区外。
    val maxBodyHeight = (LocalConfiguration.current.screenHeightDp * 0.45f).dp
    OverlayDialog(
        show = content != null,
        // 与 QrScopeDialog 同一口径：对话框内缩收到 16dp（官方默认 24 偏大）。
        insideMargin = DpSize(16.dp, 16.dp),
        title = current?.title ?: TransferStrings.selectImportModeTitle.zh,
        onDismissRequest = { onChoose(null) },
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxBodyHeight)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                item(key = "message") {
                    Text(
                        text = current?.message.orEmpty(),
                        style = MiuixTheme.textStyles.body2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            for (action in DataTransferLogic.previewActions(canMerge)) {
                TransferButton(
                    label = action.label,
                    onClick = { onChoose(action.mode) },
                    modifier = Modifier.fillMaxWidth(),
                    primary = action.mode == TransferApplyMode.OVERWRITE,
                    fillWidth = true,
                )
            }
        }
    }
}
