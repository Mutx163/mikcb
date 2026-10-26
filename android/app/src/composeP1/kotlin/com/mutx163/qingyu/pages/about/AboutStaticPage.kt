package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 关于页「静态信息区」· Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/about_screen.dart:296-450` 的三段列表：
 * 支持与更新 / 产品 / 社区。**不含**该页的更新检查、下载渠道、镜像探测与更新日志
 * （那约 2298 行是独立一批）。
 *
 * ## 组件选择
 *
 * Scaffold / Card / Text 全部官方 `miuix.kmp.basic.*`，不自绘。列表行用 Card + Row
 * 组合（0.8.8 无 preference 模块，官方 Preference 行不可用，见
 * `docs/plans/2026-10-26-compose-phase3-prep.md`）。
 *
 * 行右侧的箭头与行左图标：0.8.8 的 `miuix-icons` 里只有 ArrowRight / ArrowUpDown /
 * Check / Search 四个基础图标，本项目用到的 `free_breakfast / chat_bubble / history …`
 * 均无对应物，自绘图标属白名单外，因此本批**不画图标**，用文字层级区分行；
 * 待 Phase 3 后续批次评估图标来源（`miuix-icons` 0.9.4 或自带矢量）再补。
 */
@Composable
fun AboutStaticPage(
    onBack: () -> Unit,
    onEntryClick: (AboutInfoEntry) -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val sections = aboutInfoSections()

    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "返回",
                    fontSize = 15.sp,
                    color = colors.primary,
                    modifier = Modifier.clickable { onBack() },
                )
                Text(
                    text = "关于",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                )
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                for (section in sections) {
                    item(key = "section-${section.label}") {
                        SectionLabel(section.label)
                    }
                    items(section.entries) { entry ->
                        EntryRow(entry = entry, onClick = { onEntryClick(entry) })
                    }
                }
            }
        }
    }
}

/** 分组小标题（Dart `HyperosSectionLabel`）。 */
@Composable
private fun SectionLabel(label: String) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = label,
        fontSize = 13.sp,
        color = colors.onSurfaceVariantSummary,
        modifier = Modifier.padding(start = 4.dp, top = 12.dp, bottom = 2.dp),
    )
}

/** 一行：标题 + 副标题。点开要么跳页、要么弹说明层，由 [AboutInfoEntry.bullets] 区分。 */
@Composable
private fun EntryRow(
    entry: AboutInfoEntry,
    onClick: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onClick() },
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Column {
            Text(
                text = entry.title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = colors.onSurface,
            )
            Text(
                text = entry.subtitle,
                fontSize = 12.sp,
                lineHeight = 18.sp,
                color = colors.onSurfaceVariantSummary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

/**
 * 说明层内容（Dart `_showInfoSheet` 的正文）。
 *
 * 渲染层只提供内容组件，弹层的壳（OverlayDialog / BottomSheet）由宿主页面决定，
 * 便于与 miuix 的弹层系统在 Phase 3 统一接线。
 */
@Composable
fun AboutInfoSheetContent(entry: AboutInfoEntry) {
    val colors = MiuixTheme.colorScheme
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = entry.title,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.onSurface,
        )
        Text(
            text = entry.subtitle,
            fontSize = 13.sp,
            color = colors.onSurfaceVariantSummary,
        )
        for (bullet in entry.bullets) {
            Text(
                text = "· $bullet",
                fontSize = 14.sp,
                lineHeight = 20.sp,
                color = colors.onSurface,
            )
        }
    }
}
