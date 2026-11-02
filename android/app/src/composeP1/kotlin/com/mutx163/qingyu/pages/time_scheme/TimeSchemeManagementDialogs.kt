package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 时间模板管理页的**全部弹层**（渲染层）。
 *
 * 与页面一样，本文件只摆像素 + 上报意图：显隐由宿主 `app/TimeSchemeHost.kt` 的
 * `TimeSchemeDialog` 状态机控制，落盘写入口也都在宿主。入参为 `null` = 不显示
 * （与 `TimeSchemeManagementPage` 的「纯函数」姿势一致）。
 *
 * ## 五个弹层各自对 Dart 的哪一段
 *
 * | 弹层 | Dart 来源 | 容器 | 为什么是这个容器 |
 * |---|---|---|---|
 * | `TimeSchemeMenuSheet` | `_openSchemeMenu`（:286-345）的条目顺序与出现条件 | `QingyuSheet`（共享底部弹层封装） | Dart 是锚点变形菜单（`HyperosAnchorMenuPopup`），需要按钮的窗口坐标；渲染层拿不到锚点坐标（那是宿主的事），所以退成官方底部动作表——同样是「从下方来的一列动作」，且不新造菜单组件 |
 * | `TimeSchemeNameSheet` | `_createScheme`（:571-612）/ `_renameScheme`（:614-658） | `OverlayDialog` | Dart `showAppTextInputDialog` 是居中对话框（标题 + 输入框 + 两个动作） |
 * | `TimeSchemeDeleteSheet` | `_deleteScheme`（:660-719）的确认框 | `OverlayDialog` | Dart `showHyperosConfirmDialog` 是居中对话框 |
 * | `TimeSchemeDeleteBlockedSheet` | `_explainDeleteBlocked`（:725-812） | `OverlayDialog` | 同上（`showHyperosDialog`），正文是占用清单，不是动作表 |
 * | `TimeSchemeUsageSheet` | `_showUsageDetails`（:1018-1179） | `OverlayDialog`（内容自己滚） | Dart 就是 `showHyperosDialog` + `SingleChildScrollView`；这里用官方 `LazyColumn` 三件套里的两件（`scrollEndHaptic` + `overScrollVertical`）承载可能很长的引用清单 |
 * | `TimeSchemeShareSheetDialog` | `_shareTimeScheme`（:851-893） | `OverlayDialog` | 同上（三个动作的对话框） |
 *
 * ## 与 Dart 的已知差异（诚实清单）
 *
 * - 菜单是**底部动作表**而不是锚点变形菜单（理由见上表）；
 * - 使用情况弹层的三段固定列表在 Dart 里是「有边框的小卡」，这里用共享 `QingyuCard`
 *   （官方 `Card` 的薄封装）承载，圆角/底色随主题；
 * - `TimeSchemeShareSheet` 没有「模板名」字段（Dart 正文居中显示 `scheme.name`），
 *   所以分享弹层**不显示正文**，只显示标题与三个动作；宿主当前也未接分享（见其文件头差异表）；
 * - 新建/重命名弹层没有用 `sheet.nameHint`：miuix `TextField` 的占位与浮动标签是同一个槽位
 *   （`useLabelAsPlaceholder`），同时给会互相顶掉，这里以「标签」为准（与 `AddCoursePage` 同口径）。
 */

/**
 * 卡片「更多」菜单的一次打开会话。
 *
 * 条目在宿主打开瞬间就冻结成一份（`items`），与 Dart `_SchemeMenuSession` 同口径：
 * 弹层收起动画期间还要拿同一份条目，现算会随仓储通知变化。
 */
data class TimeSchemeMenuState(
    val schemeId: String,
    val schemeName: String,
    val items: List<TimeSchemeMenuItem>,
)

