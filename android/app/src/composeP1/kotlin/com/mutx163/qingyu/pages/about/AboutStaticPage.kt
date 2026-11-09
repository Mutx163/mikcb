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
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
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
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
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
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 关于页「静态信息区 + 头部信息卡 + 说明/仓库弹层」· Compose 渲染层（Phase 3，2026-10-28 补全）。
 *
 * 对照 Flutter `lib/screens/about_screen.dart` 的 `AboutScreen`（:234-603）：
 * 1. **头部信息卡**：应用图标 + 应用名 + 版本号 + 一句定位 + 三格元信息条
 *    （Dart :252-294）。此前 Compose 版**整块缺失**，这是与老版本最直观的差异。
 * 2. **三段列表**：支持与更新 / 产品 / 社区，一组一个 item（标题 + 官方 [ArrowPreference] 卡），
 *    顺序由 [aboutInfoSections] 钉住；行首图标取自模型层的 `AboutRowIcon`，配色统一走官方
 *    demo 的 `onBackground` 单色（2026-11-09 A 方案；`accentArgb` 仍留在模型层供 Dart 对拍）。
 * 3. **10 个入口全部接线**：导航类转成壳页面 id 交给 [onOpenPage]；说明类（项目定位 / 导入迁移）
 *    弹 [AboutInfoSheet]；开源仓库弹 [AboutRepositorySheet]。
 * 4. **页尾免责声明**：第三方声明从头部卡移到三段列表之后，12sp 左对齐（2026-11-09）。
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
 *
 * @param versionOverride 仅 IDE 预览用：注入假版本号，避开 Preview 里 PackageManager 读不到
 *   真实值导致版本行整行不画；生产调用不传。
 */
