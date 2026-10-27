package com.mutx163.qingyu.pages.import

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageTheme
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
import top.yukonga.miuix.kmp.basic.Switch
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

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
    // 每个页面实例一个折叠状态：返回后重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = title,
                    largeTitle = title,
                    scrollBehavior = scrollBehavior,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = "返回",
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
            bottomBar = {
                if (bottomBar != null) {
                    // Dart 侧底部按钮区：SafeArea(minimum: fromLTRB(16, 12, 16, 16))，
                    // 底色就是页面背景（HyperosSubpage 的 body），不是独立 surface。
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(QingyuTheme.scaffoldBackground(dark)))
                            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 16.dp),
                    ) {
                        bottomBar()
                    }
                }
            },
        ) { innerPadding ->
            content(innerPadding, scrollBehavior)
        }
    }
}

/** 分组小标题（Dart `HyperosSectionLabel`）：13sp / 次要文字色，与设置族同档。 */
@Composable
fun ImportSectionLabel(text: String, modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    Text(
        text = text,
        fontSize = 13.sp,
        color = Color(QingyuTheme.sectionLabel(dark)),
        modifier = modifier.padding(start = 4.dp, top = 12.dp, bottom = 4.dp),
    )
}

/**
 * 导航行（Dart `HyperosNavTile` + `ImportIconBadge`）：36dp 图标徽标 + 标题 / 副标题
 * + 行尾箭头。用 [Card] 的 `onClick` 重载拿官方按压反馈，不用 `Modifier.clickable`。
 */
@Composable
fun ImportNavRow(
    title: String,
    subtitle: String,
    icon: ImageVector,
    accentHex: String,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val accent = Color(parseImportAccentHex(accentHex))
    Card(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ImportIconBadge(icon = icon, accent = accent)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
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
 * 开关行（Dart `HyperosSwitchTile`）：与 [ImportNavRow] 同一骨架，行尾换 [Switch]。
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
) {
    val dark = isSystemInDarkTheme()
    val accent = Color(parseImportAccentHex(accentHex))
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ImportIconBadge(icon = icon, accent = accent)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            Switch(
                checked = checked,
                onCheckedChange = if (enabled) onCheckedChange else null,
            )
        }
    }
}

/**
 * 取值行（Dart `HyperosListTile(title, details, onTap)`）：标题 + 行尾当前取值。
 * [enabled] = false 时不显示行尾箭头、点击无响应（Dart `onTap: null`）。
 */
@Composable
fun ImportValueRow(
    title: String,
    value: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = if (enabled) onClick else null,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = title,
                fontSize = 16.sp,
                color = Color(
                    if (enabled) QingyuTheme.primaryText(dark) else QingyuTheme.secondaryText(dark),
                ),
                modifier = Modifier.weight(1f),
            )
            Text(
                text = value,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            if (enabled) {
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        }
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
) {
    val dark = isSystemInDarkTheme()
    Column(modifier = Modifier.fillMaxWidth()) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Text(
                    text = ImportStrings.applicableScenarioTitle.zh,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = scenarioIntro,
                    fontSize = 12.sp,
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
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Text(
                    text = ImportStrings.supportedFilesTitle.zh,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = supportedFilesSuffix,
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(top = 6.dp),
                )
                if (supportedFilesExtra != null) {
                    Text(
                        text = supportedFilesExtra,
                        fontSize = 12.sp,
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
                fontSize = 12.sp,
                color = primary,
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = subtitle,
                fontSize = 12.sp,
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
        // Dart HyperosButtonVariant.secondary：浅底 + 主色文字（与 AI 导入页同款取法）。
        Button(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            enabled = enabled && !loading,
            colors = ButtonDefaults.buttonColors(
                color = MiuixTheme.colorScheme.surfaceVariant,
                contentColor = MiuixTheme.colorScheme.primary,
            ),
        ) { content() }
    } else {
        Button(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            enabled = enabled && !loading,
        ) { content() }
    }
}

/**
 * 替换选择对话框（Dart `askImportReplaceExisting` → `showAppTripleActionDialog`）。
 *
 * 三个动作：取消 / 更新课表（推荐）/ 覆盖导入。Dart 在正文末尾固定拼接一段引导句，
 * 该句**不在 ARB 里**（源文件硬编码），所以照抄为下面的私有常量。
 */
@Composable
fun ImportReplaceExistingDialog(
    show: Boolean,
    title: String,
    message: String,
    onCancel: () -> Unit,
    onUpdate: () -> Unit,
    onOverwrite: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    OverlayDialog(
        show = show,
        title = title,
        onDismissRequest = onCancel,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = message,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = IMPORT_REPLACE_EXISTING_GUIDANCE,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(16.dp))
            ImportActionButton(
                label = ImportStrings.courseImportOverwriteAction.zh,
                onClick = onOverwrite,
            )
            Spacer(modifier = Modifier.height(8.dp))
            ImportActionButton(
                label = ImportStrings.courseImportUpdateRecommendedAction.zh,
                onClick = onUpdate,
                secondary = true,
            )
            Spacer(modifier = Modifier.height(8.dp))
            ImportActionButton(
                label = ImportStrings.cancelAction.zh,
                onClick = onCancel,
                secondary = true,
            )
        }
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
    OverlayDialog(
        show = show,
        title = ImportStrings.spreadsheetImportWarningsTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = ImportStrings.spreadsheetImportWarningsMessage.zh,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(modifier = Modifier.height(12.dp))
            for (warning in warnings) {
                Text(
                    text = "• $warning",
                    fontSize = 13.sp,
                    lineHeight = 19.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(bottom = 6.dp),
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            ImportActionButton(
                label = ImportStrings.spreadsheetImportWarningsContinue.zh,
                onClick = onContinue,
            )
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

/** Dart `askImportReplaceExisting` 正文末尾的固定引导句（硬编码，不在 ARB）。 */
private const val IMPORT_REPLACE_EXISTING_GUIDANCE =
    "日常更新建议优先选择更新课表，保留本地独有课程并合并新课程"
