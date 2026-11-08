package com.mutx163.qingyu.pages.about

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 关于页「静态信息区 + 头部信息卡 + 说明/仓库弹层」· Compose 渲染层（Phase 3，2026-10-28 补全）。
 *
 * 对照 Flutter `lib/screens/about_screen.dart` 的 `AboutScreen`（:234-603）：
 * 1. **头部信息卡**：应用图标 + 应用名 + 版本号 + 一句定位 + 三格元信息条 + 第三方免责声明
 *    （Dart :252-294）。此前 Compose 版**整块缺失**，这是与老版本最直观的差异。
 * 2. **三段列表**：支持与更新 / 产品 / 社区，行走 [QingyuRow]，顺序由 [aboutInfoSections] 钉住。
 * 3. **10 个入口全部接线**：导航类转成壳页面 id 交给 [onOpenPage]；说明类（项目定位 / 导入迁移）
 *    弹 [AboutInfoSheet]；开源仓库弹 [AboutRepositorySheet]。
 *
 * ## 为什么头部卡在这里画而不是壳
 *
 * 头部卡只用一次、且强属关于页语义（版本号来自本机 PackageManager），放这里与 Flutter 结构一一对应；
 * 壳只负责把「点了要去哪一页」转成路由，不掺和版式。
 *
 * ## 文案纪律
 *
 * 本文件**不含任何中文字面量**（i18n 棘轮 `CjkLiteralGateTest` 管着渲染层）：屏上文案全部取自
 * main 层 [AboutInfoStrings] / [AboutRepositoryStrings]，与 `app_zh.arb` 逐字一致。
 */
