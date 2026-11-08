package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Download
import top.yukonga.miuix.kmp.icon.extended.Forward
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 临时测试课程页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/live_testing_fixture_screen.dart`：安装 / 清除 24 时段测试课表、
 * 选课前提前量、一键发送当前/下一节次、按节次网格发送。入口只挂在诊断包
 * （`.debug` / `.profile`），正式版不展示。
 *
 * 布局与取值来自 [LiveFixtureViewState]，点击一律回调出去（装课/清除/触发都是 IO，
 * 由页面壳接 `LiveTestingFixtureService`）；本层不做业务计算。
 *
 * ## 版面结构（2026-11-08 重排）
 *
 * 四组一律是「分组标题 + 内容 +（可选）整宽说明」，标题全走 [QingyuSectionTitle]：
 *
 * | 组 | 内容 | 说明 |
 * |---|---|---|
 * | 快捷测试课表 | 安装 / 清除 两行 | 当前方案 + 测试完先清除的后果 |
 * | 课前提醒 | [TabRow] 分段控件（直接落在页底） | 提前多久进入课前态 |
 * | 一键发送 | 当前节次 / 下一节次 两行 | 什么情况下提示无课 |
 * | 按节次发送 | 四列节次格 | 没有节次表时的空态 |
 *
 * 重排前的两个毛病（2026-11-08 用户实报「很乱很奇怪」）：
 *
 * 1. 「课前提醒」「按节次发送」的标题写在**卡片里面**（body1 加粗），另两组标题在卡外
 *    （[QingyuSectionTitle]，subtitle 14sp 次要色）⇒ 同一页两套标题，卡片还一层套一层。
 * 2. 整宽说明（13sp 次要色）紧贴在下一张卡上方 8dp，跟下一组的卡标题糊成一团；
 *    它和 [QingyuSectionTitle] 只差 1sp、同色，读起来像「又一个标题」。
 *
 * 所以：标题只留在卡外一处，说明一律挂在**它解释的那块内容下面**（组内），
 * 组间由 [QingyuSectionGap] 拉开；说明与内容之间只留 6dp，说明不会飘到下一组头上。
 */
@Composable
fun LiveTestingFixturePage(
    viewState: LiveFixtureViewState,
    onBack: () -> Unit,
    onInstall: () -> Unit,
    onClear: () -> Unit,
    onSelectLead: (Int) -> Unit,
    onTriggerSection: (sectionNumber: Int, source: String) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    // Dart live_testing_fixture_screen.dart 走 HyperosSubpage，标题是纯 Text ⇒ 可折叠大标题。
    // 骨架与滚动容器都走共享套件（见 docs/reference/compose-page-style-rules.md §三）。
    QingyuPageScaffold(
        title = viewState.pageTitle,
        onBack = onBack,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(bottom = 24.dp),
        ) {
            // ── 快捷测试课表 ──
            item(key = "quick-grid") {
                FixtureSection(
                    title = LiveFixtureStrings.quickGridSection,
                    description = viewState.schemeDescription,
                    dark = dark,
                ) {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        FixtureActionRow(
                            icon = MiuixIcons.Download,
                            // Dart `HyperosListTile(iconAccent: HyperosIconColors.indigo)`
                            iconTint = Color(QingyuIconColors.INDIGO),
                            title = viewState.installTitle,
                            details = viewState.installDetails,
                            enabled = viewState.installEnabled,
                            onClick = onInstall,
                            dark = dark,
                        )
                        FixtureActionRow(
                            icon = MiuixIcons.Delete,
                            iconTint = Color(QingyuIconColors.ORANGE),
                            title = viewState.clearTitle,
                            details = viewState.clearDetails,
                            enabled = viewState.clearEnabled,
                            onClick = onClear,
                            dark = dark,
                        )
                    }
                }
            }

            // ── 课前提醒档位 ──
            item(key = "lead") {
                FixtureSection(
                    title = LiveFixtureStrings.leadSection,
                    description = LiveFixtureStrings.leadSubtitle,
                    dark = dark,
                ) {
                    // 分段控件直接落在页底上（官方 `TabRowDemo.kt:40-46` 就是这么用的）：
                    // 塞进白卡会变成「灰底条 + 白卡」两层容器，而且卡内 14dp 内边距把每个
                    // 档位挤到 56dp 文字宽——大字号下「1 分钟」会被截成「1 分…」。
                    // 左右各让 12dp 与卡片同轴，宽度回到 376dp 后四个档位都放得下。
                    TabRow(
                        tabs = viewState.leadTabs,
                        selectedTabIndex = viewState.leadIndex,
                        onTabSelected = { index ->
                            viewState.leadOptions.getOrNull(index)?.let(onSelectLead)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                    )
                }
            }

            // ── 一键发送 ──
            item(key = "send") {
                FixtureSection(
                    title = LiveFixtureStrings.sendSection,
                    description = viewState.sendHint,
                    dark = dark,
                ) {
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = QingyuPageCardMargin),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        viewState.sendRows.forEachIndexed { index, row ->
                            FixtureActionRow(
                                icon = if (index == 0) MiuixIcons.Play else MiuixIcons.Forward,
                                // Dart：play_circle_outline 蓝 / skip_next 紫
                                iconTint = if (index == 0) {
                                    Color(QingyuIconColors.BLUE)
                                } else {
                                    Color(QingyuIconColors.PURPLE)
                                },
                                title = row.title,
                                details = row.details,
                                enabled = row.enabled,
                                onClick = { onTriggerSection(row.sectionNumber, row.source) },
                                dark = dark,
                            )
                        }
                    }
                }
            }

            // ── 按节次发送 ──
            item(key = "grid") {
                val empty = viewState.gridCells.isEmpty()
                FixtureSection(
                    title = LiveFixtureStrings.gridSection,
                    // 没有节次表时不留一张空卡：只有标题和这句说明。
                    description = if (empty) viewState.gridEmptyText else null,
                    dark = dark,
                ) {
                    if (!empty) {
                        QingyuCard(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = QingyuPageCardMargin),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                // 每行 4 格（Dart `crossAxisCount: 4`）；不用嵌套滚动网格。
                                viewState.gridCells.chunked(4).forEach { rowCells ->
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                                    ) {
                                        rowCells.forEach { cell ->
                                            FixtureSectionCell(
                                                cell = cell,
                                                onClick = {
                                                    onTriggerSection(
                                                        cell.sectionNumber,
                                                        LiveFixtureStrings.sourceGrid,
                                                    )
                                                },
                                                dark = dark,
                                                modifier = Modifier.weight(1f),
                                            )
                                        }
                                        // 末行不足 4 格时补空位，保持等宽。
                                        repeat(4 - rowCells.size) {
                                            Column(modifier = Modifier.weight(1f)) {}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * 一组 = 分组标题 + 内容 +（可选）整宽说明。
 *
 * 间距口径：标题自带 8dp 上下留白（官方 `SmallTitle` 的 `InsideMargin`），组末再留
 * [QingyuSectionGap] ⇒「上一组末尾 → 下一组标题」= 8 + 12 = 20dp，组内「标题 → 内容」
 * = 8dp。层级一眼能看出来，不会像重排前那样 Card 和下一段说明只隔 8dp。
 *
 * 说明固定挂在内容下面（6dp），因为它解释的正是上面那块；放到下一组头上就变成
 * 「下一组没头没脑的一段灰字」。
 */
@Composable
private fun FixtureSection(
    title: String,
    dark: Boolean,
    description: String? = null,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = QingyuSectionGap),
    ) {
        QingyuSectionTitle(title)
        content()
        description?.let { SectionDescription(text = it, dark = dark) }
    }
}

/** 安装 / 清除 / 发送这类行（Dart `HyperosListTile`）。禁用态整行不响应点击、文字变淡。 */
@Composable
private fun FixtureActionRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    title: String,
    details: String?,
    enabled: Boolean,
    onClick: () -> Unit,
    dark: Boolean,
) {
    val titleColor = if (enabled) {
        Color(QingyuTheme.primaryText(dark))
    } else {
        Color(QingyuTheme.secondaryText(dark))
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .let { if (enabled) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            // 禁用整行变灰时图标跟着褪色，否则一行里只有图标还亮着。
            tint = if (enabled) iconTint else Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = title,
            style = MiuixTheme.textStyles.body1,
            color = titleColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        details?.let {
            Text(
                text = it,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 网格里的一节（Dart `_QuickFixtureSectionCell`）：当前节用主题色反白。
 *
 * 三行（节次 / 钟点 / 徽标）**每一格都占满**：没装也没到当前节时徽标位留空行。
 * 重排前只有装了或当前节才有第三行，`Center` 居中后同一排里两行格子和三行格子
 * 的钟点高低不一——一眼看过去整片格子在跳。留空行后六排的钟点全在一条线上。
 *
 * 高度给 `heightIn(min = 74.dp)`（Dart 是 `childAspectRatio: 1.15`，约 74dp）而不是
 * 写死 64dp：写死时三行字加大字号必然超出，字号 1.3 档下钟点被压成「00…」。
 */
@Composable
private fun FixtureSectionCell(
    cell: LiveFixtureSectionCell,
    onClick: () -> Unit,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val background = if (cell.isCurrent) {
        Color(QingyuTheme.primary(dark = dark))
    } else {
        Color(QingyuTheme.card(dark))
    }
    val titleColor = if (cell.isCurrent) {
        Color(QingyuTheme.onAccent(dark))
    } else {
        Color(QingyuTheme.primaryText(dark))
    }
    val captionColor = if (cell.isCurrent) {
        Color(QingyuTheme.onAccent(dark)).copy(alpha = 0.86f)
    } else {
        Color(QingyuTheme.secondaryText(dark))
    }

    Column(
        modifier = modifier
            .heightIn(min = 74.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = cell.title,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(
                if (cell.isCurrent) QingyuWeightDelta.SEMIBOLD else QingyuWeightDelta.MEDIUM,
            ),
            color = titleColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = cell.startTime,
            style = MiuixTheme.textStyles.footnote2,
            color = captionColor,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
        // 徽标位固定占一行：见上方注释，靠它把各格钟点压在同一条基线上。
        Text(
            text = cell.badgeLabel.orEmpty(),
            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = captionColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** 灰字说明（Dart `HyperosSectionDescription`）：挂在所解释的内容下面 6dp。 */
@Composable
private fun SectionDescription(text: String, dark: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = Color(QingyuTheme.secondaryText(dark)),
        // 与分组标题的 28dp 轴线对齐（Card 外边距 12 + 行内 16）。
        modifier = Modifier.padding(
            start = QingyuPageCardMargin + 16.dp,
            top = 6.dp,
            end = QingyuPageCardMargin + 16.dp,
        ),
    )
}

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 状态一律由同包的真装配函数 `buildLiveFixtureViewState` 算，节次表用
// `LiveTestingFixtureData.buildHourlySections()`、测试课用 `buildSlotTemplate(...)`，
// 所以「当前节 / 下一节 / 已装徽标」都是真算出来的，预览里不手写假节次。
//
// 远端类（`widgetdata`）用全限定名调用：本文件的 import 块按预览约定只允许动三行
// （`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览基准时刻：周日上午 9:10（第 10 节）。 */
private val previewFixtureNow: java.time.LocalDateTime = java.time.LocalDateTime.of(2026, 11, 8, 9, 10)

