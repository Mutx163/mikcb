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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
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
import top.yukonga.miuix.kmp.basic.TabRowDefaults
import top.yukonga.miuix.kmp.basic.TabRowWithContour
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
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
 * ## 2026-11-08 第二轮：鸣谢卡收口
 *
 * 用户对着预览截图说「这块框选区域看着有点奇怪」。卡头原来把副标题 / 更新时间 / 留言提示三档字
 * 和一颗刷新键堆在一起，铅笔图标还把文字推开一条锯齿边、挤出一个孤字行。现在改成
 * 「说明 → 名单 → 元信息」三段：卡头只留一句副标题，刷新键上顶栏，时间与提示降卡尾。
 * 逐条理由（含旧版挂在哪）见 [DonorCard] 与 [DonorCardFooter] 的头注。
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
    // 顶栏动作键的配色：骨架内部的 `QingyuPageTheme` 只影响它自己的子树，
    // 这里取同一个来源（各页一致做法，如版本更新页 / 性能报告页）。
    val dark = isSystemInDarkTheme()

    val assetPath = if (method == SupportMethod.WECHAT) wechatQrAsset else alipayQrAsset
    val fileName = if (method == SupportMethod.WECHAT) wechatQrFileName else alipayQrFileName

    QingyuPageScaffold(
        title = SupportCreatorStrings.pageTitle,
        onBack = onBack,
        // 名单是本页唯一的网络动作，刷新键放顶栏右上（与版本更新页同一处）：
        // 原先它挂在鸣谢卡头右侧、跟两行说明字顶对齐，右边一大片空 —— 就是「浮在卡里」那颗 ↻。
        // 刷新中把图标换成转圈（共享件的内容槽），按钮位置与尺寸不变，顶栏不会跳。
        actions = {
            QingyuGlassIconButton(
                onClick = onReload,
                contentDescription = SupportCreatorStrings.reloadAction,
                icon = MiuixIcons.Refresh,
                tint = Color(QingyuTheme.actionIcon(dark)),
                enabled = !isLoading,
                content = if (isLoading) {
                    {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                        )
                    }
                } else {
                    null
                },
            )
        },
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = AboutPageListBottomPadding),
            verticalArrangement = AboutPageListSpacing,
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
                // 标题内边距收 16dp（+列表 12dp = 官方 28dp 轴线）。原先用
                // `Modifier.offset(-12dp)` 硬掰，2026-11-03 共享件出了 `insideMargin`
                // 参数后按它自己的 TODO 换成正式口径。
                QingyuSectionTitle(
                    text = donorData?.title?.takeIf { it.isNotEmpty() }
                        ?: SupportCreatorStrings.donorListTitle,
                    insideMargin = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
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
            // 配色必须自带对比，不能靠「容器色差一档」：
            //
            // 2026-11-08 用户实报「微信/支付宝切换器看不到，颜色和背景一样」。原先是
            // 轨道 `secondaryVariant`(#E6E6E6) + 选中块 `surfaceContainerHighest`(#E8E8E8)，
            // 两者只差 2/255，等于选中块隐形；暗色下选中块 `#2D2D2D` 又与本页卡片底色
            // **完全同色**，同样看不见。根因是这排控件放在白/深卡片**内部**，而那两个槽
            // 是给「页底 + 卡片」两层关系设计的，用在卡片里就没有台阶了。
            //
            // 现在改成三段彼此分得开：轨道 = `secondary`（亮 #E6E6E6 / 暗 #505050，压在
            // 卡片上仍有轮廓）、选中块 = 主题色实底 + `onPrimary` 墨（与主按钮同一套，
            // 选中态一眼可辨，深色模式也成立）、未选中墨 = `fieldLabel`（亮 #5A5A5A /
            // 暗 #B8B8B8），比正文次墨 #999 在灰轨道上更清楚。
            colors = TabRowDefaults.tabRowColors(
                backgroundColor = MiuixTheme.colorScheme.secondary,
                contentColor = Color(QingyuTheme.fieldLabel(dark)),
                selectedBackgroundColor = MiuixTheme.colorScheme.primary,
                selectedContentColor = MiuixTheme.colorScheme.onPrimary,
            ),
        )
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            // 内容/展示类卡片圆角统一走默认 16（[QingyuCardDefaults.Corner]）；
            // 显式传参收掉，避免同层出现第二种圆角。
            QingyuCard(
                modifier = Modifier.fillMaxWidth(0.72f),
                insideMargin = PaddingValues(0.dp),
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
                // 内容/展示类卡片圆角统一默认 16（原 20 与收款卡同层不同角，已收）。
                modifier = Modifier.fillMaxWidth(0.72f),
                insideMargin = PaddingValues(0.dp),
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
 *
 * ## 2026-11-08 版式重排（用户实报「这块框选区域看着有点奇怪」）
 *
 * 上一版把三档字全堆在卡头：副标题、更新时间、留言提示，右侧再挂一颗 40dp 刷新键。问题不是
 * 字多，而是**三种不同性质的信息被摆成了同一档**：
 *
 * 1. 刷新键跟两行文字顶端对齐，右边留一大片空 —— 看着像一颗浮在卡里的 ↻；
 * 2. 留言提示前面挂的是铅笔（`MiuixIcons.Edit`）—— 那是「编辑」的语义，文案却在讲同步；
 * 3. 铅笔把第二行推到 35dp 起排，与上面 16dp 起排的正文错开一条锯齿边；
 * 4. 提示句约 31 字，被铅笔和右侧热区挤窄后正好折出「现。」两个字**孤字成行**。
 *
 * 现在按「说明 → 名单 → 元信息」三段收口：
 *
 * - **卡头**只剩一句副标题（`footnote1`，13sp）+ 一条内缩分隔线，回答「这张卡是什么」；
 * - **刷新**移到顶栏右上（见 [SupportCreatorPage] 的 `actions`）—— 名单是本页唯一的网络
 *   动作，放顶栏既不占卡内版面，也不用再跟卡头文字对齐；
 * - **更新时间与留言提示**降到卡尾（`footnote2`，11sp，内缩细线隔开）：日期是最不该第一个被
 *   读到的信息（版本更新页同一结论），提示句回到整宽、不再被图标挤成孤字行。
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

        else -> {
            val subtitle = donorData?.subtitle?.takeIf { it.isNotEmpty() }
            val updatedAt = donorData?.updatedAt?.takeIf { it.isNotEmpty() }
            val note = donorData?.subtitleNote?.takeIf { it.isNotEmpty() }
            Column {
                if (subtitle != null || loadError != null) {
                    Column(
                        modifier = Modifier.padding(
                            start = 16.dp,
                            end = 16.dp,
                            top = 14.dp,
                            bottom = 12.dp,
                        ),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        subtitle?.let {
                            Text(
                                text = it,
                                style = MiuixTheme.textStyles.footnote1,
                                lineHeight = 19.sp,
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        }
                        // 已有旧名单但这轮刷新失败：只加一行错误提示，不把整份名单换掉。
                        // 重试入口就是顶栏那颗刷新键（不再在卡头里多坐一个文字按钮）。
                        if (loadError != null) {
                            Text(
                                text = SupportCreatorStrings.donorListLoadFailed,
                                style = MiuixTheme.textStyles.footnote2,
                                color = Color(QingyuTheme.error(dark)),
                            )
                        }
                    }
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        color = MiuixTheme.colorScheme.dividerLine,
                    )
                }
                if (donorData == null || donorData.donors.isEmpty()) {
                    Text(
                        text = SupportCreatorStrings.donorListEmpty,
                        style = MiuixTheme.textStyles.footnote1,
                        lineHeight = 19.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    )
                } else {
                    donorData.donors.forEach { donor ->
                        DonorRow(donor)
                    }
                }
                DonorCardFooter(updatedAt = updatedAt, note = note)
            }
        }
    }
}

