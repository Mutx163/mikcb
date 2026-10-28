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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 支持作者页 · Compose 渲染层（Phase 3，2026-10-28 补真实二维码/保存/徽标）。
 *
 * 对照 Flutter `lib/screens/support_creator_screen.dart`（782 行）：
 * 紧凑头图（图标 + 「运行中」徽标 + 能力胶囊）+ 收款卡（**真二维码图** + 点击放大 +
 * 保存到相册 + 「已支持」提示）+ 鸣谢名单。
 *
 * ## 本轮补上的关键件
 *
 * 1. 二维码从 `flutter_assets/assets/donate/{wechatpay,alipay}.png` 真读（此前是占位文字）；
 * 2. 点击二维码弹出放大弹层（[OverlayBottomSheet]）；
 * 3. 保存到相册走 MediaStore（minSdk 33，直接插 `Pictures/qingyu`）；
 * 4. 头图有应用图标 + 「运行中」徽标。
 *
 * ## 仍依赖宿主的部分
 *
 * 鸣谢名单仍由宿主喂 [donorData]（Compose 侧还没有移植 `SupportCreatorService` 的网络拉取），
 * 宿主喂 null 时显示 Flutter 同款空态文案。
 *
 * ## 文案纪律
 *
 * 无中文字面量，全部取自 main 层 [SupportCreatorStrings]。
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
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current

    val assetPath = if (method == SupportMethod.WECHAT) wechatQrAsset else alipayQrAsset
    val fileName = if (method == SupportMethod.WECHAT) wechatQrFileName else alipayQrFileName

    QingyuPageScaffold(title = SupportCreatorStrings.heroTitle, onBack = onBack) {
        QingyuPageList(
            // 同 AboutStaticPage：innerPadding 只给 top，底部手势条高度显式算进 contentPadding，
            // 避免 QingyuPageList 内部再加一次 bottom 造成重复。
            innerPadding = PaddingValues(top = innerPadding.calculateTopPadding()),
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = innerPadding.calculateBottomPadding() + 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // ── 紧凑头图 ──
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    SupportHeroCard()
                }
            }

            // ── 收款方式卡 ──
            item {
                QingyuCard(
                    modifier = Modifier.fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = SupportCreatorStrings.methodTitle,
                            style = MiuixTheme.textStyles.body2,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            MethodTab(
                                label = SupportCreatorStrings.wechatLabel,
                                selected = method == SupportMethod.WECHAT,
                                onClick = { method = SupportMethod.WECHAT },
                            )
                            MethodTab(
                                label = SupportCreatorStrings.alipayLabel,
                                selected = method == SupportMethod.ALIPAY,
                                onClick = { method = SupportMethod.ALIPAY },
                            )
                        }
                        Text(
                            text = SupportCreatorStrings.scanTitleFor(method),
                            style = MiuixTheme.textStyles.body2,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            // 左：真二维码（点击放大）
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(Color(QingyuTheme.surfaceContainer(dark)))
                                    .padding(8.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                QingyuAssetImage(
                                    assetPath = assetPath,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .aspectRatio(1f)
                                        .clip(RoundedCornerShape(8.dp))
                                        .clickable { previewOpen = true },
                                )
                            }
                            // 右：保存 / 已支持 / 提示
                            Column(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Button(
                                    onClick = {
                                        val ok = saveQrToGallery(context, assetPath, fileName)
                                        Toast.makeText(
                                            context,
                                            if (ok) SupportCreatorStrings.savedToGallery
                                            else SupportCreatorStrings.saveToGalleryFailed,
                                            Toast.LENGTH_SHORT,
                                        ).show()
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(),
                                ) {
                                    Text(SupportCreatorStrings.saveShort)
                                }
                                TextButton(
                                    text = SupportCreatorStrings.confirmedShort,
                                    onClick = {
                                        Toast.makeText(
                                            context,
                                            SupportCreatorStrings.completeThanks,
                                            Toast.LENGTH_SHORT,
                                        ).show()
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.textButtonColors(),
                                )
                                Text(
                                    text = SupportCreatorStrings.hintFor(method),
                                    style = MiuixTheme.textStyles.footnote2,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            Icon(
                                imageVector = MiuixIcons.Favorites,
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
                    }
                }
            }

            item { QingyuSectionTitle(SupportCreatorStrings.donorListTitle) }

            when {
                isLoading -> item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        CircularProgressIndicator()
                    }
                }

                loadError != null -> item {
                    QingyuRow(
                        title = SupportCreatorStrings.donorListLoadFailed,
                        icon = {
                            Icon(
                                imageVector = MiuixIcons.Refresh,
                                contentDescription = null,
                                tint = Color(QingyuIconColors.ORANGE),
                            )
                        },
                        onClick = onReload,
                    )
                }

                donorData == null || donorData.donors.isEmpty() -> item {
                    QingyuCard(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = QingyuCardDefaults.ContentInsideMargin,
                    ) {
                        Text(
                            text = SupportCreatorStrings.donorListEmpty,
                            style = MiuixTheme.textStyles.footnote1,
                            lineHeight = 19.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                }

                else -> {
                    donorData.updatedAt?.takeIf { it.isNotEmpty() }?.let { updatedAt ->
                        item {
                            Text(
                                text = SupportCreatorStrings.updatedAtLabel(updatedAt),
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(start = 4.dp),
                            )
                        }
                    }
                    for (donor in donorData.donors) {
                        item { DonorRow(donor) }
                    }
                }
            }
        }
    }

    if (previewOpen) {
        OverlayBottomSheet(
            show = true,
            title = SupportCreatorStrings.scanTitleFor(method),
            onDismissRequest = { previewOpen = false },
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color(QingyuTheme.surfaceContainer(dark)))
                        .padding(12.dp),
                ) {
                    QingyuAssetImage(
                        assetPath = assetPath,
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(12.dp)),
                    )
                }
                Text(
                    text = SupportCreatorStrings.scanQrSubtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    textAlign = TextAlign.Center,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Button(
                    onClick = {
                        val ok = saveQrToGallery(context, assetPath, fileName)
                        Toast.makeText(
                            context,
                            if (ok) SupportCreatorStrings.savedToGallery
                            else SupportCreatorStrings.saveToGalleryFailed,
                            Toast.LENGTH_SHORT,
                        ).show()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(),
                ) {
                    Text(SupportCreatorStrings.saveToGallery)
                }
            }
        }
    }
}

