package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.Search

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
        LazyColumn(
            // 把滚动手势喂给顶栏的折叠行为；漏了这一步大标题就永不收起。
            modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = innerPadding.calculateTopPadding(),
                // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                bottom = innerPadding.calculateBottomPadding() + 24.dp,
            ),
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
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        LicenseParagraph(OpenSourceLicensesStrings.appLicenseLabel)
                        LicenseParagraph(OpenSourceLicensesStrings.intro)
                        LicenseParagraph(OpenSourceLicensesStrings.extraUmeng)
                    }
                }
            }

            item {
                QingyuSectionLabel(
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

                else -> items(filtered) { pkg ->
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
            fontSize = 13.sp,
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
        fontSize = 14.sp,
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
        LazyColumn(
            // 把滚动手势喂给顶栏的折叠行为；漏了这一步大标题就永不收起。
            modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = innerPadding.calculateTopPadding(),
                // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                bottom = innerPadding.calculateBottomPadding() + 24.dp,
            ),
        ) {
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = PaddingValues(14.dp),
                ) {
                    Text(
                        text = pkg.combinedLicenseText,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        color = Color(QingyuTheme.primaryText(dark)),
                    )
                }
            }
        }
    }
}
