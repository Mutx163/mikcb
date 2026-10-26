package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Community
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Link
import top.yukonga.miuix.kmp.icon.extended.Messages
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Recent
import top.yukonga.miuix.kmp.icon.extended.Report
import top.yukonga.miuix.kmp.icon.extended.Update

/**
 * 关于页「静态信息区」· Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/about_screen.dart:296-450` 的三段列表：
 * 支持与更新 / 产品 / 社区。**不含**更新检查、下载渠道、镜像探测与更新日志
 * （那约 2298 行是独立一批，判据已单独移植并有测试）。
 *
 * 骨架走 [QingyuPageScaffold]（官方 TopAppBar + 返回图标），行走 [QingyuRow]
 * （官方 Card 按压反馈 + 行首图标 + 行尾箭头）；图标与配色来自模型层的
 * [AboutInfoEntry.icon] / [AboutInfoEntry.accentArgb]，与 Flutter 侧逐行对应。
 */
@Composable
fun AboutStaticPage(
    onBack: () -> Unit,
    onEntryClick: (AboutInfoEntry) -> Unit,
) {
    val sections = aboutInfoSections()

    QingyuPageScaffold(title = "关于", onBack = onBack) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = innerPadding.calculateTopPadding(),
                bottom = 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            for (section in sections) {
                item(key = "section-${section.label}") {
                    QingyuSectionLabel(section.label)
                }
                items(section.entries) { entry ->
                    QingyuRow(
                        title = entry.title,
                        subtitle = entry.subtitle,
                        icon = { RowIcon(entry) },
                        onClick = { onEntryClick(entry) },
                    )
                }
            }
        }
    }
}

/** 行首图标：矢量取自官方图标包，配色取自 Flutter 同行的彩豆。 */
@Composable
private fun RowIcon(entry: AboutInfoEntry) {
    Icon(
        imageVector = iconOf(entry.icon),
        contentDescription = null,
        tint = Color(entry.accentArgb),
    )
}

/** [AboutRowIcon] → 官方图标包里的矢量。 */
private fun iconOf(icon: AboutRowIcon) = when (icon) {
    AboutRowIcon.FAVORITES -> MiuixIcons.Favorites
    AboutRowIcon.MESSAGES -> MiuixIcons.Messages
    AboutRowIcon.UPDATE -> MiuixIcons.Update
    AboutRowIcon.RECENT -> MiuixIcons.Recent
    AboutRowIcon.NOTES -> MiuixIcons.Notes
    AboutRowIcon.INFO -> MiuixIcons.Info
    AboutRowIcon.IMPORT -> MiuixIcons.Import
    AboutRowIcon.COMMUNITY -> MiuixIcons.Community
    AboutRowIcon.LINK -> MiuixIcons.Link
    AboutRowIcon.REPORT -> MiuixIcons.Report
}

/**
 * 说明层内容（Dart `_showInfoSheet` 的正文）。
 *
 * 弹层壳（OverlayDialog / BottomSheet）由宿主页面决定，便于与官方弹层系统统一接线。
 */
@Composable
fun AboutInfoSheetContent(entry: AboutInfoEntry) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (bullet in entry.bullets) {
            QingyuRow(title = bullet)
        }
    }
}