/** 紧凑头图：应用图标 + 「运行中」徽标 + 标题 + 副标题 + 三个能力胶囊。 */
@Composable
private fun SupportHeroCard() {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        QingyuAssetImage(
            assetPath = "flutter_assets/assets/branding/launcher_icon.png",
            modifier = Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)),
        )
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = SupportCreatorStrings.heroTitle,
                    style = MiuixTheme.textStyles.body1,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.primaryText(dark)),
                )
                Text(
                    text = SupportCreatorStrings.runningBadge,
                    style = MiuixTheme.textStyles.footnote2,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(QingyuTheme.success(dark)),
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color(QingyuTheme.success(dark)).copy(alpha = 0.14f))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
            Text(
                text = SupportCreatorStrings.heroSubtitle,
                style = MiuixTheme.textStyles.footnote1,
                lineHeight = 18.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                FeatureChip(SupportCreatorStrings.chipFixes)
                FeatureChip(SupportCreatorStrings.chipAdapters)
                FeatureChip(SupportCreatorStrings.chipPolish)
            }
        }
    }
}

/** 能力胶囊（Dart `_FeatureCapsule`）：弱底色 + 圆角。 */
@Composable
private fun FeatureChip(label: String) {
    val dark = isSystemInDarkTheme()
    Text(
        text = label,
        style = MiuixTheme.textStyles.footnote2,
        color = Color(QingyuTheme.secondaryText(dark)),
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(Color(QingyuTheme.surfaceContainer(dark)))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/** 收款方式/操作按钮：官方 Card 可点击重载，选中态用强调色区分。 */
@Composable
private fun MethodTab(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
        onClick = onClick,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) {
                Color(QingyuTheme.primary(dark = dark))
            } else {
                Color(QingyuTheme.primaryText(dark))
            },
        )
    }
}

/** 名单一行：名字 + 金额/日期/留言。 */
@Composable
private fun DonorRow(donor: SupportDonorEntry) {
    val dark = isSystemInDarkTheme()
    val meta = listOfNotNull(
        donor.amount?.takeIf { it.isNotEmpty() },
        donor.date?.takeIf { it.isNotEmpty() },
        donor.message?.takeIf { it.isNotEmpty() },
    ).joinToString(" · ")

    QingyuRow(
        title = donor.name,
        subtitle = meta.takeIf { it.isNotEmpty() },
        icon = {
            Icon(
                imageVector = MiuixIcons.Favorites,
                contentDescription = null,
                tint = Color(QingyuIconColors.YELLOW),
            )
        },
    )
}

/** 从 `flutter_assets` 读一张图并画出来（读不到时留尺寸占位，不画假图）。 */
@Composable
private fun QingyuAssetImage(assetPath: String, modifier: Modifier = Modifier) {
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
        Image(
            bitmap = image,
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = modifier,
        )
    } else {
        Box(modifier)
    }
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

private const val wechatQrAsset = "flutter_assets/assets/donate/wechatpay.png"
private const val alipayQrAsset = "flutter_assets/assets/donate/alipay.png"
private const val wechatQrFileName = "qingyu_kebiao_wechatpay.png"
private const val alipayQrFileName = "qingyu_kebiao_alipay.png"
