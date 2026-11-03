package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageScaffold as SharedPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.ScrollBehavior
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import java.time.LocalDateTime

/**
 * 导入域共享组合件（P3-G1 · 移植 `lib/screens/import/import_shared.dart` 的 UI 部分）。
 *
 * ## 为什么域内私有而不是上移 `components/`
 *
 * 这些组合件只有导入四页用（入口 / ICS / 表格 / 仓库系已在 P3-G2 自成一套）。
 * 台账 §6 的共享件落点由 Lead 指派，这里先按 BRIEF「域内私有 Common.kt」处理；
 * 真要被别的域用到，再整体上移，不提前抽象。
 *
 * ## 骨架的两条硬教训（照 `pages/about/PagesCommon.kt` 的行车记录）
 *
 * 1. 官方 [TopAppBar] 自己就吃 `WindowInsets.systemBars` 顶部内边距；放进 [Scaffold]
 *    的 `topBar` 槽位后内容只吃顶栏高度 + 底部手势条。第一版把它塞在 content 里，
 *    状态栏高度被算了两遍，标题整体下移一个状态栏。
 * 2. `largeTitle` 默认等于 `title`、`scrollBehavior` 默认 `null`：不传 `largeTitle`
 *    会白送一个 32sp 大标题，不传 `scrollBehavior` 则永不折叠、白占约 60dp。
 *    Dart 侧这几页走 `HyperosSubpage`（`overlayHeader` / `collapsibleLargeTitle`
 *    默认 true），所以两者都必须补齐，并把折叠行为交给内容去挂 `nestedScroll`。
 */
@Composable
fun ImportPageScaffold(
    title: String,
    onBack: () -> Unit,
    bottomBar: (@Composable () -> Unit)? = null,
    content: @Composable (innerPadding: PaddingValues, scrollBehavior: ScrollBehavior) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 统一走共享骨架（官方 TopAppBar + 标准左箭头）。这里只额外保留 Dart 侧
    // 底部按钮区的 SafeArea 内边距（16/12/16）。
    val wrappedBottomBar: (@Composable () -> Unit)? = if (bottomBar == null) {
        null
    } else {
        { ImportBottomBarBox(dark) { bottomBar() } }
    }
    SharedPageScaffold(
        title = title,
        onBack = onBack,
        bottomBar = wrappedBottomBar,
    ) { content(innerPadding, scrollBehavior) }
}

/** 导入页底部按钮区的底衬：页面底色 + SafeArea(minimum: 16/12/16)。 */
@Composable
private fun ImportBottomBarBox(dark: Boolean, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(QingyuTheme.scaffoldBackground(dark)))
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 16.dp),
    ) {
        content()
    }
}

/**
 * 导航行（Dart `HyperosNavTile` + `ImportIconBadge`）：官方 [ArrowPreference] 承担
 * 标题 / 副标题 / 行尾箭头 / 按压反馈，36dp 图标徽标走 `startAction` 槽。
 *
 * 行内左右 16dp 是官方 `BasicComponentDefaults.InsideMargin`：官方轴线
 * 「页面 0 → Card 外边距 12 → 行内 16 = 文字左缘 28」，
 * 与 `QingyuSectionTitle`（`SmallTitle` 自带 28）对齐。
 */
@Composable
fun ImportNavRow(
    title: String,
    subtitle: String,
    icon: ImageVector,
    accentHex: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val accent = Color(parseImportAccentHex(accentHex))
    QingyuCard(modifier = modifier.fillMaxWidth()) {
        ArrowPreference(
            title = title,
            summary = subtitle,
            startAction = { ImportIconBadge(icon = icon, accent = accent) },
            onClick = onClick,
        )
    }
}

/**
 * 开关行（Dart `HyperosSwitchTile`）：官方 [SwitchPreference] 承担整行点击切换与
 * 按压反馈，36dp 图标徽标走 `startAction` 槽。
 * [enabled] = false 表示偏好还没读完，交互不可用（Dart 传 `onChanged: null`）。
 */
