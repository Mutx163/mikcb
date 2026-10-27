package com.mutx163.qingyu.pages.diagnostics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.SmallTitle
import top.yukonga.miuix.kmp.basic.TabRow
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Download
import top.yukonga.miuix.kmp.icon.extended.Forward
import top.yukonga.miuix.kmp.icon.extended.Play

/**
 * 临时测试课程页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/live_testing_fixture_screen.dart`：安装 / 清除 24 时段测试课表、
 * 选课前提前量、一键发送当前/下一节次、按节次网格发送。入口只挂在诊断包
 * （`.debug` / `.profile`），正式版不展示。
 *
 * 布局与取值来自 [LiveFixtureViewState]，点击一律回调出去（装课/清除/触发都是 IO，
 * 由页面壳接 `LiveTestingFixtureService`）；本层不做业务计算。
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

    Scaffold(containerColor = Color(QingyuTheme.scaffoldBackground(dark))) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            TopAppBar(
                title = viewState.pageTitle,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = DiagnosticsStrings.closeAction.zh,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // ── 快捷测试课表 ──
                item { SmallTitle(text = LiveFixtureStrings.quickGridSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        FixtureActionRow(
                            icon = MiuixIcons.Download,
                            title = viewState.installTitle,
                            details = viewState.installDetails,
                            enabled = viewState.installEnabled,
                            onClick = onInstall,
                            dark = dark,
                        )
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                        FixtureActionRow(
                            icon = MiuixIcons.Delete,
                            title = viewState.clearTitle,
                            details = viewState.clearDetails,
                            enabled = viewState.clearEnabled,
                            onClick = onClear,
                            dark = dark,
                        )
                    }
                }
                item {
                    SectionDescription(text = viewState.schemeDescription, dark = dark)
                }

                // ── 课前提醒档位 ──
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        Text(
                            text = LiveFixtureStrings.leadSection,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Text(
                            text = LiveFixtureStrings.leadSubtitle,
                            fontSize = 12.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.padding(top = 2.dp, bottom = 8.dp),
                        )
                        TabRow(
                            tabs = viewState.leadTabs,
                            selectedTabIndex = viewState.leadIndex,
                            onTabSelected = { index ->
                                viewState.leadOptions.getOrNull(index)?.let(onSelectLead)
                            },
                        )
                    }
                }

                // ── 一键发送 ──
                item { SmallTitle(text = LiveFixtureStrings.sendSection) }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 4.dp),
                    ) {
                        viewState.sendRows.forEachIndexed { index, row ->
                            if (index > 0) {
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 14.dp))
                            }
                            FixtureActionRow(
                                icon = if (index == 0) MiuixIcons.Play else MiuixIcons.Forward,
                                title = row.title,
                                details = row.details,
                                enabled = row.enabled,
                                onClick = { onTriggerSection(row.sectionNumber, row.source) },
                                dark = dark,
                            )
                        }
                    }
                }
                item { SectionDescription(text = viewState.sendHint, dark = dark) }

                // ── 按节次发送 ──
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        Text(
                            text = LiveFixtureStrings.gridSection,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        if (viewState.gridCells.isEmpty()) {
                            Text(
                                text = viewState.gridEmptyText,
                                fontSize = 12.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(top = 6.dp),
                            )
                        } else {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 10.dp),
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

/** 安装 / 清除 / 发送这类行（Dart `HyperosListTile`）。禁用态整行不响应点击、文字变淡。 */
@Composable
private fun FixtureActionRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
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
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = title,
            fontSize = 16.sp,
            color = titleColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        details?.let {
            Text(
                text = it,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** 网格里的一节（Dart `_QuickFixtureSectionCell`）：当前节用主题色反白。 */
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
            .height(64.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 6.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = cell.title,
            fontSize = 13.sp,
            fontWeight = if (cell.isCurrent) FontWeight.SemiBold else FontWeight.Medium,
            color = titleColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = cell.startTime,
            fontSize = 11.sp,
            color = captionColor,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
        cell.badgeLabel?.let { badge ->
            Text(
                text = badge,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = captionColor,
                maxLines = 1,
            )
        }
    }
}

/** 灰字说明（Dart `HyperosSectionDescription`）。 */
@Composable
private fun SectionDescription(text: String, dark: Boolean) {
    Text(
        text = text,
        fontSize = 12.sp,
        lineHeight = 17.sp,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier.padding(horizontal = 4.dp),
    )
}
