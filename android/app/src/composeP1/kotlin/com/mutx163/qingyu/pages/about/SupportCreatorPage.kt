package com.mutx163.qingyu.pages.about

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.TabRowDefaults
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Edit
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.icon.extended.Show
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 支持作者页 · Compose 渲染层（Phase 3，2026-11-02 版式重排）。
 *
 * 对照 Flutter `lib/screens/support_creator_screen.dart`（782 行）：
 * 紧凑头图（图标 + 「运行中」徽标 + 能力胶囊）+ 收款卡（**真二维码图** + 点击放大 +
 * 保存到相册 + 「已支持」提示）+ 鸣谢名单。
 *
 * ## 本轮（2026-11-02）修的观感问题
 *
 * 1. 顶栏标题不再复用 [SupportCreatorStrings.heroTitle]，改用 [SupportCreatorStrings.pageTitle]
 *    （进页不再连读两遍同一句）；
 * 2. 收款方式从「卡片里套卡片」换成官方 `TabRowWithContour` 分段控件；
 * 3. 二维码**按素材原始宽高比**显示（素材是 1325×1806 / 1182×1772 的竖版海报，
 *    旧版套 1:1 方框导致左右空带、二维码本身只有指甲盖大）；
 * 4. 收款卡改成单列纵向，二维码居中，保存/已支持同高一排、主次分明；
 * 5. 鸣谢名单合并成一张卡（分组标题 + 说明 + 更新时间 + 刷新 + 分隔线行），
 *    不再一人一张卡；卡片的 title / subtitle / subtitleNote 三个字段都渲染出来；
 * 6. 名单加载成功后也有手动刷新入口；刷新失败时保留旧名单。
 *
 * ## 数据从哪来
 *
 * 鸣谢名单由宿主喂 [donorData] / [isLoading] / [loadError] / [onReload]。
 * 2026-10-29（F09）起宿主是 [SupportCreatorHostPage]：官方 raw 为主、GitCode 直连兜底
 * （见 `SupportDonorsFeed`），成功显示名单、失败显示真原因并给重试入口。
 *
 * ## 文案纪律
 *
 * 无中文字面量，全部取自 main 层 [SupportCreatorStrings]。[loadError] 是**诊断码**
 * （`http_404` 这类 ASCII），不经 ARB——它是排查信息，不是界面文案。
 */
@Composable
fun SupportCreatorPage(
    donorData: SupportDonorData?,
    onBack: () -> Unit,
    onReload: () -> Unit,
    isLoading: Boolean = false,
    loadError: String? = null,
) {
    var method by remember { mutableStateOf(SupportMethod.WECHAT) }
    var previewOpen by remember { mutableStateOf(false) }

    val assetPath = if (method == SupportMethod.WECHAT) wechatQrAsset else alipayQrAsset
    val fileName = if (method == SupportMethod.WECHAT) wechatQrFileName else alipayQrFileName

    QingyuPageScaffold(title = SupportCreatorStrings.pageTitle, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // ── 头卡：图标 + 运行中 + 副标题 + 能力胶囊 ──
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    SupportHeroCard()
                }
            }

            // ── 收款卡：分段控件 + 原始宽高比二维码 + 主次按钮 ──
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    PaymentCard(
                        method = method,
                        onMethodSelected = { method = it },
                        onOpenPreview = { previewOpen = true },
                    )
                }
            }

            // ── 鸣谢区：分组标题独立，内容合并成一张卡 ──
            item {
                QingyuSectionTitle(
                    text = donorData?.title?.takeIf { it.isNotEmpty() }
                        ?: SupportCreatorStrings.donorListTitle,
                    // 列表已经加了 12dp，而 SmallTitle 默认横向内边距 28dp ⇒ 标题左缘 40dp，
                    // 比卡内文字（12 + 16 = 28dp）右移 12dp。左移 12dp 落回同一条轴线。
                    // TODO: 共享件 `QingyuSectionTitle` 合入 `insideMargin` 参数后，
                    //  这一行应换成 `insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp)`。
                    modifier = Modifier.offset(x = (-12).dp),
                )
            }
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    // 名单行自己控制内边距（16dp）；卡片再给会变成 32dp。
                    insideMargin = PaddingValues(0.dp),
                ) {
                    DonorCard(
                        donorData = donorData,
                        isLoading = isLoading,
                        loadError = loadError,
                        onReload = onReload,
                    )
                }
            }
        }
    }

    // 弹层常驻组合、只翻 show：包在 `if (previewOpen)` 里会让关闭时的下滑退场一次都不播
    // （2026-11-02 弹窗审核 P3）。内容取值都来自页面状态（method 派生），没有可空载荷，
    // 不需要退场快照。
    QingyuSheet(
        show = previewOpen,
        title = SupportCreatorStrings.scanTitleFor(method),
        onDismissRequest = { previewOpen = false },
        // 预览列自己留 4dp 呼吸：保持套件侧边距 ⇒ 单边 20dp。
        contentPadsHorizontally = false,
    ) {
        QrPreview(
            assetPath = assetPath,
            fileName = fileName,
            contentDescription = SupportCreatorStrings.scanTitleFor(method),
            fallbackAspectRatio = qrFallbackAspectRatio(method),
            onClose = { previewOpen = false },
        )
    }
}