/** 卡片右上「更多」→ 动作表（Dart `_openSchemeMenu` 的 7 项，顺序由模型决定）。 */
@Composable
fun TimeSchemeMenuSheet(
    state: TimeSchemeMenuState?,
    onDismiss: () -> Unit,
    onAction: (TimeSchemeAction) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuSheet(
        show = state != null,
        // 用模板名当弹层标题：菜单里 7 个动作都作用于这一套模板，标题是唯一的上下文。
        title = state?.schemeName,
        onDismissRequest = onDismiss,
        // 内容自己给了 16dp（下面那个 Column），所以框架侧横向归零，避免叠成 32。
        contentPadsHorizontally = true,
    ) {
        val items = state?.items.orEmpty()
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            for (item in items) {
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = item.label,
                    // 删除是唯一 destructive 项（Dart `destructive: true`）：中性底 + 红字，
                    // 但**照常可点**——点它只会开对话框（有引用时说明是什么挡住了），
                    // 禁掉会读成「红字却点不动」。
                    // 注意 `textButtonColors(color = …)` 的 `color` 是**底色**（会得到整颗红底 +
                    // 默认灰字，对比度坏）；Dart 口径是中性的底 + 危险色的字 ⇒ 用 `textColor`。
                    colors = if (item.action == TimeSchemeAction.DELETE) {
                        ButtonDefaults.textButtonColors(textColor = Color(QingyuTheme.error(dark)))
                    } else {
                        ButtonDefaults.textButtonColors()
                    },
                    onClick = { onAction(item.action) },
                )
            }
            Spacer(modifier = Modifier.height(4.dp))
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = TimeSchemeManagementStrings.cancelAction.zh,
                onClick = onDismiss,
            )
        }
    }
}

/**
 * 新建 / 重命名共用的文本输入弹层（Dart `showAppTextInputDialog`）。
 *
 * 校验不在这里做：宿主拿到 `onConfirm` 的原文后调 `model.validateName`，
 * 这样「什么算合法名字」只有模型一处口径。
 */
@Composable
fun TimeSchemeNameSheet(
    sheet: TimeSchemeSheet?,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    val current = sheet
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = current != null,
        title = current?.title,
        onDismissRequest = onDismiss,
    ) {
        if (current != null) {
            var text by remember(current) { mutableStateOf(current.initialName) }
            TextField(
                value = text,
                onValueChange = { text = it },
                label = current.nameLabel,
                useLabelAsPlaceholder = true,
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
            )
            DialogActionRow(
                cancelLabel = TimeSchemeManagementStrings.cancelAction.zh,
                onCancel = onDismiss,
                confirmLabel = current.confirmLabel,
                onConfirm = { onConfirm(text) },
            )
        }
    }
}

/**
 * 删除确认框（Dart `showHyperosConfirmDialog(destructive: true)`）。
 *
 * 只有「这套模板确实能删」时宿主才会用它；有引用的那一路走
 * [TimeSchemeDeleteBlockedSheet]，所以这里没有「查看使用情况」动作
 * （`onViewUsage` 仅为契约签名保留，宿主在可删分支不会用到它）。
 */
@Composable
fun TimeSchemeDeleteSheet(
    check: TimeSchemeDeleteCheck?,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
    onViewUsage: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = check
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = current != null,
        title = current?.title,
        summary = current?.message,
        onDismissRequest = onCancel,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                if (current.inUseNote.isNotBlank()) {
                    Text(
                        text = current.inUseNote,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }
                DialogActionRow(
                    // Dart 的两个删除弹层里「取消」都用 `l10n.cancelAction`（`_deleteScheme:683` /
                    // `_explainDeleteBlocked:793`）；模型目前把 `cancelLabel` 灌成 `closeAction`
                    // （「关闭」），那是使用情况弹层的动作词，所以这里直接用 ARB 的 cancelAction。
                    cancelLabel = TimeSchemeManagementStrings.cancelAction.zh,
                    onCancel = onCancel,
                    confirmLabel = current.confirmLabel,
                    onConfirm = onConfirm,
                    destructive = true,
                    // 可删分支不出现次要动作（Dart 的确认框只有「取消 / 删除」两项）；
                    // 只有宿主误把被占用的模板塞进来时才补一条「查看使用情况」。
                    onSecondary = if (current.canDelete) null else onViewUsage,
                )
            }
        }
    }
}

/**
 * 删除被拦弹层（Dart `_explainDeleteBlocked`，:725-812）。
 *
 * 结构逐条对：抬头一句居中说明（`blockerIntro`）→ 左对齐的占用清单（每条一段，
 * 行间 8dp）→ 两个动作「取消 / 查看使用情况」。
 *
 * 不加引导圆点：Dart 注释写明「这弹层通常只有一个占用方，圆点不携带信息」，
 * 而且主色圆点在深色主题下会被读成脏点。
 */
