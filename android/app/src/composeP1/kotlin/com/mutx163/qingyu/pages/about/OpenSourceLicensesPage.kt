package com.mutx163.qingyu.pages.about

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.InputField
import top.yukonga.miuix.kmp.basic.SearchBarDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.basic.Search
import top.yukonga.miuix.kmp.icon.basic.SearchCleanup
import top.yukonga.miuix.kmp.icon.extended.File
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
            // 官方配方：页面横向 0，留白由每个块自己带（卡片 12dp），与关于族一致
            //（滚动条位置与此无关：miuix 竖条只用 trackPadding 的上下两个值）。
            horizontalPadding = QingyuPageCardMargin,
            // 发布版列表顶部 4dp（`hyperos_tokens.dart:71`）：本页首项是搜索卡，没有分组
            // 标题的 8dp 兜底，直接贴栏会显得被切掉一截。
            extraTopPadding = 4.dp,
            // 底部手势条那段由 QingyuPageList 内部按 innerPadding 算
            //（等价于原先手写的 innerPadding.calculateBottomPadding()），
            // 这里只补额外的滚动留白，避免重复相加。
            contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
            // 全族统一 12dp 段间距（原先是 10dp，与关于/更新/捐助页不是一套刻度）。
            verticalArrangement = AboutPageListSpacing,
        ) {
            // ── 搜索框：miuix 官方 `InputField` 胶囊 ──
            // 45dp 胶囊 + `surfaceContainerHigh` 底 + 左右自带 16/8 图标位，全在组件内部；
            // 不再套一层卡片、也不自拼 Row+TextField（配方见 `basic/SearchBar.kt:158` 与
            // 官方 demo `SuperSearchBar.kt`）。`expanded` 恒 false：这一页是「边输边滤」的
            // 常驻搜索框，不展开成全屏搜索页；minSdk 33 不触发库内 API 26-27 焦点补丁。
            item(key = "search") {
                InputField(
                    query = query,
                    onQueryChange = { query = it },
                    // 输入即筛，没有独立提交动作（回车只收键盘）。
                    onSearch = { },
                    expanded = false,
                    onExpandedChange = { },
                    modifier = Modifier.fillMaxWidth(),
                    label = OpenSourceLicensesStrings.searchHint,
                    // 官方默认放大镜的朗读文案是库里的英文 "Search"；输入框已有 label，
                    // 图标纯装饰，交回正文朗读（同 GlassDockIconPicker 的写法）。
                    leadingIcon = {
                        Icon(
                            imageVector = MiuixIcons.Basic.Search,
                            contentDescription = null,
                            tint = MiuixTheme.colorScheme.onSurfaceContainerHigh,
                            modifier = Modifier.padding(
                                start = SearchBarDefaults.LeadingIconStartPadding,
                                end = SearchBarDefaults.LeadingIconEndPadding,
                            ),
                        )
                    },
                    // 清空键：44dp 触区、start 8 / end 16 内边距、无涟漪；文案复用全站
                    // 已有的「清空」（`SettingsStringsExt4.clearSearchAction`），不新造键。
                    trailingIcon = {
                        AnimatedVisibility(
                            visible = query.isNotEmpty(),
                            enter = fadeIn(),
                            exit = fadeOut(),
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Basic.SearchCleanup,
                                contentDescription = SettingsStringsExt4.clearSearchAction.text,
                                tint = MiuixTheme.colorScheme.onSurface,
                                modifier = Modifier
                                    .size(44.dp)
                                    .padding(start = 8.dp, end = 16.dp)
                                    .clickable(interactionSource = null, indication = null) {
                                        query = ""
                                    },
                            )
                        }
                    },
                )
            }

            // ── 许可说明卡 ──
            item(key = "app-license") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(16.dp),
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

            item(key = "packages-title") {
                QingyuSectionTitle(
                    text = OpenSourceLicensesStrings.packagesSectionTitle(
                        if (isLoading) 0 else packages.size,
                    ),
                    // 列表已统一加 12dp，标题这里只让 16dp ⇒ 12 + 16 = 官方 28dp 轴线；
                    // 默认值 28 会变成 40，标题比整张卡缩进一格（2026-11-10 修）。
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                )
            }

            when {
                // D1 档 A2（块内居中）：列表上方还有分组标题，不能整页铺满；
                // 共享件给 120dp 最小高度，替代原先手写的 padding(vertical = 32)。
                isLoading -> item { QingyuLoadingCenter(fillPage = false) }

                loadError != null -> item {
                    HintRow(OpenSourceLicensesStrings.loadFailed)
                }

                filtered.isEmpty() -> item {
                    HintRow(OpenSourceLicensesStrings.empty)
                }

                else -> items(filtered, key = { it.packageName }) { pkg ->
                    // 发布版是一张 `HyperosListGroup`（所有包在一张卡里）。这里**故意**保持
                    // 「一行一张卡 + 惰性组合」：APK 里的 `licenses/NOTICES` 实测聚合出
                    // 234 个包，塞进同一个 item 会一次性组合 234 行（进页首帧、每次清空
                    // 搜索框都要重来一遍）；拆成 list item 才只组合屏幕内那十来个。
                    // 看起来仍是一套刻度：列表 12dp 页边 + 行内 16dp（= 28 轴线）。
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
            contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
        ) {
            item(key = "license-body") {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    // 与列表页说明卡同一内边距（原先 14dp，同族两页差 2dp）。
                    insideMargin = PaddingValues(16.dp),
                ) {
                    // 发布版用 `SelectionArea` 包住全文（`open_source_licenses_screen.dart:246`）：
                    // 许可证要能被选中、复制去核对，不只是「看」。Compose 侧等价物就是
                    // `SelectionContainer`，长按即出选择手柄。
                    SelectionContainer {
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

// ── 整页档（1200dp）────────────────────────────────────────────────────────
//
// 900dp 的一屏档只能看到搜索框 + 许可说明卡，组件列表被裁掉；整页档按页面
// 真实长度给 1200dp，用来检查「搜索框 → 说明卡 → 分组标题 → 包列表」的整页节奏。
// 原 900 档保留：900 看首屏，1200 看整页。

@Suppress("unused")
@Preview(name = "10 整页", showBackground = true, widthDp = 400, heightDp = 1200)
@Composable
private fun OpenSourceLicensesPagePreviewFullPage() {
    PreviewOpenSourceLicensesPage()
}