@Composable
fun AboutStaticPage(
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val sections = aboutInfoSections()
    var infoSheetEntry by remember { mutableStateOf<AboutInfoEntry?>(null) }
    var repositorySheetOpen by remember { mutableStateOf(false) }
    // 退场动画期间保留最后一份非空快照：弹层常驻组合、只翻 show（2026-11-02 弹窗审核 P3，
    // 「条件成立才组合」会让关闭时的下滑退场一次都不播）。
    var lastInfoEntry by remember { mutableStateOf<AboutInfoEntry?>(null) }
    LaunchedEffect(infoSheetEntry) { infoSheetEntry?.let { lastInfoEntry = it } }
    val context = LocalContext.current

    QingyuPageScaffold(title = AboutInfoStrings.aboutTitle, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 官方配方：页面横向留白由每个块自己带（Card 12dp），
            // 不在 contentPadding 里加左右内边距——否则滚动条贴不到屏幕边缘。
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
            verticalArrangement = AboutPageListSpacing,
        ) {
            // ── 头部信息卡 ──
            item(key = "about-hero") {
                AboutHeroCard()
            }

            // ── 三段列表：一段一张设置组卡（圆角 24），行走官方 ArrowPreference ──
            // （2026-11-03 版面收口：原先一行一张自拼卡、行内 Row+箭头手拼，
            //   与高级选项页的官方 preference 形态不一致。）
            for (section in sections) {
                item(key = "section-${section.label}") {
                    QingyuSectionTitle(section.label)
                }
                item(key = "group-${section.label}") {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                    ) {
                        section.entries.forEach { entry ->
                            ArrowPreference(
                                title = entry.title,
                                summary = entry.subtitle.takeIf { it.isNotEmpty() },
                                onClick = {
                                    when (entry.kind) {
                                        // 说明层：页内弹层，不外跳。
                                        AboutEntryKind.POSITIONING,
                                        AboutEntryKind.IMPORT_MIGRATION -> infoSheetEntry = entry
                                        // 仓库说明：页内弹层，含三个动作。
                                        AboutEntryKind.REPOSITORY -> repositorySheetOpen = true
                                        // 其余都是「推一页」，交给壳把它们转成壳页面 id。
                                        else -> onOpenPage(routeOf(entry.kind))
                                    }
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    val renderedInfoEntry = infoSheetEntry ?: lastInfoEntry
    if (renderedInfoEntry != null) {
        AboutInfoSheet(
            show = infoSheetEntry != null,
            entry = renderedInfoEntry,
            onDismiss = { infoSheetEntry = null },
        )
    }
    AboutRepositorySheet(
        show = repositorySheetOpen,
        onDismiss = { repositorySheetOpen = false },
        onOpenMainRepo = { openUrl(context, AboutRepositoryStrings.mainRepoUrl) },
        onOpenWarehouseRepo = { openUrl(context, AboutRepositoryStrings.warehouseRepoUrl) },
        onCopyAddress = {
            copyToClipboard(context, AboutRepositoryStrings.mainRepoUrl)
            Toast.makeText(
                context,
                AboutRepositoryStrings.copiedAddress,
                Toast.LENGTH_SHORT,
            ).show()
        },
    )
}

/**
 * 入口种类 → 壳页面 id。
 *
 * 只映射**导航类**入口；说明类（POSITIONING / IMPORT_MIGRATION / REPOSITORY）在上面的 when 里已
 * 就地处理，不会走到这里。
 */
private fun routeOf(kind: AboutEntryKind): String = when (kind) {
    AboutEntryKind.COFFEE -> "a.support"
    AboutEntryKind.FEEDBACK -> "k.feedback"
    AboutEntryKind.UPDATES -> "a.update"
    AboutEntryKind.CHANGELOG -> "a.changelog"
    AboutEntryKind.APP_LOGS -> "h.log"
    AboutEntryKind.CONTRIBUTORS -> "a.contributors"
    AboutEntryKind.OPEN_SOURCE_LICENSES -> "a.licenses"
    // 说明/仓库类不会到这里；给个安全兜底（回关于页自身，绝不崩）。
    AboutEntryKind.POSITIONING,
    AboutEntryKind.IMPORT_MIGRATION,
    AboutEntryKind.REPOSITORY -> "a.about"
}

/** 头部信息卡：对照 `AboutScreen.build` 的第一张卡（Dart :252-294）。
 *
 *  2026-11-03 版面收口：内边距收 [QingyuCardDefaults.ContentInsideMargin]（16dp，与全族一致）；
 *  图标换共享 [AboutAppIconBadge]（单层干净图标，与更新页同一身份块）；版本号等宽字体，
 *  与「当前版本 / 最新版本」的更新页口径一致。 */
@Composable
private fun AboutHeroCard() {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    // 版本号：与 Dart `PackageInfo.fromPlatform()` 同源（PackageManager），格式 `版本 x.y.z (code)`。
    val versionText = remember {
        runCatching {
            @Suppress("DEPRECATION")
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            val name = info.versionName.orEmpty()
            val code = if (android.os.Build.VERSION.SDK_INT >= 28) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
            AboutInfoStrings.versionLabel(if (name.isEmpty()) "$code" else "$name ($code)")
        }.getOrDefault(AboutInfoStrings.loadingText)
    }

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AboutAppIconBadge(size = 84.dp)
            Spacer(Modifier.height(16.dp))
            Text(
                text = AboutInfoStrings.appName,
                style = MiuixTheme.textStyles.title2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = versionText,
                style = MiuixTheme.textStyles.footnote1.copy(fontFamily = FontFamily.Monospace),
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = AboutInfoStrings.heroSubtitle,
                style = MiuixTheme.textStyles.footnote1,
                lineHeight = 19.sp,
                textAlign = TextAlign.Center,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(Modifier.height(16.dp))
            HeroMetaStrip(updateValue = AboutInfoStrings.stableOnly)
            Spacer(Modifier.height(16.dp))
            Text(
                text = AboutInfoStrings.thirdPartyDisclaimer,
                style = MiuixTheme.textStyles.footnote2,
                textAlign = TextAlign.Center,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
    }
}

/** 三格元信息条（Dart `_buildHeroMetaStrip`，:528-572）：平台 / 重点 / 更新。
 *  三格用留白分隔（2026-11-03 去线收口：原来格间竖 1dp 线删除）。 */
@Composable
private fun HeroMetaStrip(updateValue: String) {
    val dark = isSystemInDarkTheme()
    val inset = Color(
        if (dark) QingyuTheme.surfaceContainerHighest(dark) else QingyuTheme.surfaceContainer(dark),
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(inset)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        HeroMetaCell(
            label = AboutInfoStrings.platformLabel,
            value = AboutInfoStrings.platformValue,
            modifier = Modifier.weight(1f),
        )
        HeroMetaCell(
            label = AboutInfoStrings.focusLabel,
            value = AboutInfoStrings.focusValue,
            modifier = Modifier.weight(1f),
        )
        HeroMetaCell(
            label = AboutInfoStrings.updateLabel,
            value = updateValue,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun HeroMetaCell(label: String, value: String, modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    Column(
        modifier = modifier.padding(horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote2,
            textAlign = TextAlign.Center,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = value,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            textAlign = TextAlign.Center,
            color = Color(QingyuTheme.primaryText(dark)),
        )
    }
}

/**
 * 说明弹层（Dart `_showInfoSheet` + `AboutInfoSheetBody`）：标题 + 若干条正文段落。
 *
 * 与 Dart 一致：正文是**普通段落**（不是一行一张卡），完整折行、可读优先。
 */
@Composable
private fun AboutInfoSheet(
    show: Boolean,
    entry: AboutInfoEntry,
    onDismiss: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuSheet(
        show = show,
        title = entry.title,
        onDismissRequest = onDismiss,
        // 内容那 4dp 只是面板内的微调，不足以顶掉套件的 16dp 口径：置 true 会把正文贴到
        // 面板边缘（单边只剩 4dp）。保持 false ⇒ 单边 16 + 4 = 20dp（Dart `HyperosSheetFrame` 是 16）。
        contentPadsHorizontally = false,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = entry.subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            for (bullet in entry.bullets) {
                Text(
                    text = bullet,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = 20.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }
    }
}

/**
 * 开源仓库弹层（Dart `_showRepositorySheet`）：地址 + 说明 + 三个动作。
 *
 * 动作按钮用官方 [Button] / [TextButton]，不塞进实心卡片（Dart 注释说明按钮应落在磨砂弹层表面）。
 */
@Composable
private fun AboutRepositorySheet(
    show: Boolean,
    onDismiss: () -> Unit,
    onOpenMainRepo: () -> Unit,
    onOpenWarehouseRepo: () -> Unit,
    onCopyAddress: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuSheet(
        show = show,
        title = AboutRepositoryStrings.sheetTitle,
        onDismissRequest = onDismiss,
        // 同 AboutInfoSheet：内容只有 4dp 微调，套件的 16dp 侧边距保留。
        contentPadsHorizontally = false,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = AboutRepositoryStrings.mainRepoUrl,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = AboutRepositoryStrings.sheetHint,
                style = MiuixTheme.textStyles.footnote1,
                lineHeight = 20.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Button(
                onClick = onOpenMainRepo,
                modifier = Modifier.fillMaxWidth(),
                // Dart `_showRepositorySheet` 里这颗是 `HyperosButton(...)` 默认（primary）；
                // `buttonColors()` 是 secondaryVariant 灰底，主操作会看起来点不动。
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(AboutRepositoryStrings.openGitHubAction)
            }
            RepositorySecondaryButton(
                text = AboutRepositoryStrings.openWarehouseRepoAction,
                onClick = onOpenWarehouseRepo,
            )
            RepositorySecondaryButton(
                text = AboutRepositoryStrings.copyAddress,
                onClick = onCopyAddress,
            )
        }
    }
}

/**
 * 开源仓库弹层的**次级按钮**（打开适配仓 / 复制地址）。
 *
 * 为什么不用 `TextButton`：miuix `TextButton` 其实不是透明文字按钮，它的填充来自
 * `ButtonDefaults.textButtonColors()` 的 `color = secondaryVariant`；本仓 `QingyuPageTheme`
 * 把 `surfaceContainerHigh`（= secondaryVariant 的来源）覆写成了 `card` 色（亮 #FFFFFF / 暗 #2D2D2D），
 * 而 `QingyuSheet` 面板底是 `background`（亮 #F2F2F2 / 暗 #242424）——两者几乎同色，按钮就“融进弹层”。
 *
 * 按 Flutter v2.1.4.1 `_showRepositorySheet` 在磨砂面板上的做法（次级按钮要有可见边界）：
 * **主题 card 底色 + 1dp 主题 outline 描边**，主按钮仍是主色实心，主次一眼可分；官方 `Button` + 主题语义色，不自造控件。
 */
@Composable
private fun RepositorySecondaryButton(text: String, onClick: () -> Unit) {
    val dark = isSystemInDarkTheme()
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .border(
                width = 1.dp,
                color = Color(QingyuTheme.outline(dark)),
                shape = RoundedCornerShape(16.dp),
            ),
        colors = ButtonDefaults.buttonColors(
            color = Color(QingyuTheme.card(dark)),
            contentColor = Color(QingyuTheme.primaryText(dark)),
            disabledColor = Color(QingyuTheme.card(dark)),
            disabledContentColor = Color(QingyuTheme.secondaryText(dark)),
        ),
    ) {
        Text(text = text)
    }
}

/** 用系统浏览器打开一个外部链接。 */
private fun openUrl(context: Context, url: String) {
    runCatching {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}

/** 复制文本到剪贴板。 */
private fun copyToClipboard(context: Context, text: String) {
    val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    manager?.setPrimaryClip(ClipData.newPlainText("", text))
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 ContributorsPage 样板铺）
//
// 只给实现阶段看效果，不进业务路径。本页**没有可喂的数据状态**：三段入口由
// `aboutInfoSections()` 现算、版本号由 PackageManager 现读，渲染层拿到的只有两个回调，
// 所以只铺外观三档：
//   · 亮色 / 暗色 —— 暗色档防「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()，历史上真出现过）；
//   · 大字号 —— 行内文案 11 / 17 字的折行点，只在字被放大后才暴露。
//
// 固定写法同 ContributorsPage：主题一律包 QingyuPageTheme(isDark = …)、字号走 textScale
//（不用 @Preview(fontScale = …)）、宽度按 400dp。
// ─────────────────────────────────────────────────────────────────────────────

/** 一档预览的公共身体：只翻外观档位。 */
@Composable
private fun PreviewAboutStaticPage(
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        AboutStaticPage(
            onBack = {},
            onOpenPage = {},
        )
    }
}

@Suppress("unused")
@Preview(name = "1 亮色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutStaticPagePreviewLight() {
    PreviewAboutStaticPage()
}

@Suppress("unused")
@Preview(name = "2 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutStaticPagePreviewDark() {
    PreviewAboutStaticPage(dark = true)
}

@Suppress("unused")
@Preview(name = "3 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun AboutStaticPagePreviewLargeText() {
    PreviewAboutStaticPage(textScale = 1.3f)
}