@Composable
fun ImportSwitchRow(
    title: String,
    subtitle: String,
    icon: ImageVector,
    accentHex: String,
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val accent = Color(parseImportAccentHex(accentHex))
    QingyuCard(modifier = modifier.fillMaxWidth()) {
        SwitchPreference(
            title = title,
            summary = subtitle,
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
            startAction = { ImportIconBadge(icon = icon, accent = accent) },
        )
    }
}

/**
 * 取值行（Dart `HyperosListTile(title, details, onTap)`）：官方 [ArrowPreference]，
 * 当前行尾取值走 `endActions` 槽。
 * [enabled] = false 时整行置灰不可点（Dart `onTap: null`）；箭头按官方 disabled 态着色。
 */
@Composable
fun ImportValueRow(
    title: String,
    value: String,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(modifier = modifier.fillMaxWidth()) {
        ArrowPreference(
            title = title,
            enabled = enabled,
            onClick = if (enabled) onClick else null,
            endActions = {
                Text(
                    text = value,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            },
        )
    }
}

/** 图标徽标（Dart `ImportIconBadge`）：36dp / 圆角 12 / 主色 12% 底 + 主色图标。 */
@Composable
private fun ImportIconBadge(icon: ImageVector, accent: Color) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(accent.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = accent,
            modifier = Modifier.size(18.dp),
        )
    }
}

/**
 * 导入引导面板（Dart `ImportGuidePanel`）：适用场景卡（含三步引导）+ 支持的文件卡。
 * 步骤标题取 ARB `stepLabel`（「步骤 {step}」），圆形徽标里再去掉前缀只留数字。
 */
