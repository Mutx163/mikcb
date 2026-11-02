package com.mutx163.qingyu.pages.about

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
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
            // 底部手势条高度显式算进 contentPadding；QingyuPageList 内部还会把传入
            // innerPadding 的 bottom 再加一次，所以 innerPadding 这里只给 top，避免小白条算两遍
            // （与 schedule/ScheduleListPage 同一配方）。
            innerPadding = PaddingValues(top = innerPadding.calculateTopPadding()),
            scrollBehavior = scrollBehavior,
            // 官方配方：页面横向留白由每个块自己带（Card 12dp），
            // 不在 contentPadding 里加左右内边距——否则滚动条贴不到屏幕边缘。
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = innerPadding.calculateBottomPadding() + 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // ── 头部信息卡 ──
            item(key = "about-hero") {
                AboutHeroCard()
            }

            // ── 三段列表 ──
            for (section in sections) {
                item(key = "section-${section.label}") {
                    QingyuSectionTitle(section.label)
                }
                items(section.entries) { entry ->
                    QingyuRow(
                        title = entry.title,
                        subtitle = entry.subtitle,
                        icon = { RowIcon(entry) },
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

/** 头部信息卡：对照 `AboutScreen.build` 的第一张卡（Dart :252-294）。 */
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
        insideMargin = PaddingValues(20.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            AppIconBadge(size = 84.dp, radius = 24.dp)
            Spacer(Modifier.height(16.dp))
            Text(
                text = AboutInfoStrings.appName,
                style = MiuixTheme.textStyles.title2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = versionText,
                style = MiuixTheme.textStyles.footnote1,
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

/** 应用图标：读 APK 里 `flutter_assets/assets/branding/launcher_icon.png`（与 Flutter 同一份）。 */
@Composable
private fun AppIconBadge(size: Dp, radius: Dp) {
    val context = LocalContext.current
    val bitmap by produceState<ImageBitmap?>(initialValue = null) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                context.assets.open("flutter_assets/assets/branding/launcher_icon.png").use { stream ->
                    BitmapFactory.decodeStream(stream)?.asImageBitmap()
                }
            }.getOrNull()
        }
    }
    val image = bitmap
    if (image != null) {
        Image(
            bitmap = image,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(size)
                .clip(RoundedCornerShape(radius)),
        )
    } else {
        // 读不到资产时留尺寸占位，不画一个假图标。
        Box(Modifier.size(size))
    }
}

/** 三格元信息条（Dart `_buildHeroMetaStrip`，:528-572）：平台 / 重点 / 更新。 */
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
        HeroMetaDivider()
        HeroMetaCell(
            label = AboutInfoStrings.focusLabel,
            value = AboutInfoStrings.focusValue,
            modifier = Modifier.weight(1f),
        )
        HeroMetaDivider()
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

@Composable
private fun HeroMetaDivider() {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(28.dp)
            .background(Color(QingyuTheme.dividerLine(dark))),
    )
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
            TextButton(
                text = AboutRepositoryStrings.openWarehouseRepoAction,
                onClick = onOpenWarehouseRepo,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.textButtonColors(),
            )
            TextButton(
                text = AboutRepositoryStrings.copyAddress,
                onClick = onCopyAddress,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.textButtonColors(),
            )
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
