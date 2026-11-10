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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuColorPreviewDotGap
import com.mutx163.qingyu.components.QingyuColorPreviewDotSize
import com.mutx163.qingyu.components.QingyuLoadingInButton
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.QingyuPageScaffold as SharedPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
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
    inGroup: Boolean = false,
) {
    val accent = Color(parseImportAccentHex(accentHex))
    ImportRowCard(modifier = modifier, inGroup = inGroup) {
        ArrowPreference(
            title = title,
            summary = subtitle,
            startAction = { ImportIconBadge(icon = icon, accent = accent) },
            onClick = onClick,
        )
    }
}

/**
 * 行卡容器：默认「一行一张官方 [QingyuCard]」；[inGroup] = true 时只吐行本体，
 * 由页面的分组卡统一承载。
 *
 * 为什么要这个开关：Dart 侧入口页的两组行各自在一个 `HyperosListGroup` 里
 * （`course_import_entry_screen.dart` 四种导入方式一张卡、
 * `import_random_color_toggle.dart` 开关 + 选组行一张卡），而「一行一张卡」是迁移期
 * 的近似做法（六张卡摊开，看着像一排按钮，不像设置组）。卡里再套卡会出现双重底色，
 * 所以只能由外卡承载、行本体重用。
 */
@Composable
private fun ImportRowCard(
    modifier: Modifier,
    inGroup: Boolean,
    content: @Composable () -> Unit,
) {
    if (inGroup) {
        // 分组态：外层 Card 已经给了 12dp 横向留白，这里不要再套卡、也不要再吃 modifier。
        content()
    } else {
        QingyuCard(modifier = modifier.fillMaxWidth()) { content() }
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
    inGroup: Boolean = false,
) {
    val accent = Color(parseImportAccentHex(accentHex))
    ImportRowCard(modifier = modifier, inGroup = inGroup) {
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
    inGroup: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    ImportRowCard(modifier = modifier, inGroup = inGroup) {
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
            // 卡内刻度照发布版 `HyperosControlCardScope`：左右 16 / 上 16 / 下 12
            //（底部比常规少 4dp，否则最后一行下面会多一条「下厚上薄」的死白）。
            insideMargin = ImportGuideCardInsideMargin,
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = ImportStrings.applicableScenarioTitle.text,
                    // Dart `HyperosTypography.title`（= listTitle）= 17sp / w400 → textStyles.main。
                    style = MiuixTheme.textStyles.main,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = scenarioIntro,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = ImportGuideCaptionLineHeight,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    // Dart `HyperosTokens.titleCaptionGap` = 3dp。
                    modifier = Modifier.padding(top = 3.dp),
                )
                // Dart `HyperosControlCard`：头部（标题 + 副标题）与正文之间 12dp。
                Spacer(modifier = Modifier.height(12.dp))
                ImportGuideLine(ImportStrings.stepLabel.filled("step", "1"), step1Subtitle)
                Spacer(modifier = Modifier.height(10.dp))
                ImportGuideLine(ImportStrings.stepLabel.filled("step", "2"), step2Subtitle)
                Spacer(modifier = Modifier.height(10.dp))
                ImportGuideLine(ImportStrings.stepLabel.filled("step", "3"), step3Subtitle)
            }
        }
        // Dart 两张卡之间是 `HyperosSectionGap`（12dp）。
        Spacer(modifier = Modifier.height(12.dp))
        QingyuCard(
            modifier = Modifier.fillMaxWidth(),
            insideMargin = ImportGuideCardInsideMargin,
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = ImportStrings.supportedFilesTitle.text,
                    style = MiuixTheme.textStyles.main,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = supportedFilesSuffix,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = ImportGuideCaptionLineHeight,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    // 头部 ↔ 正文同样 12dp（发布版这一卡没有副标题，直接接正文）。
                    modifier = Modifier.padding(top = 12.dp),
                )
                if (supportedFilesExtra != null) {
                    Text(
                        text = supportedFilesExtra,
                        style = MiuixTheme.textStyles.footnote1,
                        lineHeight = ImportGuideCaptionLineHeight,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}

/** 引导卡内边距：左右 16 / 上 16 / 下 12（Dart `HyperosControlCardScope` 的三个默认值）。 */
private val ImportGuideCardInsideMargin = PaddingValues(
    start = 16.dp,
    top = 16.dp,
    end = 16.dp,
    bottom = 12.dp,
)

/** 卡内说明句行高：Dart `sectionDescription` 是 13sp × 1.5 ≈ 20sp（原 18 偏挤）。 */
private val ImportGuideCaptionLineHeight = 20.sp

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
                // Dart listDetail = 14sp（textStyles.body2）；原来 13sp 比徽标小一圈。
                style = MiuixTheme.textStyles.body2,
                color = primary,
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                // Dart listTitle = 17sp / w400：与卡标题同阶（原 14sp + MEDIUM 小一号又偏粗）。
                style = MiuixTheme.textStyles.main,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                // Dart listDetail = 14sp，行高 1.4 ≈ 20sp（原 13sp / 18sp 偏小偏挤）。
                style = MiuixTheme.textStyles.body2,
                lineHeight = ImportGuideCaptionLineHeight,
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
                // D1 加载态统一（规格：美化一 `2026-11-10-loading-state-unification.md` 第 14 行
                // 本文件 :365 → B1）：发布版按钮内是 16dp / 线宽 2，颜色取按钮自己的
                // contentColor（禁用态即 disabledContentColor）。原来 18dp 且吃默认主色，
                // 在 primary 蓝底按钮上是「蓝底蓝圈」，等于看不见。
                // 颜色取按钮自己的 contentColor（主色按钮上即 onPrimary 白；禁用态跟着降）。
                QingyuLoadingInButton()
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
    val maxBodyHeight = rememberSheetMaxHeight(0.5f)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = show,
        title = ImportStrings.spreadsheetImportWarningsTitle.text,
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
                        text = ImportStrings.spreadsheetImportWarningsMessage.text,
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
                    label = ImportStrings.cancelAction.text,
                    onClick = onDismiss,
                    secondary = true,
                    modifier = Modifier.weight(1f),
                )
                ImportActionButton(
                    label = ImportStrings.spreadsheetImportWarningsContinue.text,
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
        title = ImportStrings.importReplaceExistingTitle.text,
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // 正文限高可滚：学期映射两行 + 替换说明在小屏/大字号下可能撑出弹窗
            //（审核报告 P1 旧 :520 三个对话框里最后没改到的这条），动作按钮留在滚动区外。
            val maxBodyHeight = rememberSheetMaxHeight(0.5f)
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
                                title = ImportStrings.importSemesterStartDateTitle.text,
                                subtitle = ImportStrings.importSemesterStartDateSubtitle.text,
                                value = ImportSharedModel.importFormatDate(start),
                                onDecrease = { startDate = start.minusDays(7) },
                                onIncrease = { startDate = start.plusDays(7) },
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            ImportStepperRow(
                                title = ImportStrings.importFirstCourseWeekMappingLabel.text,
                                subtitle = ImportStrings.importFirstCourseWeekMappingSubtitle.text,
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
                                    ImportStrings.importSemesterMappingNoShiftHint.text
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
                                text = ImportStrings.importReplaceExistingGuidance.text,
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
                    label = ImportStrings.cancelAction.text,
                    onClick = onCancel,
                    secondary = true,
                )
                Spacer(modifier = Modifier.height(12.dp))
                ImportActionButton(
                    label = ImportStrings.courseImportUpdateRecommendedAction.text,
                    onClick = {
                        onConfirm(ImportPreviewChoice(choiceStart, firstWeek, replaceExisting = false))
                    },
                    secondary = true,
                )
                Spacer(modifier = Modifier.height(12.dp))
                ImportActionButton(
                    label = ImportStrings.courseImportOverwriteAction.text,
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
                        label = ImportStrings.cancelAction.text,
                        onClick = onCancel,
                        secondary = true,
                        modifier = Modifier.weight(1f),
                    )
                    ImportActionButton(
                        label = ImportStrings.spreadsheetImportWarningsContinue.text,
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
        title = ImportStrings.courseImportSectionCountInsufficientTitle.text,
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
                    label = ImportStrings.cancelAction.text,
                    onClick = onCancel,
                    secondary = true,
                    modifier = Modifier.weight(1f),
                )
                ImportActionButton(
                    label = ImportStrings.courseImportAutoFillAndImportAction.text,
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
    val maxListHeight = rememberSheetMaxHeight(0.5f)
    QingyuSheet(
        show = show,
        title = ImportStrings.importRandomColorGroupTitle.text,
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
        // 只读色点的直径 / 间距走共享刻度（发布版 `import_random_color_toggle.dart`：
        // `width/height: 14` + `SizedBox(width: 4)`），与可选色块（42/40/36/32）不是一套。
        horizontalArrangement = Arrangement.spacedBy(QingyuColorPreviewDotGap),
    ) {
        (hexes.indices step stride).take(10).forEach { index ->
            Box(
                modifier = Modifier
                    .size(QingyuColorPreviewDotSize)
                    .clip(CircleShape)
                    .background(parseHexColorOrFallback(hexes[index])),
            )
        }
    }
}