@Composable
fun AboutStaticPage(
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    versionOverride: String? = null,
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
                AboutHeroCard(versionOverride = versionOverride)
            }

            // ── 三段列表：一段一张设置组卡（圆角 24），行走官方 ArrowPreference ──
            // （2026-11-03 版面收口：原先一行一张自拼卡、行内 Row+箭头手拼，
            //   与高级选项页的官方 preference 形态不一致。）
            for (section in sections) {
                // 一组 = 一个 item（官方配方）：标题与卡片之间不再夹一层 12dp 列表间距，
                // 标题到卡片顶只剩 SmallTitle 自带的 8dp，与 demo 的「段首贴合」一致。
                item(key = "group-${section.label}") {
                    QingyuSectionTitle(
                        text = section.label,
                        // 列表已统一加 12dp（horizontalPadding = QingyuPageCardMargin），标题这里
                        // 必须只让 16dp，才能和卡内 Preference 的 16dp 落在同一条 28dp 轴线；
                        // 继续用默认 28 ⇒ 12 + 28 = 40，标题比整张卡缩进一格（2026-11-08 修）。
                        insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    )
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                    ) {
                        section.entries.forEach { entry ->
                            AboutEntryRow(
                                entry = entry,
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

            // ── 页尾免责声明（2026-11-09 从头部卡移出）──
            item(key = "about-legal") {
                AboutLegalFooter()
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

/**
 * 一行入口：官方 [ArrowPreference] + 行首单色图标。
 *
 * 图标语义仍由模型层给（[AboutInfoEntry.icon]），渲染层只负责翻译成官方矢量；**配色统一**
 * 走官方 demo 的 `onBackground` 单色（`ArrowSection.kt:49-70`），不再逐行取彩豆色
 * （2026-11-09 A 方案：彩豆色亮暗差异过大，五色并排也压不住）。图标外面那圈 8dp 是同一
 * 官方配方的固定间距（不包的话图标贴住标题）。
 */
@Composable
private fun AboutEntryRow(entry: AboutInfoEntry, onClick: () -> Unit) {
    ArrowPreference(
        title = entry.title,
        summary = entry.subtitle.takeIf { it.isNotEmpty() },
        startAction = {
            Box(modifier = Modifier.padding(end = 8.dp)) {
                Icon(
                    imageVector = entry.icon.toMiuixIcon(),
                    // 标题已经把这一行说清楚了，图标只是装饰，读屏不再重复念一遍。
                    contentDescription = null,
                    tint = MiuixTheme.colorScheme.onBackground,
                )
            }
        },
        onClick = onClick,
    )
}

/** 模型层的语义图标 → 官方图标包里的矢量（模型层不依赖 Compose，翻译只能在渲染层做）。 */
private fun AboutRowIcon.toMiuixIcon(): ImageVector = when (this) {
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

/** 读本机安装版本；读不到返回 null（IDE 预览 / 包信息异常时不画假版本行）。 */
private fun readInstalledVersion(context: Context): String? = runCatching {
    @Suppress("DEPRECATION")
    val info = context.packageManager.getPackageInfo(context.packageName, 0)
    val name = info.versionName.orEmpty().trim()
    val code = if (android.os.Build.VERSION.SDK_INT >= 28) {
        info.longVersionCode
    } else {
        @Suppress("DEPRECATION")
        info.versionCode.toLong()
    }
    when {
        name.isNotEmpty() && code > 0 -> AboutInfoStrings.versionLabel("$name ($code)")
        name.isNotEmpty() -> AboutInfoStrings.versionLabel(name)
        code > 0 -> AboutInfoStrings.versionLabel("$code")
        else -> null
    }
}.getOrNull()

/** 头部信息卡：对照 `AboutScreen.build` 的第一张卡（Dart :252-294）。
 *
 *  2026-11-03 版面收口：内边距收 [QingyuCardDefaults.ContentInsideMargin]（16dp，与全族一致）；
 *  图标换共享 [AboutAppIconBadge]（单层干净图标，与更新页同一身份块）。
 *
 *  2026-11-08 整体重排：版本行不再整串套等宽字体（汉字落进等宽 fallback，字距发飘），
 *  定位句从 footnote1 提到 body2（13→14sp，行高 20）；读不到真实版本号时整行不画，不再拼出「版本 0」。
 *
 *  2026-11-09：第三方免责声明移出本卡，改由页尾 [AboutLegalFooter] 承载（12sp 左对齐），
 *  卡片只留身份 + 一句定位 + 三格元信息条。 */
@Composable
private fun AboutHeroCard(versionOverride: String? = null) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    // 版本号：生产环境与 Dart `PackageInfo.fromPlatform()` 同源（PackageManager），形如
    // 「版本 2.1.4-1 (100140)」。Preview 里 PackageManager 读不到真值，由 [versionOverride]
    // 注入；两边都读不到就返回 null，整行不画，避免拼出「版本 0」。
    val versionText: String? = remember(versionOverride) {
        if (versionOverride != null) {
            AboutInfoStrings.versionLabel(versionOverride)
        } else {
            readInstalledVersion(context)
        }
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
            if (versionText != null) {
                Spacer(Modifier.height(6.dp))
                // 不再套 FontFamily.Monospace：「版本」两个汉字会落到等宽字体的 fallback，
                // 字距比正文宽一挡，整行看着发虚；单行居中也用不上等宽对齐。
                Text(
                    text = versionText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            // 版本行有 / 无时，标题到正文都是 10dp（有版本 = 6 + 行高；无版本 = 10）。
            Spacer(Modifier.height(10.dp))
            Text(
                text = AboutInfoStrings.heroSubtitle,
                // 定位句是「正文」，不是脚注：13 → 14sp，行高 20 让两行之间不挤。
                style = MiuixTheme.textStyles.body2,
                lineHeight = 20.sp,
                textAlign = TextAlign.Center,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Spacer(Modifier.height(16.dp))
            HeroMetaStrip(updateValue = AboutInfoStrings.stableOnly)
        }
    }
}

/**
 * 页尾第三方免责声明（2026-11-09 从头部卡移出）。
 *
 * 12sp 是设计指定值：字阶只有 footnote2 11 / footnote1 13 两档，所以从 footnote1 派生并只改
 * 字号——保留用户字重、字族与 appTextScale 的缩放；这一处已在
 * `tool/compose_style_exceptions/about.txt` 登记 R4 例外。左对齐、整宽折行，按法律文本读，
 * 不再居中造成右侧参差。
 */
@Composable
private fun AboutLegalFooter() {
    val dark = isSystemInDarkTheme()
    Text(
        text = AboutInfoStrings.thirdPartyDisclaimer,
        style = MiuixTheme.textStyles.footnote1.copy(fontSize = 12.sp),
        lineHeight = 18.sp,
        textAlign = TextAlign.Start,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier
            .fillMaxWidth()
            // 列表已带 12dp 页边；再加 16dp 落到卡内文字同一条 28dp 轴线。
            .padding(horizontal = 16.dp, vertical = 4.dp),
    )
}

/** 三格元信息条（Dart `_buildHeroMetaStrip`，:528-572）：平台 / 重点 / 更新。
 *  三格用留白分隔（2026-11-03 去线收口：原来格间竖 1dp 线删除）。 */
@Composable
private fun HeroMetaStrip(updateValue: String) {
    val dark = isSystemInDarkTheme()
    // 凹槽底色要比卡片**深一档**（亮 #E8E8E8 / 暗 #242424）。
    // 旧写法是 `if (dark) 最高级容器 else surfaceContainer`：亮色取到 #FFFFFF、暗色取到
    // #2D2D2D——正好等于卡片底色，整条三格条在两种模式下都是隐形的（2026-11-08 修）。
    val inset = Color(
        if (dark) QingyuTheme.scaffoldBackground(dark) else QingyuTheme.surfaceContainerHighest(dark),
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
// 只给实现阶段看效果，不进业务路径。三段入口由 `aboutInfoSections()` 现算；版本号生产环境
// 由 PackageManager 现读，Preview 读不到真值，统一用 [PreviewVersion] 注入（否则版本行整行不画，
// 评审看不到真实高度）。渲染层拿到的只有两个回调，所以只铺外观三档：
//   · 亮色 / 暗色 —— 暗色档防「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()，历史上真出现过）；
//   · 大字号 —— 行内文案 11 / 17 字的折行点，只在字被放大后才暴露。
//
// 固定写法同 ContributorsPage：主题一律包 QingyuPageTheme(isDark = …)、字号走 textScale
//（不用 @Preview(fontScale = …)）、宽度按 400dp。
// ─────────────────────────────────────────────────────────────────────────────

/**
 * 预览用假版本号：Preview 里 PackageManager 读不到真实包信息，不注入就会把版本行整行省掉，
 * 评审时看不到真实高度。取一个真实长度的版本串，三档共用。
 */
private const val PreviewVersion = "2.1.4-1 (100140)"

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
            versionOverride = PreviewVersion,
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