@Composable
fun TimeSchemeDeleteBlockedSheet(
    check: TimeSchemeDeleteCheck?,
    onCancel: () -> Unit,
    onViewUsage: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = check
    // 占用清单条数无上界：正文限高 + 可滚，两个动作按钮固定在外。
    val maxBodyHeight = (LocalConfiguration.current.screenHeightDp * 0.45f).dp
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = current != null,
        title = current?.title,
        onDismissRequest = onCancel,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = maxBodyHeight)
                        .scrollEndHaptic()
                        .overScrollVertical(),
                ) {
                    if (current.blockerIntro.isNotBlank()) {
                        item(key = "intro") {
                            Text(
                                text = current.blockerIntro,
                                style = MiuixTheme.textStyles.footnote1,
                                // 抬头句沿用对话框自己的居中惯例（与 Dart 同口径）。
                                textAlign = TextAlign.Center,
                                color = Color(QingyuTheme.primaryText(dark)),
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                        }
                    }
                    items(current.blockers) { line ->
                        Text(
                            text = line,
                            style = MiuixTheme.textStyles.footnote1,
                            textAlign = TextAlign.Start,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp),
                        )
                    }
                }
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    // 同 [TimeSchemeDeleteSheet]：Dart 这里也是 `cancelAction`（「取消」），
                    // 不是使用情况弹层的 `closeAction`（「关闭」）。
                    text = TimeSchemeManagementStrings.cancelAction.zh,
                    onClick = onCancel,
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = TimeSchemeManagementStrings.viewUsageAction.zh,
                    colors = ButtonDefaults.textButtonColorsPrimary(),
                    onClick = onViewUsage,
                )
            }
        }
    }
}

/**
 * 使用情况详情（Dart `_showUsageDetails`，:1018-1179）。
 *
 * 结构逐条对：说明句 → 三个统计 chip（课表 / 课程 / 副时间模板）→ 三段**固定**列表
 * （直接绑定 / 跟随主模板 / 副时间模板，各有自己的空态句）→ 两个**有才显示**的段
 * （地点作息匹配 / 日期作息规则，副标题是「需先改绑到别的模板才能删除」）→ 「关闭」。
 *
 * 内容可能很长，所以清单部分走官方 `LazyColumn` + 两件滚动修饰（抽屉里没有顶栏，
 * 官方只挂 `scrollEndHaptic` + `overScrollVertical`，见 `BottomSheetSection.kt:209-213`）。
 */
@Composable
fun TimeSchemeUsageSheet(
    view: TimeSchemeUsageView?,
    onClose: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = view
    // 清单限高按屏高走：矮屏不再被 380dp 硬上限顶掉「关闭」按钮。
    val maxListHeight = (LocalConfiguration.current.screenHeightDp * 0.42f).dp
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = current != null,
        title = current?.title,
        onDismissRequest = onClose,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = current.intro,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Spacer(modifier = Modifier.height(12.dp))
                UsageCountChips(
                    profileLabel = current.profileCountLabel,
                    profileValue = current.profileCountValue,
                    courseLabel = current.courseCountLabel,
                    courseValue = current.courseCountValue,
                    overrideLabel = current.overrideCountLabel,
                    overrideValue = current.overrideCountValue,
                )
                Spacer(modifier = Modifier.height(16.dp))
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        // 弹窗里必须给上界，否则 LazyColumn 在无界高度里量不出来。
                        .heightIn(max = maxListHeight)
                        .scrollEndHaptic()
                        .overScrollVertical(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    item(key = "directProfiles") {
                        UsageSection(
                            title = current.directProfilesTitle,
                            subtitle = current.directProfilesSubtitle,
                            lines = current.directProfiles,
                            emptyText = current.directProfilesEmpty,
                        )
                    }
                    item(key = "followMainCourses") {
                        UsageSection(
                            title = current.followTitle,
                            subtitle = current.followSubtitle,
                            lines = current.followLines,
                            emptyText = current.followEmpty,
                        )
                    }
                    item(key = "overrideCourses") {
                        UsageSection(
                            title = current.overrideTitle,
                            subtitle = current.overrideSubtitle,
                            lines = current.overrideLines,
                            emptyText = current.overrideEmpty,
                        )
                    }
                    // 地点规则与日期规则**有才显示**（Dart `if (…isNotEmpty)`）：
                    // 常见的「只有一个占用方」场景不该长两个空盒子。
                    if (current.locationLines.isNotEmpty()) {
                        item(key = "locationGroups") {
                            UsageSection(
                                title = current.locationTitle,
                                subtitle = current.locationSubtitle,
                                lines = current.locationLines,
                                emptyText = null,
                            )
                        }
                    }
                    if (current.dateRuleLines.isNotEmpty()) {
                        item(key = "dateRules") {
                            UsageSection(
                                title = current.dateRuleTitle,
                                subtitle = current.dateRuleSubtitle,
                                lines = current.dateRuleLines,
                                emptyText = null,
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = TimeSchemeManagementStrings.closeAction.zh,
                    onClick = onClose,
                )
            }
        }
    }
}