/** 紧凑头卡：应用图标 + 心形角标 + 标题/运行中 + 副标题 + 三枚能力胶囊。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SupportHeroCard() {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(modifier = Modifier.size(54.dp)) {
            Box(
                modifier = Modifier
                    .size(50.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MiuixTheme.colorScheme.surfaceContainer)
                    .border(
                        width = 1.dp,
                        color = MiuixTheme.colorScheme.outline.copy(alpha = 0.4f),
                        shape = RoundedCornerShape(14.dp),
                    ),
            ) {
                QingyuAssetImage(
                    assetPath = launcherIconAsset,
                    modifier = Modifier.fillMaxSize(),
                )
            }
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 2.dp, y = 2.dp)
                    .size(18.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(MiuixTheme.colorScheme.primary),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = MiuixIcons.Favorites,
                    contentDescription = null,
                    tint = MiuixTheme.colorScheme.onPrimary,
                    modifier = Modifier.size(10.dp),
                )
            }
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = SupportCreatorStrings.heroTitle,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = Color(QingyuTheme.primaryText(dark)),
                    modifier = Modifier.weight(1f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                RunningBadge()
            }
            Text(
                text = SupportCreatorStrings.heroSubtitle,
                style = MiuixTheme.textStyles.footnote1,
                lineHeight = 19.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            // 大字号下三枚胶囊会挤爆，用官方 FlowRow 自动换行。
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                FeatureChip(
                    label = SupportCreatorStrings.chipAdapters,
                    accent = MiuixTheme.colorScheme.primary,
                )
                FeatureChip(
                    label = SupportCreatorStrings.chipFixes,
                    accent = Color(QingyuIconColors.ORANGE),
                )
                FeatureChip(
                    label = SupportCreatorStrings.chipPolish,
                    accent = Color(QingyuTheme.success(dark)),
                )
            }
        }
    }
}

/** 「运行中」徽标：成功色 + 14% 成功色底。 */
@Composable
private fun RunningBadge() {
    val dark = isSystemInDarkTheme()
    val success = Color(QingyuTheme.success(dark))
    Text(
        text = SupportCreatorStrings.runningBadge,
        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
        color = success,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(success.copy(alpha = 0.14f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}

/**
 * 能力胶囊：13% 强调色底 + 正文色文字。
 *
 * 文字不用强调色：primary / ORANGE 在浅色底上对比度只有约 2.9:1 / 2.5:1，
 * 11sp 小字会发虚；三枚胶囊靠**底色**区分即可。
 */
@Composable
private fun FeatureChip(label: String, accent: Color) {
    val dark = isSystemInDarkTheme()
    Text(
        text = label,
        style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
        color = Color(QingyuTheme.primaryText(dark)),
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(accent.copy(alpha = 0.13f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/** 收款卡：官方分段控件 + 原始宽高比二维码 + 保存/已支持。 */
@Composable
private fun PaymentCard(
    method: SupportMethod,
    onMethodSelected: (SupportMethod) -> Unit,
    onOpenPreview: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val assetPath = if (method == SupportMethod.WECHAT) wechatQrAsset else alipayQrAsset
    val fileName = if (method == SupportMethod.WECHAT) wechatQrFileName else alipayQrFileName

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = SupportCreatorStrings.methodTitle,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.primaryText(dark)),
        )
        TabRowWithContour(
            tabs = listOf(
                SupportCreatorStrings.wechatLabel,
                SupportCreatorStrings.alipayLabel,
            ),
            // SupportMethod 的声明顺序 = 页签顺序（WECHAT = 0 / ALIPAY = 1）。
            selectedTabIndex = method.ordinal,
            onTabSelected = { index ->
                SupportMethod.entries.getOrNull(index)?.let(onMethodSelected)
            },
            minWidth = 0.dp,
            maxWidth = Dp.Infinity,
            colors = TabRowDefaults.tabRowColors(
                backgroundColor = MiuixTheme.colorScheme.secondaryVariant,
                contentColor = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                selectedBackgroundColor = MiuixTheme.colorScheme.surfaceContainerHighest,
                selectedContentColor = MiuixTheme.colorScheme.onBackground,
            ),
        )
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            QingyuCard(
                modifier = Modifier.fillMaxWidth(0.72f),
                insideMargin = PaddingValues(0.dp),
                cornerRadius = 16.dp,
                onClick = onOpenPreview,
            ) {
                // 素材是竖版支付海报（1325×1806 / 1182×1772），按原始宽高比显示；
                // 再套 1:1 方框会把海报压小、左右留两条空带。
                QingyuAssetImage(
                    assetPath = assetPath,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp)),
                    contentDescription = SupportCreatorStrings.scanTitleFor(method),
                    useNaturalAspectRatio = true,
                    // 解码完成前先用素材已知比例占位，避免首帧 0 高再撑开导致整页跳动。
                    fallbackAspectRatio = qrFallbackAspectRatio(method),
                )
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = MiuixIcons.Show,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(14.dp),
            )
            Text(
                text = SupportCreatorStrings.tapQrHint,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(
                onClick = { saveQrAndToast(context, assetPath, fileName) },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColorsPrimary(),
            ) {
                Text(SupportCreatorStrings.saveShort)
            }
            Button(
                onClick = {
                    Toast.makeText(
                        context,
                        SupportCreatorStrings.completeThanks,
                        Toast.LENGTH_SHORT,
                    ).show()
                },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(),
            ) {
                Text(SupportCreatorStrings.confirmedShort)
            }
        }
        Text(
            text = SupportCreatorStrings.hintFor(method),
            style = MiuixTheme.textStyles.footnote1,
            textAlign = TextAlign.Center,
            color = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** 放大预览：竖版海报按原始比例铺满 72% 宽，下面一句说明 + 保存/关闭两个动作。 */
@Composable
private fun QrPreview(
    assetPath: String,
    fileName: String,
    contentDescription: String,
    fallbackAspectRatio: Float,
    onClose: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            QingyuCard(
                // 0.72 而不是 0.9：竖版海报按原始比例会很高，宽一点就会把
                // 标题 + 说明 + 保存按钮挤出矮屏的一屏。
                modifier = Modifier.fillMaxWidth(0.72f),
                insideMargin = PaddingValues(0.dp),
                cornerRadius = 20.dp,
            ) {
                QingyuAssetImage(
                    assetPath = assetPath,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(20.dp)),
                    contentDescription = contentDescription,
                    useNaturalAspectRatio = true,
                    fallbackAspectRatio = fallbackAspectRatio,
                )
            }
        }
        Text(
            text = SupportCreatorStrings.scanQrSubtitle,
            style = MiuixTheme.textStyles.footnote1,
            textAlign = TextAlign.Center,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Button(
            onClick = { saveQrAndToast(context, assetPath, fileName) },
            modifier = Modifier.fillMaxWidth(),
            // Dart `_showQrPreview`：保存是普通动作（非 primary），关闭才是 isPrimary。
            colors = ButtonDefaults.buttonColors(),
        ) {
            Text(SupportCreatorStrings.saveToGallery)
        }
        Button(
            onClick = onClose,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) {
            Text(SupportCreatorStrings.closeAction)
        }
    }
}

/**
 * 鸣谢卡：加载 / 失败 / 空态 / 刷新失败但保留旧名单，四种状态都在这一张卡里。
 *
 * 分组标题在卡片外（`QingyuSectionTitle`），卡内不再重复写标题。
 */
@Composable
private fun DonorCard(
    donorData: SupportDonorData?,
    isLoading: Boolean,
    loadError: String?,
    onReload: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    when {
        isLoading && donorData == null -> Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 28.dp),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator()
        }

        loadError != null && donorData == null -> Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = SupportCreatorStrings.donorListLoadFailed,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            // 真原因照实显示（`http_404` / `network_unreachable` / `donors_payload_not_map`）。
            // 只写「加载失败」会让用户和排查的人都没法区分「断网」与「服务器上没这个文件」。
            Text(
                text = loadError,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.error(dark)),
            )
            Button(
                onClick = onReload,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(),
            ) {
                Text(SupportCreatorStrings.reloadAction)
            }
        }

        else -> Column {
            DonorCardHeader(
                donorData = donorData,
                isLoading = isLoading,
                loadError = loadError,
                onReload = onReload,
            )
            if (donorData == null || donorData.donors.isEmpty()) {
                Text(
                    text = SupportCreatorStrings.donorListEmpty,
                    style = MiuixTheme.textStyles.footnote1,
                    lineHeight = 19.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(16.dp),
                )
            } else {
                donorData.donors.forEachIndexed { index, donor ->
                    if (index > 0) {
                        HorizontalDivider(Modifier.padding(start = 56.dp))
                    }
                    DonorRow(donor)
                }
            }
        }
    }
}

