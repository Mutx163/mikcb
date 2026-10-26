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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 开源许可页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/open_source_licenses_screen.dart`：
 * 搜索框 + 「许可说明」卡 + 组件列表（点进看全文）。
 *
 * ## 分层约定
 *
 * 本文件在 **composeP1** 源集，因为只有该变体的 classpath 上有官方 Miuix；
 * 结构与文案在 main 源集的 [OpenSourcePackageLicense] / [filterOpenSourcePackages] /
 * [OpenSourceLicensesStrings]（那边零 Compose 依赖，可进常规单测）。
 *
 * ## 组件选择（对照 S2-5 组件表）
 *
 * - Scaffold / Card / Text / TextField / CircularProgressIndicator 全部用官方
 *   `top.yukonga.miuix.kmp.basic.*`，不自绘；
 * - 0.8.8 里**没有 preference 模块**（设置行那套在 0.9.4 独立模块，需 Kotlin 2.4），
 *   所以列表行用 Card + Row 组合，不引 preference；
 * - 图标沿用纯文字（返回用「返回」二字）：miuix-icons 0.8.8 的图标集里没有
 *   返回箭头对应物，自绘箭头属白名单外，先不引。
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
    val colors = MiuixTheme.colorScheme

    Scaffold(containerColor = colors.surface) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(innerPadding),
        ) {
            // ── 标题栏（返回 + 标题）──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "返回",
                    fontSize = 15.sp,
                    color = colors.primary,
                    modifier = Modifier.clickable { onBack() },
                )
                Text(
                    text = OpenSourceLicensesStrings.title,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                )
            }

            // ── 搜索框（官方 TextField）──
            TextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                label = OpenSourceLicensesStrings.searchHint,
                singleLine = true,
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // ── 许可说明卡 ──
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(
                                text = OpenSourceLicensesStrings.appSectionTitle,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = colors.onSurface,
                            )
                            LicenseParagraph(OpenSourceLicensesStrings.appLicenseLabel)
                            LicenseParagraph(OpenSourceLicensesStrings.intro)
                            LicenseParagraph(OpenSourceLicensesStrings.extraUmeng)
                        }
                    }
                }

                // ── 组件数量小节标题 ──
                item {
                    Text(
                        text = OpenSourceLicensesStrings.packagesSectionTitle(
                            if (isLoading) 0 else packages.size,
                        ),
                        fontSize = 13.sp,
                        color = colors.onSurfaceVariantSummary,
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
                        HintCard(OpenSourceLicensesStrings.loadFailed)
                    }

                    filtered.isEmpty() -> item {
                        HintCard(OpenSourceLicensesStrings.empty)
                    }

                    else -> items(filtered) { pkg ->
                        PackageRow(pkg = pkg, onOpen = { onOpenPackage(pkg) })
                    }
                }
            }
        }
    }
}

/** 列表行：包名 + 「N 份许可证文本」。点击进详情。 */
@Composable
private fun PackageRow(
    pkg: OpenSourcePackageLicense,
    onOpen: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onOpen() },
        insideMargin = PaddingValues(14.dp),
    ) {
        Column {
            Text(
                text = pkg.packageName,
                fontSize = 16.sp,
                color = colors.onSurface,
            )
            Text(
                text = OpenSourceLicensesStrings.packageSubtitle(pkg.licenseBodies.size),
                fontSize = 12.sp,
                color = colors.onSurfaceVariantSummary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

/** 加载失败 / 无匹配的提示卡（Dart 侧 HyperosHintBanner 的等价物）。 */
@Composable
private fun HintCard(message: String) {
    val colors = MiuixTheme.colorScheme
    Card(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(14.dp),
    ) {
        Text(
            text = message,
            fontSize = 13.sp,
            color = colors.onSurfaceVariantSummary,
        )
    }
}

/** 卡内段落：Dart 侧统一 1.45 行高（HyperosTypography.listDetail + height 1.45）。 */
@Composable
private fun LicenseParagraph(text: String) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = text,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        color = colors.onSurface,
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
    val colors = MiuixTheme.colorScheme
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
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "返回",
                    fontSize = 15.sp,
                    color = colors.primary,
                    modifier = Modifier.clickable { onBack() },
                )
                Text(
                    text = pkg.packageName,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = colors.onSurface,
                )
            }
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
            ) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(14.dp),
                    ) {
                        Text(
                            text = pkg.combinedLicenseText,
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            color = colors.onSurface,
                        )
                    }
                }
            }
        }
    }
}