/**
 * 分享二选一（Dart `_shareTimeScheme`，:851-893）：取消 / 二维码分享 / 系统分享文件。
 *
 * 三个动作都是「上报」，真正打包与分享在宿主。
 */
@Composable
fun TimeSchemeShareSheetDialog(
    sheet: TimeSchemeShareSheet?,
    onDismiss: () -> Unit,
    onShareSystem: () -> Unit,
    onShareQr: () -> Unit,
) {
    val current = sheet
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = current != null,
        title = current?.title,
        onDismissRequest = onDismiss,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = current.cancelLabel,
                    onClick = onDismiss,
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = current.viaQrLabel,
                    onClick = onShareQr,
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = current.viaSystemLabel,
                    colors = ButtonDefaults.textButtonColorsPrimary(),
                    onClick = onShareSystem,
                )
            }
        }
    }
}

// ────────────────────────────── 内部小件 ──────────────────────────────

/**
 * 对话框底部一行动作：左「取消」+ 右确认（Dart `HyperosDialogAction` 的排列）。
 *
 * `destructive = true` 时确认按钮走危险色（删除）；`onSecondary` 非空时在两者之间
 * 再插一个次要动作（当前只有删除确认弹层的「查看使用情况」用到，且宿主可删时不会传）。
 */
@Composable
private fun DialogActionRow(
    cancelLabel: String,
    onCancel: () -> Unit,
    confirmLabel: String,
    onConfirm: () -> Unit,
    destructive: Boolean = false,
    onSecondary: (() -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        TextButton(
            modifier = Modifier.weight(1f),
            text = cancelLabel,
            onClick = onCancel,
        )
        if (onSecondary != null) {
            TextButton(
                modifier = Modifier.weight(1f),
                text = TimeSchemeManagementStrings.viewUsageAction.zh,
                onClick = onSecondary,
            )
        }
        TextButton(
            modifier = Modifier.weight(1f),
            text = confirmLabel,
            // `destructive` 是「中性底 + 危险色的字」：`textButtonColors(color = …)` 的 `color`
            // 是**底色**（红底 + 默认灰字），所以这里必须用 `textColor`。
            colors = if (destructive) {
                ButtonDefaults.textButtonColors(textColor = Color(QingyuTheme.error(dark)))
            } else {
                ButtonDefaults.textButtonColorsPrimary()
            },
            onClick = onConfirm,
        )
    }
}

/** 三个统计 chip（Dart `_TimeSchemeInfoChip` → `HyperosTag('label value')`，横向 Wrap）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun UsageCountChips(
    profileLabel: String,
    profileValue: String,
    courseLabel: String,
    courseValue: String,
    overrideLabel: String,
    overrideValue: String,
) {
    // Dart 是 `Wrap(spacing: 8, runSpacing: 8)`：三个 chip 在窄屏上会折行。
    // 用固定 Row 会在弹窗内宽里把最后一个 chip 挤出去（三个中文 chip 合计约 320dp）。
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        UsageChip(text = "$profileLabel $profileValue")
        UsageChip(text = "$courseLabel $courseValue")
        UsageChip(text = "$overrideLabel $overrideValue")
    }
}

/** 单个统计 chip：浅底圆角，文字走官方字阶（Dart `HyperosTag` 的对应物）。 */
@Composable
private fun UsageChip(text: String) {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(Color(QingyuTheme.surfaceContainerHighest(dark)))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
            maxLines = 1,
        )
    }
}

/**
 * 使用情况里的一段（Dart `_UsageSection`）：标题 + 副标题 + 逐条带主色小圆点的引用行。
 *
 * `emptyText` 为 null 表示「这段只在有内容时出现」，不拼空态句。
 */
@Composable
private fun UsageSection(
    title: String,
    subtitle: String,
    lines: List<TimeSchemeLine>,
    emptyText: String?,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(12.dp),
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = subtitle,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(modifier = Modifier.height(10.dp))
        if (lines.isEmpty()) {
            val text = emptyText ?: subtitle
            Text(
                text = text,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        } else {
            for (line in lines) {
                UsageLineItem(line = line)
            }
        }
    }
}

/** 一条引用（Dart `_UsageLine`）：5dp 主色小圆点 + 主行 +（可选）副行。 */
@Composable
private fun UsageLineItem(line: TimeSchemeLine) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .padding(top = 6.dp)
                .size(5.dp)
                .clip(CircleShape)
                .background(Color(QingyuTheme.primary(dark = dark))),
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = line.title,
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            if (line.summary.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = line.summary,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}