@Composable
fun ImportGuidePanel(
    scenarioIntro: String,
    step1Subtitle: String,
    step2Subtitle: String,
    step3Subtitle: String,
    supportedFilesSuffix: String,
    supportedFilesExtra: String? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    Column(modifier = modifier.fillMaxWidth()) {
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            // 普通内容（非 Preference 行）必须给内边距，否则贴卡片边。
            insideMargin = QingyuCardDefaults.ContentInsideMargin,
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = ImportStrings.applicableScenarioTitle.zh,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = scenarioIntro,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 4.dp),
                )
                Spacer(modifier = Modifier.height(14.dp))
                ImportGuideLine(ImportStrings.stepLabel.filled("step", "1"), step1Subtitle)
                Spacer(modifier = Modifier.height(10.dp))
                ImportGuideLine(ImportStrings.stepLabel.filled("step", "2"), step2Subtitle)
                Spacer(modifier = Modifier.height(10.dp))
                ImportGuideLine(ImportStrings.stepLabel.filled("step", "3"), step3Subtitle)
            }
        }
        Spacer(modifier = Modifier.height(12.dp))
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = QingyuCardDefaults.ContentInsideMargin,
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = ImportStrings.supportedFilesTitle.zh,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = supportedFilesSuffix,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 6.dp),
                )
                if (supportedFilesExtra != null) {
                    Text(
                        text = supportedFilesExtra,
                        style = MiuixTheme.textStyles.footnote1,
                        lineHeight = 18.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}

/** 引导行（Dart `ImportGuideLine`）：28dp 主色圆徽标 + 步骤标题 + 说明。 */
@Composable
private fun ImportGuideLine(title: String, subtitle: String) {
    val dark = isSystemInDarkTheme()
    val primary = Color(QingyuTheme.primary(dark = dark))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(primary.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                // Dart: title.replaceAll('步骤 ', '')——徽标里只留数字。
                text = title.replaceFirst("步骤 ", ""),
                style = MiuixTheme.textStyles.footnote1,
                color = primary,
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                lineHeight = 18.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

/**
 * 整宽动作按钮（Dart `HyperosButton(expand: true)`）。
 * [loading] 时按钮内并排一个官方转圈且不可点（Dart 同时把 label 换成「标题...」，由调用方给）。
 */
@Composable
fun ImportActionButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    secondary: Boolean = false,
    loading: Boolean = false,
    enabled: Boolean = true,
) {
    val dark = isSystemInDarkTheme()
    val content: @Composable () -> Unit = {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (loading) {
                CircularProgressIndicator(size = 18.dp)
            }
            Text(label)
        }
    }
    if (secondary) {
        // Dart HyperosButtonVariant.secondary：`#E6E6E6`（暗 0xFF505050）底 + 主文本字
        //（`hyperos_controls.dart:657-818`，与 transfer 域 TransferButton 同款取法）。
        // 以前用 miuix 的 surfaceVariant：深色下与对话框底同为 #242424，按钮直接
        // 「隐身」；浅色下白底蓝字又比灰底主按钮更抢眼（审核报告 P2 旧 :429）。
        Button(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            enabled = enabled && !loading,
            colors = ButtonDefaults.buttonColors(
                color = Color(QingyuTheme.secondary(dark)),
                contentColor = Color(QingyuTheme.primaryText(dark)),
            ),
        ) { content() }
    } else {
        Button(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            enabled = enabled && !loading,
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) { content() }
    }
}

/**
 * 表格导入提醒对话框（Dart `_showSpreadsheetWarnings`）：正文说明 + 逐行「• 提醒」。
 * [warnings] 已由模型层本地化好的成品句（`localizeServiceWarning` 的产物）。
 */
@Composable
fun ImportSpreadsheetWarningsDialog(
    show: Boolean,
    warnings: List<String>,
    onContinue: () -> Unit,
    onDismiss: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 提醒条数无上界：正文限高 + 可滚，动作按钮留在滚动区外（小屏/大字号仍能点到「继续」）。
    val maxBodyHeight = (LocalConfiguration.current.screenHeightDp * 0.5f).dp
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = ImportStrings.spreadsheetImportWarningsTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxBodyHeight)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                item(key = "message") {
                    Text(
                        text = ImportStrings.spreadsheetImportWarningsMessage.zh,
                        style = MiuixTheme.textStyles.body2,
                        lineHeight = 20.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }
                items(warnings) { warning ->
                    Text(
                        text = "• $warning",
                        style = MiuixTheme.textStyles.footnote1,
                        lineHeight = 19.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(bottom = 6.dp),
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            // 两动作横排：取消在左、继续在右（Dart `showAppConfirmDialogWithBody`）。
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ImportActionButton(
                    label = ImportStrings.cancelAction.zh,
                    onClick = onDismiss,
                    secondary = true,
                    modifier = Modifier.weight(1f),
                )
                ImportActionButton(
                    label = ImportStrings.spreadsheetImportWarningsContinue.zh,
                    onClick = onContinue,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/**
 * 把 `ImportEntryModel` 的 accent 槽位名解析成 ARGB。
 *
 * 色值逐字来自 `lib/ui/hyperos/hyperos_tokens.dart:125-129`
 * （`HyperosIconColors` 的 blue / green / orange / purple）；未知槽位回主色，
 * 与 Dart 侧图标底色取不到时回落一致。
 */
fun parseImportAccentHex(slot: String): Long = when (slot.trim().lowercase()) {
    "blue" -> 0xFF3482FF
    "green" -> 0xFF10C550
    "orange" -> 0xFFFF6B00
    "purple" -> 0xFF8B5CF6
    else -> 0xFF3482FF
}

// ==========================================================================
// 导入流程的三个弹层（2026-10-29 · F07 接线补）
//
// Dart 侧这条链路是三张独立对话框接力：`askImportReplaceExisting` →
// `pickImportSemesterConfig` → `ensureImportSectionCapacity`（外加表格那条
// `_showSpreadsheetWarnings` 先于它们）。Kotlin 侧把「替换选择」与「学期映射」
// 合并成**一张预览卡**：用户在同一个地方看到「识别到几门课 / 开学日 / 第 1 周对应
// 校历第几周 / 覆盖还是更新」，少一次点击，也少一处「上一步选了什么都没显示」的
// 状态。**语义不变**：确认前一个字节都不落盘。
// ==========================================================================

/** 预览卡确认后交给宿主的东西（宿主据此做节次检查与落盘）。 */
data class ImportPreviewChoice(
    /** 用户确认的开学日；表格导入没有学期映射环节，传 null。 */
    val semesterStartDate: LocalDateTime?,
    /** 第 1 周对应校历第几周（仅 ICS 用）。 */
    val firstCourseWeek: Int,
    /** true = 覆盖导入；false = 更新课表（保留本地课程并合并）。 */
    val replaceExisting: Boolean,
)

/**
 * 导入预览确认卡（合并 Dart 的「替换选择」与「学期映射」两张对话框）。
 *
 * @param semesterStartDate 非 null 才显示学期映射两行（ICS 走这条）；表格导入传 null。
 * @param lastAllowedWeek 校历周数上限（设置里的 `semesterWeekCount`），周次步进不会越过它。
 * @param hasExistingCourses 本地已有课程 ⇒ 必须让用户在「覆盖」和「更新」之间明确选一个。
 */
@Composable
fun ImportPreviewDialog(
    show: Boolean,
    importLabel: String,
    courseCount: Int,
    semesterStartDate: LocalDateTime?,
    initialFirstCourseWeek: Int,
    lastAllowedWeek: Int,
    hasExistingCourses: Boolean,
    onCancel: () -> Unit,
    onConfirm: (ImportPreviewChoice) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val maxWeek = lastAllowedWeek.coerceAtLeast(1)
    // 弹层常驻组合、可见性只交给 show（提前 return 会把 OverlayDialog 整棵摘出组合，
    // 官方 260ms 退场动画一次都不播；规矩见
    // .agents/notes/implemented/architecture/2026-11-02-settings-dialogs-persistent-composition.md）。
    // 打开时重置步进值：remember 初值只算一次，靠 LaunchedEffect(show) 在每次打开时回填。
    var startDate by remember { mutableStateOf(semesterStartDate) }
    var firstWeek by remember { mutableIntStateOf(initialFirstCourseWeek.coerceIn(1, maxWeek)) }
    LaunchedEffect(show, semesterStartDate, initialFirstCourseWeek, lastAllowedWeek) {
        if (show) {
            startDate = semesterStartDate
            firstWeek = initialFirstCourseWeek.coerceIn(1, maxWeek)
        }
    }

    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = ImportStrings.importReplaceExistingTitle.zh,
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 正文限高可滚：学期映射两行 + 替换说明在小屏/大字号下可能撑出弹窗
            //（审核报告 P1 旧 :520 三个对话框里最后没改到的这条），动作按钮留在滚动区外。
            val maxBodyHeight = (LocalConfiguration.current.screenHeightDp * 0.5f).dp
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxBodyHeight)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                item(key = "body") {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        // 「识别到 N 门课程，是否导入？」
                        Text(
                            text = ImportStrings.importCourseCountPrompt.filled("count", courseCount.toString()),
                            style = MiuixTheme.textStyles.body2,
                            lineHeight = 20.sp,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        val start = startDate
                        if (start != null) {
                            Spacer(modifier = Modifier.height(12.dp))
                            // 开学日只能按周挪：学期起点本来就归一到周一，按天调只会造出半周。
                            ImportStepperRow(
                                title = ImportStrings.importSemesterStartDateTitle.zh,
                                subtitle = ImportStrings.importSemesterStartDateSubtitle.zh,
                                value = ImportSharedModel.importFormatDate(start),
                                onDecrease = { startDate = start.minusDays(7) },
                                onIncrease = { startDate = start.plusDays(7) },
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            ImportStepperRow(
                                title = ImportStrings.importFirstCourseWeekMappingLabel.zh,
                                subtitle = ImportStrings.importFirstCourseWeekMappingSubtitle.zh,
                                value = firstWeek.toString(),
                                onDecrease = { if (firstWeek > 1) firstWeek -= 1 },
                                onIncrease = { if (firstWeek < maxWeek) firstWeek += 1 },
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = if (firstWeek > 1) {
                                    ImportStrings.importSemesterMappingShiftHint.filled(
                                        "shiftedWeeks" to (firstWeek - 1).toString(),
                                        "calendarWeek" to firstWeek.toString(),
                                    )
                                } else {
                                    ImportStrings.importSemesterMappingNoShiftHint.zh
                                },
                                style = MiuixTheme.textStyles.footnote1,
                                lineHeight = 18.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                        if (hasExistingCourses) {
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = ImportStrings.importReplaceExistingMessage.filled("name", importLabel),
                                style = MiuixTheme.textStyles.body2,
                                lineHeight = 20.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = ImportStrings.importReplaceExistingGuidance.zh,
                                style = MiuixTheme.textStyles.body2,
                                lineHeight = 20.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            val choiceStart = startDate
            if (hasExistingCourses) {
                // 顺序对齐 Dart `showAppTripleActionDialog`：取消 → 更新（推荐） → 覆盖（主），
                // 三个动作竖排、间距 12dp。
                ImportActionButton(
                    label = ImportStrings.cancelAction.zh,
                    onClick = onCancel,
                    secondary = true,
                )
                Spacer(modifier = Modifier.height(12.dp))
                ImportActionButton(
                    label = ImportStrings.courseImportUpdateRecommendedAction.zh,
                    onClick = {
                        onConfirm(ImportPreviewChoice(choiceStart, firstWeek, replaceExisting = false))
                    },
                    secondary = true,
                )
                Spacer(modifier = Modifier.height(12.dp))
                ImportActionButton(
                    label = ImportStrings.courseImportOverwriteAction.zh,
                    onClick = {
                        onConfirm(ImportPreviewChoice(choiceStart, firstWeek, replaceExisting = true))
                    },
                )
            } else {
                // 本地没课 ⇒ 只有一条路（整份写入），不摆「覆盖 / 更新」二选一。
                // 两动作横排等宽：取消在左、继续在右（Dart/官方 demo 的两动作排布，
                // 与同文件 ImportCapacityDialog 一致）。
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    ImportActionButton(
                        label = ImportStrings.cancelAction.zh,
                        onClick = onCancel,
                        secondary = true,
                        modifier = Modifier.weight(1f),
                    )
                    ImportActionButton(
                        label = ImportStrings.spreadsheetImportWarningsContinue.zh,
                        onClick = {
                            onConfirm(ImportPreviewChoice(choiceStart, firstWeek, replaceExisting = true))
                        },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

/**
 * 一行「标题 + 说明 + ◀ 取值 ▶」（Dart `pickImportSemesterConfig` 里的两个可调行）。
 * 步进按钮用官方 [TextButton]，不自己画圆形箭头——按压反馈与无障碍都跟着 miuix。
 */
@Composable
private fun ImportStepperRow(
    title: String,
    subtitle: String,
    value: String,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                lineHeight = 18.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        TextButton(text = "－", onClick = onDecrease)
        Text(
            text = value,
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.primaryText(dark)),
            modifier = Modifier.padding(horizontal = 4.dp),
        )
        TextButton(text = "＋", onClick = onIncrease)
    }
}

/**
 * 节次容量不足确认（Dart `ensureImportSectionCapacity` 的对话框那一半）。
 *
 * 「自动补齐」会**当场改作息**（写时间模板 / 设置节次表），所以这里必须让用户看见
 * 「现在几节 / 导入需要到第几节」，不能悄悄补。
 */
@Composable
fun ImportCapacityDialog(
    show: Boolean,
    currentSectionCount: Int,
    requiredSectionCount: Int,
    onCancel: () -> Unit,
    onAutoFill: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // 常驻组合、show 驱动显隐：提前 return 会让官方 260ms 退场动画一次都不播
    //（与 ImportPreviewDialog 同一条规矩）。
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = ImportStrings.courseImportSectionCountInsufficientTitle.zh,
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = ImportStrings.courseImportSectionCountInsufficientMessage.filled(
                    "current" to currentSectionCount.toString(),
                    "required" to requiredSectionCount.toString(),
                ),
                style = MiuixTheme.textStyles.body2,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(16.dp))
            // 两动作横排等宽：取消在左、自动补齐（主）在右，与 Dart 的确认弹层一致。
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ImportActionButton(
                    label = ImportStrings.cancelAction.zh,
                    onClick = onCancel,
                    secondary = true,
                    modifier = Modifier.weight(1f),
                )
                ImportActionButton(
                    label = ImportStrings.courseImportAutoFillAndImportAction.zh,
                    onClick = onAutoFill,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/**
 * 随机配色组选择弹层（Dart `import_random_color_toggle.dart` 的 `showHyperosSheet`）。
 *
 * Dart 原版是**底部弹层** + `HyperosChoiceGroup`：选项行 = 标题 + 色点预览 +
 * 选中行尾 22dp 勾（`tiles.dart:630-693`），选完立刻落盘并关闭、没有「取消」按钮
 * （`Navigator.pop(sheetContext, groupId)`）。这里照抄同一形态，不再用居中对话框里
 * 嵌卡片 + 右箭头 + 灰色 ✓ 的旧写法。
 *
 * 选项顺序与色板表一致（[ImportRandomColorStore.GROUP_OPTIONS]）。
 * 选项行骨架与 `pages/task/TaskPickerSheets.kt` 的选课程弹层同款。
 */
@Composable
fun ImportColorGroupSheet(
    show: Boolean,
    selectedGroupId: String,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme
    // 7 行配色组在小屏/大字号下会撑出面板：清单限高可滚（弹层内短列表，不承载页面级滚动）。
    val maxListHeight = (LocalConfiguration.current.screenHeightDp * 0.5f).dp
    QingyuSheet(
        show = show,
        title = ImportStrings.importRandomColorGroupTitle.zh,
        // 内容自己有 LazyColumn ⇒ 不再套外层 verticalScroll，底部让位落进列表 contentPadding。
        contentScrolls = true,
        onDismissRequest = onDismiss,
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = maxListHeight)
                .scrollEndHaptic()
                .overScrollVertical(),
            contentPadding = PaddingValues(bottom = bottomInset),
        ) {
            itemsIndexed(ImportRandomColorStore.GROUP_OPTIONS) { index, groupId ->
                val selected = groupId == selectedGroupId
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = COLOR_GROUP_ROW_MIN_HEIGHT)
                        .clickable { onSelect(groupId) }
                        .padding(
                            horizontal = COLOR_GROUP_ROW_HORIZONTAL_PADDING,
                            vertical = COLOR_GROUP_ROW_VERTICAL_PADDING,
                        ),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = ImportRandomColorStore.groupLabel(groupId),
                            // Dart 选项行是 `HyperosChoiceTile` → listTitle ⇒ 官方字阶 main。
                            style = MiuixTheme.textStyles.main,
                            color = Color(QingyuTheme.primaryText(dark)),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        ImportColorDotsPreview(
                            hexes = ImportSharedModel.courseColorGroupPalette(groupId),
                        )
                    }
                    if (selected) {
                        // Dart `HyperosSelectedCheckmark(size = 22)`（dialog 变体）。
                        Spacer(modifier = Modifier.width(COLOR_GROUP_CHECK_GAP))
                        Icon(
                            imageVector = MiuixIcons.Ok,
                            contentDescription = null,
                            modifier = Modifier.size(COLOR_GROUP_CHECK_SIZE),
                            tint = colors.primary,
                        )
                    }
                }
            }
        }
    }
}

/** Dart `HyperosChoiceTile` 行最小高度（`HyperosMiuixSpec.settingsRowMinHeight`）。 */
private val COLOR_GROUP_ROW_MIN_HEIGHT = 56.dp

/** Dart `HyperosMiuixSpec.settingsRowPadding`（`16,13,16,13`）。 */
private val COLOR_GROUP_ROW_HORIZONTAL_PADDING = 16.dp
private val COLOR_GROUP_ROW_VERTICAL_PADDING = 13.dp

/** Dart `HyperosSelectedCheckmark(size = 22)`（dialog 变体）。 */
private val COLOR_GROUP_CHECK_SIZE = 22.dp

/** 勾与标题之间的间隔（Dart `tiles.dart:657` `SizedBox(width: 6)`）。 */
private val COLOR_GROUP_CHECK_GAP = 6.dp

/**
 * 选组行的色点预览（Dart `_ColorDotsPreview`，`import_random_color_toggle.dart:132-166`）：
 * 色板过长时按步长抽样，最多 10 个 14dp 圆点、间距 4dp。
 */
@Composable
private fun ImportColorDotsPreview(hexes: List<String>) {
    val stride = if (hexes.size > 10) (hexes.size + 9) / 10 else 1
    Row(
        modifier = Modifier.padding(top = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        (hexes.indices step stride).take(10).forEach { index ->
            Box(
                modifier = Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(parseHexColorOrFallback(hexes[index])),
            )
        }
    }
}