/** 24 小时快捷测试节次表（与页面「安装 24 时段测试课表」同一份）。 */
private val previewFixtureSections = com.mutx163.qingyu.widgetdata.LiveTestingFixtureData.buildHourlySections()

/** 已安装的测试课：第 1~3 节。 */
private val previewFixtureCourses = (1..3).map { sectionNumber ->
    com.mutx163.qingyu.widgetdata.LiveTestingFixtureData.buildSlotTemplate(
        sectionNumber = sectionNumber,
        section = previewFixtureSections[sectionNumber - 1],
        dayOfWeek = 7,
        semesterWeekCount = 20,
    )
}

private fun previewFixtureState(name: String): LiveFixtureViewState = when (name) {
    "未安装" -> buildLiveFixtureViewState(
        sections = previewFixtureSections,
        courses = emptyList(),
        activeSchemeName = "标准作息",
        now = previewFixtureNow,
    )
    "安装中" -> buildLiveFixtureViewState(
        sections = previewFixtureSections,
        courses = emptyList(),
        activeSchemeName = "标准作息",
        now = previewFixtureNow,
        isInstalling = true,
    )
    else -> buildLiveFixtureViewState(
        sections = previewFixtureSections,
        courses = previewFixtureCourses,
        activeSchemeName = "标准作息",
        now = previewFixtureNow,
    )
}

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewLiveFixtureBody(
    state: LiveFixtureViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        LiveTestingFixturePage(
            viewState = state,
            onBack = {},
            onInstall = {},
            onClear = {},
            onSelectLead = {},
            onTriggerSection = { _, _ -> },
        )
    }
}

@Suppress("unused")
@Preview(name = "1 已安装", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewLiveFixtureInstalled() {
    PreviewLiveFixtureBody(previewFixtureState("已安装"))
}

@Suppress("unused")
@Preview(name = "2 未安装", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewLiveFixtureNotInstalled() {
    PreviewLiveFixtureBody(previewFixtureState("未安装"))
}

@Suppress("unused")
@Preview(name = "3 安装中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewLiveFixtureInstalling() {
    PreviewLiveFixtureBody(previewFixtureState("安装中"))
}

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewLiveFixtureDark() {
    PreviewLiveFixtureBody(previewFixtureState("已安装"), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewLiveFixtureLargeText() {
    PreviewLiveFixtureBody(previewFixtureState("已安装"), textScale = 1.3f)
}