/** 鸣谢卡头部：副标题 / 更新时间 + 刷新入口 + 备注条（有旧数据时刷新失败仍保留名单）。 */
@Composable
private fun DonorCardHeader(
    donorData: SupportDonorData?,
    isLoading: Boolean,
    loadError: String?,
    onReload: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Column(modifier = Modifier.padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                donorData?.subtitle?.takeIf { it.isNotEmpty() }?.let { subtitle ->
                    Text(
                        text = subtitle,
                        style = MiuixTheme.textStyles.footnote1,
                        lineHeight = 19.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }
                donorData?.updatedAt?.takeIf { it.isNotEmpty() }?.let { updatedAt ->
                    Text(
                        text = SupportCreatorStrings.updatedAtLabel(updatedAt),
                        style = MiuixTheme.textStyles.footnote2,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                )
            } else {
                IconButton(onClick = onReload) {
                    Icon(
                        imageVector = MiuixIcons.Refresh,
                        contentDescription = SupportCreatorStrings.reloadAction,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        }
        donorData?.subtitleNote?.takeIf { it.isNotEmpty() }?.let { note ->
            Row(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(MiuixTheme.colorScheme.surfaceContainerHighest)
                    .border(
                        width = 1.dp,
                        color = MiuixTheme.colorScheme.outline.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(10.dp),
                    )
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Icon(
                    imageVector = MiuixIcons.Edit,
                    contentDescription = null,
                    tint = MiuixTheme.colorScheme.primary,
                    modifier = Modifier.size(16.dp),
                )
                Text(
                    text = note,
                    style = MiuixTheme.textStyles.footnote2,
                    lineHeight = 19.sp,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
            }
        }
        // 已有旧数据但这次刷新失败：只加一行错误提示 + 重试，不把整份名单换掉。
        if (loadError != null && donorData != null) {
            Text(
                text = SupportCreatorStrings.donorListLoadFailed,
                style = MiuixTheme.textStyles.footnote2,
                color = Color(QingyuTheme.error(dark)),
                modifier = Modifier.padding(top = 8.dp),
            )
            TextButton(
                text = SupportCreatorStrings.reloadAction,
                onClick = onReload,
                modifier = Modifier.padding(top = 2.dp),
                colors = ButtonDefaults.textButtonColors(),
            )
        }
    }
}

/** 名单一行：心形底 + 名字 + 金额/日期/留言。 */
@Composable
private fun DonorRow(donor: SupportDonorEntry) {
    val dark = isSystemInDarkTheme()
    val yellow = Color(QingyuIconColors.YELLOW)
    val meta = listOfNotNull(
        donor.amount?.takeIf { it.isNotEmpty() },
        donor.date?.takeIf { it.isNotEmpty() },
        donor.message?.takeIf { it.isNotEmpty() },
    ).joinToString(" · ")

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(yellow.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Favorites,
                contentDescription = null,
                tint = yellow,
                modifier = Modifier.size(14.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = donor.name,
                style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = Color(QingyuTheme.primaryText(dark)),
            )
            meta.takeIf { it.isNotEmpty() }?.let { text ->
                Text(
                    text = text,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

/**
 * 从主 assets 读一张图并画出来（读不到时留尺寸占位，不画假图）。
 *
 * @param useNaturalAspectRatio 传 `true` 时按 `bitmap.width / bitmap.height` 约束宽高比，
 *   用于竖版支付海报（1325×1806 / 1182×1772）。图标这类已知方形的图不传。
 * @param fallbackAspectRatio bitmap 解码出来之前的占位比例。不传则占位高度为 0，
 *   首帧会从 0 撑到海报高度，整页明显跳一下；传入素材已知比例可让首帧就占住位置。
 */
@Composable
private fun QingyuAssetImage(
    assetPath: String,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    useNaturalAspectRatio: Boolean = false,
    fallbackAspectRatio: Float? = null,
) {
    val context = LocalContext.current
    val bitmap by produceState<ImageBitmap?>(initialValue = null, assetPath) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                context.assets.open(assetPath).use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
            }.getOrNull()
        }
    }
    val image = bitmap
    if (image != null) {
        val naturalRatio = if (useNaturalAspectRatio && image.height > 0) {
            image.width.toFloat() / image.height.toFloat()
        } else {
            null
        }
        Image(
            bitmap = image,
            contentDescription = contentDescription,
            contentScale = ContentScale.Fit,
            modifier = modifier.then(
                if (naturalRatio != null) Modifier.aspectRatio(naturalRatio) else Modifier,
            ),
        )
    } else {
        // 解码完成前的占位：有已知比例时先按比例撑住高度，避免首帧 0 高再跳开。
        Box(
            modifier.then(
                if (fallbackAspectRatio != null) {
                    Modifier.aspectRatio(fallbackAspectRatio)
                } else {
                    Modifier
                },
            ),
        )
    }
}

/** 保存二维码到相册并弹提示（保留原有的 Toast 反馈，不在本任务范围内改动）。 */
private fun saveQrAndToast(context: Context, assetPath: String, fileName: String) {
    val ok = saveQrToGallery(context, assetPath, fileName)
    Toast.makeText(
        context,
        if (ok) SupportCreatorStrings.savedToGallery else SupportCreatorStrings.saveToGalleryFailed,
        Toast.LENGTH_SHORT,
    ).show()
}

/** 保存二维码到相册（MediaStore，minSdk 33 直接插 `Pictures/qingyu`）。 */
private fun saveQrToGallery(context: Context, assetPath: String, fileName: String): Boolean =
    runCatching {
        val bitmap = context.assets.open(assetPath).use { BitmapFactory.decodeStream(it) }
            ?: return false
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                Environment.DIRECTORY_PICTURES + "/qingyu",
            )
        }
        val uri = context.contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            values,
        ) ?: return false
        context.contentResolver.openOutputStream(uri)?.use { output ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        } ?: return false
        true
    }.getOrDefault(false)

// 2026-11-02 资产迁移：二维码与图标落主 assets，不再读 flutter_assets/（删 Flutter 后不再生成）。
private const val launcherIconAsset = "assets/branding/launcher_icon.png"
private const val wechatQrAsset = "assets/donate/wechatpay.png"
private const val alipayQrAsset = "assets/donate/alipay.png"
private const val wechatQrFileName = "qingyu_kebiao_wechatpay.png"
private const val alipayQrFileName = "qingyu_kebiao_alipay.png"

/** 二维码素材像素比（wechatpay.png = 1325×1806，alipay.png = 1182×1772），用于解码前占位。 */
private val wechatQrAspectRatio = 1325f / 1806f
private val alipayQrAspectRatio = 1182f / 1772f

private fun qrFallbackAspectRatio(method: SupportMethod): Float = when (method) {
    SupportMethod.WECHAT -> wechatQrAspectRatio
    SupportMethod.ALIPAY -> alipayQrAspectRatio
}
