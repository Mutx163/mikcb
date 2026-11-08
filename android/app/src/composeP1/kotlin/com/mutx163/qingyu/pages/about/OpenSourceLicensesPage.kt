package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 开源许可页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/open_source_licenses_screen.dart`：
 * 搜索框 + 「许可说明」卡 + 组件列表（点进看全文）。
 *
 * 骨架与行都走 [QingyuPageScaffold] / [QingyuRow]（官方顶栏、官方卡片按压反馈、
 * 官方图标），不再各页手拼——第一版手拼出来的顶栏与无图标行是「廉价感」主因。
 */
@Composable
fun OpenSourceLicensesPage(
    packages: List<OpenSourcePackageLicense>,
    onBack: () -> Unit,
    onOpenPackage: (OpenSourcePackageLicense) -> Unit,
    isLoading: Boolean = false,
    loadError: String? = null,
) {
    var query by remember { mutableStateOf("") }
    val filtered = filterOpenSourcePackages(packages, query)
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(title = OpenSourceLicensesStrings.title, onBack = onBack) {
        // 列表头部有搜索输入框：imePadding 把列表抬到键盘之上（壳是 edge-to-edge）。
        QingyuPageList(
            modifier = Modifier.imePadding(),
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 官方配方：横向留白由卡片自己带（12dp），滚动条才贴得到屏幕边缘。
            horizontalPadding = QingyuPageCardMargin,
            // 底部手势条那段由 QingyuPageList 内部按 innerPadding 算
            //（等价于原先手写的 innerPadding.calculateBottomPadding()），
            // 这里只补额外的滚动留白，避免重复相加。
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // ── 搜索框（官方 TextField）──
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        imageVector = MiuixIcons.Search,
                        contentDescription = null,
                        tint = Color(QingyuTheme.secondaryText(dark)),
                    )
                    TextField(
                        value = query,
                        onValueChange = { query = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = OpenSourceLicensesStrings.searchHint,
                        singleLine = true,
                    )
                }
            }

            // ── 许可说明卡 ──
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(14.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = OpenSourceLicensesStrings.appSectionTitle,
                            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        LicenseParagraph(OpenSourceLicensesStrings.appLicenseLabel)
                        LicenseParagraph(OpenSourceLicensesStrings.intro)
                        LicenseParagraph(OpenSourceLicensesStrings.extraUmeng)
                    }
                }
            }

            item {
                QingyuSectionTitle(
                    OpenSourceLicensesStrings.packagesSectionTitle(
                        if (isLoading) 0 else packages.size,
                    ),
                )
            }

            when {
                isLoading -> item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        CircularProgressIndicator()
                    }
                }

                loadError != null -> item {
                    HintRow(OpenSourceLicensesStrings.loadFailed)
                }

                filtered.isEmpty() -> item {
                    HintRow(OpenSourceLicensesStrings.empty)
                }

                else -> items(filtered, key = { it.packageName }) { pkg ->
                    QingyuRow(
                        title = pkg.packageName,
                        subtitle = OpenSourceLicensesStrings.packageSubtitle(pkg.licenseBodies.size),
                        icon = {
                            Icon(
                                imageVector = MiuixIcons.File,
                                contentDescription = null,
                                tint = Color(QingyuIconColors.BLUE),
                            )
                        },
                        onClick = { onOpenPackage(pkg) },
                    )
                }
            }
        }
    }
}

/** 加载失败 / 无匹配的提示行（Dart 侧 `HyperosHintBanner` 的等价物）。 */
@Composable
private fun HintRow(message: String) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(14.dp),
    ) {
        Text(
            text = message,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/** 卡内段落：Dart 侧统一 1.45 行高（`HyperosTypography.listDetail` + height 1.45）。 */
@Composable
private fun LicenseParagraph(text: String) {
    val dark = isSystemInDarkTheme()
    Text(
        text = text,
        style = MiuixTheme.textStyles.body2,
        lineHeight = 20.sp,
        color = Color(QingyuTheme.primaryText(dark)),
    )
}

/**
 * 详情页：某个包的许可证全文（Dart `_OpenSourceLicenseDetailScreen`）。
 *
 * 全文用 [OpenSourcePackageLicense.combinedLicenseText]，即 Dart 的
 * `licenseBodies.join('\n\n---\n\n')`——分隔线形态由模型层钉住。
 */
@Composable
fun OpenSourceLicenseDetailPage(
    pkg: OpenSourcePackageLicense,
    onBack: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuPageScaffold(title = pkg.packageName, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = 24.dp),
        ) {
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(14.dp),
                ) {
                    Text(
                        text = pkg.combinedLicenseText,
                        style = MiuixTheme.textStyles.body2,
                        lineHeight = 20.sp,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 ContributorsPage 样板铺）
//
// 只给实现阶段看效果，不进业务路径。本文件两个整页入口，各自铺：
//
// 【列表页 OpenSourceLicensesPage】四条分支都在同一个 `when` 里，容易只改其中一条：
//   有数据 / 空态（搜索无匹配或注册表为空）/ 加载中 / 读取失败；再加暗色、大字号两档。
//
// 【详情页 OpenSourceLicenseDetailPage】无数据分支（一个包 + 一段全文），只铺外观三档：
//   亮色 / 暗色 / 大字号——全文是长段落，大字号下折行与卡片高度变化最明显。
//
// 固定写法同 ContributorsPage：主题一律包 QingyuPageTheme(isDark = …)、字号走 textScale、
// 宽度按 400dp。搜索框里的关键词属于页面内部状态，预览一律从空搜索开始。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：三包，包名与正文长度都照真注册表的形态写。 */
private val previewOpenSourcePackages: List<OpenSourcePackageLicense> = listOf(
    OpenSourcePackageLicense(
        packageName = "androidx.compose.ui",
        licenseBodies = listOf(
            """
                Apache License
                Version 2.0, January 2004
                http://www.apache.org/licenses/

                Licensed under the Apache License, Version 2.0 (the "License");
                you may not use this file except in compliance with the License.
                You may obtain a copy of the License at

                    http://www.apache.org/licenses/LICENSE-2.0
            """.trimIndent(),
        ),
    ),
    OpenSourcePackageLicense(
        packageName = "miuix-kmp",
        licenseBodies = listOf(
            """
                Copyright 2024 Yukonga

                Licensed under the Apache License, Version 2.0 (the "License");
                you may not use this file except in compliance with the License.
            """.trimIndent(),
            "本项目自带的图标与排版素材仅可在 GPL-3.0 范围内再分发。",
        ),
    ),
    OpenSourcePackageLicense(
        packageName = "okhttp",
        licenseBodies = listOf(
            """
                MIT License

                Permission is hereby granted, free of charge, to any person obtaining a copy
                of this software and associated documentation files (the "Software").
            """.trimIndent(),
        ),
    ),
)

/** 一档预览的公共身体：三态输入 + 外观档位。 */
@Composable
private fun PreviewOpenSourceLicensesPage(
    packages: List<OpenSourcePackageLicense> = previewOpenSourcePackages,
    isLoading: Boolean = false,
    loadError: String? = null,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        OpenSourceLicensesPage(
            packages = packages,
            onBack = {},
            onOpenPackage = {},
            isLoading = isLoading,
            loadError = loadError,
        )
    }
}

@Suppress("unused")
@Preview(name = "1 有数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicensesPagePreviewData() {
    PreviewOpenSourceLicensesPage()
}

@Suppress("unused")
@Preview(name = "2 空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicensesPagePreviewEmpty() {
    PreviewOpenSourceLicensesPage(packages = emptyList())
}

@Suppress("unused")
@Preview(name = "3 加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicensesPagePreviewLoading() {
    PreviewOpenSourceLicensesPage(packages = emptyList(), isLoading = true)
}

@Suppress("unused")
@Preview(name = "4 读取失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicensesPagePreviewError() {
    PreviewOpenSourceLicensesPage(
        packages = emptyList(),
        loadError = "licenses_registry_unavailable",
    )
}

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicensesPagePreviewDark() {
    PreviewOpenSourceLicensesPage(dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicensesPagePreviewLargeText() {
    PreviewOpenSourceLicensesPage(textScale = 1.3f)
}

/** 详情页一档预览的公共身体：同一个包 + 外观档位。 */
@Composable
private fun PreviewOpenSourceLicenseDetailPage(
    pkg: OpenSourcePackageLicense = previewOpenSourcePackages[1],
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        OpenSourceLicenseDetailPage(pkg = pkg, onBack = {})
    }
}

@Suppress("unused")
@Preview(name = "7 详情·亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicenseDetailPagePreviewLight() {
    PreviewOpenSourceLicenseDetailPage()
}

@Suppress("unused")
@Preview(name = "8 详情·暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicenseDetailPagePreviewDark() {
    PreviewOpenSourceLicenseDetailPage(dark = true)
}

@Suppress("unused")
@Preview(name = "9 详情·大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun OpenSourceLicenseDetailPagePreviewLargeText() {
    PreviewOpenSourceLicenseDetailPage(textScale = 1.3f)
}