/**
 * 鸣谢卡尾部元信息：更新时间 + 同步说明，顶部一条内缩细线。
 *
 * 2026-11-08 从卡头降到卡尾（版式理由见 [DonorCard] 头注）：
 *
 * - 两行都是 `footnote2`（11sp）弱色，与上面 `body1` 的名单名字拉开三个字阶；
 * - 不再带铅笔图标 —— `MiuixIcons.Edit` 的语义是「编辑」，文案说的却是同步时间；
 * - 提示句回到**整宽**（左右各 16dp，无图标占位），上一版被图标挤窄后折出「现。」孤字行；
 * - 名单行本身不带线，这条细线是把「名单」和「说明」分开的唯一分界（与卡头那条对称）。
 */
@Composable
private fun DonorCardFooter(updatedAt: String?, note: String?) {
    if (updatedAt == null && note == null) return
    val dark = isSystemInDarkTheme()
    Column {
        HorizontalDivider(
            modifier = Modifier.padding(horizontal = 16.dp),
            color = MiuixTheme.colorScheme.dividerLine,
        )
        Column(
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            updatedAt?.let {
                Text(
                    text = SupportCreatorStrings.updatedAtLabel(it),
                    style = MiuixTheme.textStyles.footnote2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
            note?.let {
                Text(
                    text = it,
                    style = MiuixTheme.textStyles.footnote2,
                    lineHeight = 18.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
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
// 2026-11-03 修路径：AssetManager 的路径本就相对 APK 的 assets 根，写 `assets/donate/…`
// 会找成 assets/assets/…，必 FileNotFound 且被 runCatching 吞掉（症状：二维码不显示、
// 只剩占位框）。改裸路径，与 docs/releases / licenses / lan_edit 同一口径。
private const val launcherIconAsset = "branding/launcher_icon.png"
private const val wechatQrAsset = "donate/wechatpay.png"
private const val alipayQrAsset = "donate/alipay.png"
private const val wechatQrFileName = "qingyu_kebiao_wechatpay.png"
private const val alipayQrFileName = "qingyu_kebiao_alipay.png"

/** 二维码素材像素比（wechatpay.png = 1325×1806，alipay.png = 1182×1772），用于解码前占位。 */
private val wechatQrAspectRatio = 1325f / 1806f
private val alipayQrAspectRatio = 1182f / 1772f

private fun qrFallbackAspectRatio(method: SupportMethod): Float = when (method) {
    SupportMethod.WECHAT -> wechatQrAspectRatio
    SupportMethod.ALIPAY -> alipayQrAspectRatio
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 ContributorsPage 样板铺）
//
// 只给实现阶段看效果，不进业务路径。鸣谢卡自己分五档，都是同一张卡里最容易改漏的分支：
//
//   有名单 / 空名单 / 加载中 / 首次加载失败 / 刷新失败但保留旧名单；
// 再加外观两档：暗色、大字号 1.3。
//
// 注意：二维码与图标是从 APK 资产现读的（`QingyuAssetImage`），预览里的假 Context 多半读不到，
// 会显示按素材比例占位的空框。**这是预览环境限制，不是页面 bug**；要看真图仍需装机。
//
// 固定写法同 ContributorsPage：主题一律包 QingyuPageTheme(isDark = …)、字号走 textScale、
// 宽度按 400dp。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用假数据：三位支持者，金额 / 日期 / 留言长度不一，看得出折行。 */
private fun previewDonorData(): SupportDonorData = SupportDonorData(
    title = "鸣谢名单",
    subtitle = "感谢这些同学让课表更顺手",
    subtitleNote = "名单每十分钟从仓库同步一次；刚支持过的可能要稍等片刻才会出现。",
    updatedAt = "2026-11-08 10:24",
    donors = listOf(
        SupportDonorEntry(
            name = "张三",
            amount = "￥20",
            date = "2026-11-02",
            message = "希望周视图能拖动调课",
        ),
        SupportDonorEntry(name = "李四", amount = "￥66", date = "2026-10-28"),
        SupportDonorEntry(
            name = "王五",
            amount = "￥9.9",
            date = "2026-10-20",
            message = "课表很干净，辛苦作者",
        ),
    ),
)

/**
 * 鸣谢卡的分支输入组合，五档不多不少。
 *
 * 这五档就是 `SupportCreatorHostPage` 能传给 [SupportCreatorPage] 的所有形态：
 * 有名单 / 空名单 / 加载中 / 首次加载失败 / 刷新失败但保留旧名单。
 */
private data class PreviewSupportCreatorState(
    /** 只用来给预览命名，不参与渲染。 */
    val name: String,
    val donorData: SupportDonorData?,
    val isLoading: Boolean,
    val loadError: String?,
)

private val previewSupportCreatorStates: List<PreviewSupportCreatorState> = listOf(
    PreviewSupportCreatorState(
        name = "有名单",
        donorData = previewDonorData(),
        isLoading = false,
        loadError = null,
    ),
    PreviewSupportCreatorState(
        name = "空名单",
        donorData = previewDonorData().copy(donors = emptyList()),
        isLoading = false,
        loadError = null,
    ),
    PreviewSupportCreatorState(
        name = "加载中",
        donorData = null,
        isLoading = true,
        loadError = null,
    ),
    PreviewSupportCreatorState(
        name = "首次加载失败",
        donorData = null,
        isLoading = false,
        loadError = "http_404",
    ),
    PreviewSupportCreatorState(
        name = "刷新失败保留旧名单",
        donorData = previewDonorData(),
        isLoading = false,
        loadError = "network_unreachable",
    ),
)

private fun previewSupportCreatorState(name: String): PreviewSupportCreatorState =
    previewSupportCreatorStates.first { it.name == name }

/** 一档预览的公共身体：名单状态 + 外观档位。 */
@Composable
private fun PreviewSupportCreatorPage(
    state: PreviewSupportCreatorState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        SupportCreatorPage(
            donorData = state.donorData,
            onBack = {},
            onReload = {},
            isLoading = state.isLoading,
            loadError = state.loadError,
        )
    }
}

// ── 单档：五态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有名单", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewDonors() {
    PreviewSupportCreatorPage(previewSupportCreatorState("有名单"))
}

@Suppress("unused")
@Preview(name = "2 空名单", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewEmpty() {
    PreviewSupportCreatorPage(previewSupportCreatorState("空名单"))
}

@Suppress("unused")
@Preview(name = "3 加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewLoading() {
    PreviewSupportCreatorPage(previewSupportCreatorState("加载中"))
}

@Suppress("unused")
@Preview(name = "4 首次加载失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewLoadFailed() {
    PreviewSupportCreatorPage(previewSupportCreatorState("首次加载失败"))
}

@Suppress("unused")
@Preview(name = "5 刷新失败保留旧名单", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewRefreshFailed() {
    PreviewSupportCreatorPage(previewSupportCreatorState("刷新失败保留旧名单"))
}

// ── 单档：外观两档（以「有名单」为基准）───────────────────────────────────

@Suppress("unused")
@Preview(name = "6 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewDark() {
    PreviewSupportCreatorPage(previewSupportCreatorState("有名单"), dark = true)
}

@Suppress("unused")
@Preview(name = "7 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun SupportCreatorPagePreviewLargeText() {
    PreviewSupportCreatorPage(previewSupportCreatorState("有名单"), textScale = 1.3f)
}
