package com.mutx163.qingyu.pages.settings

import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.pages.shell.HomeBackdropScope
import com.mutx163.qingyu.pages.shell.HomeBackdropSize
import com.mutx163.qingyu.pages.shell.HomeBackdropSnapshot
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.shell.HomeWallpaperBackdrop
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 壁纸「拖动取景」页（Dart `lib/widgets/wallpaper_position_picker_sheet.dart:123-828`）。
 *
 * ## 它补的是哪个洞
 *
 * 外观编辑 → 壁纸面板 →「调整位置」原来只弹一句「不可用」：Dart 的取景页在 Kotlin 侧
 * 根本没移植（`WallpaperSheetBody.kt` 的 `wantsAdjust` 分支）。本页把它补上，写回
 * `homePageWallpaperAlignX` / `homePageWallpaperAlignY` / `homePageWallpaperScale`，
 * 首页 `HomeWallpaperBackdrop` 用同一套几何就能看到新取景。
 *
 * ## 为什么是整屏、而不是 `QingyuPageScaffold` + 列表
 *
 * Dart 这一页是**全屏取景器**：预览与首页同尺寸、同 cover、同对齐（`:703-707`），
 * 顶部「退出 / 标题 / 完成」悬浮在壁纸上（`:586-673`）。套上常规顶栏会把预览压掉一截，
 * 所见即所得就不成立（取景值虽然归一，但预览与首页的裁剪窗口不再一致）。
 * 同域已有先例：`AppearanceEditorScreen` 也是沉浸式整屏、不走页面骨架。
 *
 * 仍然使用共享套件里该用的部分：[QingyuPageTheme]（主题/字阶桥）、[QingyuCard]
 * （悬浮操作条，自带按压反馈与语义圆角）、`MiuixTheme.textStyles.*` 与
 * `MiuixTheme.colorScheme.*`；没有写死字号/圆角/十六进制颜色。
 *
 * ## 交互契约（逐项照 Dart，纯运算在 [SettingsWallpaperPositionPage]）
 *
 * * **拖动**：单指拖动与双指捏合同一个 `transformable` 手势；拖动位移按「当前倍数下的
 *   真实溢出」折算，内容与手指 1:1；对齐值夹 [-1, 1]，该轴不溢出时归 0；
 * * **缩放**：倍数夹 1..4，绕对齐点放大（绘制由 `HomeWallpaperBackdrop` 的
 *   `drawRect` 完成，与首页同一份几何）；
 * * **重置**：位置与缩放一起回 0 / 0 / 1（`:473-483`）；
 * * **退出（系统返回 / 左按钮）**：不写任何设置，直接返回（Dart `confirmed = false`）；
 * * **完成**：写路径 + 三个取景值，并把这幅图的「最近使用」条目更新为新取景，然后返回
 *   （Dart `:1069-1091`）。
 *
 * ## 已知差异（照实写）
 *
 * 1. **没有「换壁纸」按钮**：Dart 这一页可以就地再选一张图（`:663-667`）。本仓的受管
 *    壁纸目录 / 选图落盘链路还没有像 Dart `pickAndStoreManagedImage` 那样的公共入口，
 *    所以按 Dart「传 `onPickNewImage = null` 时只显示重置」的那一支实现 —— 不是忘了做，
 *    是不假装做了；
 * 2. **状态栏图标极性没跟着壁纸亮度翻**：Dart 会采样壁纸顶部亮度再切深浅图标
 *    （`:518-521`）。本页沿用壳的默认状态栏样式，深色壁纸下图标可能不够醒目；
 * 3. **落盘失败只记日志 + 一句「保存失败」**：与外观编辑页 / Bing 图库同一处理
 *    （`AppearanceEditorHost` 是 `Log.e`，`BingGalleryHost` 多弹一句），不静默回滚。
 *
 * @param store 设置模型读写（壳里 `wiring.settingsModel`）；与外观编辑页共用同一个
 *   `timetable_settings` 键与合并写。返回上一页时编辑器会重新 `load()`，看到的就是新值。
 * @param onBack 返回（保存成功后由本页调用；取消时直接调用）。
 */
@Composable
fun WallpaperPositionPickerHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    // 进页那一刻的取景就是初值（Dart `_alignX = widget.initialAlignX`，`:287-289`）。
    // 只读一次：本页存活期间没有别人能改这份设置。
    val openedWith = remember(store) { store.load() }
    val wallpaperPath = openedWith.homePageWallpaperPath
    val hasWallpaper = !wallpaperPath.isNullOrBlank()

    var alignX by rememberSaveable {
        mutableStateOf(SettingsWallpaperPositionPage.clampAlign(openedWith.homePageWallpaperAlignX))
    }
    var alignY by rememberSaveable {
        mutableStateOf(SettingsWallpaperPositionPage.clampAlign(openedWith.homePageWallpaperAlignY))
    }
    var scale by rememberSaveable {
        mutableStateOf(SettingsWallpaperPositionPage.clampScale(openedWith.homePageWallpaperScale))
    }

    // 预览区尺寸（物理像素）：拖动折算的分母与解码宽都从这里来。
    var viewport by remember { mutableStateOf(IntSize.Zero) }
    // 图片原始尺寸（已按 EXIF 摆正）：尺寸没到之前拖动是空操作（Dart `:708-710`）。
    var imageSize by remember(wallpaperPath) { mutableStateOf<HomeBackdropSize?>(null) }
    var imageUnavailable by remember(wallpaperPath) { mutableStateOf(false) }

    LaunchedEffect(wallpaperPath) {
        if (wallpaperPath.isNullOrBlank()) {
            imageSize = null
            imageUnavailable = false
            return@LaunchedEffect
        }
        // 只读头部拿宽高，不解码像素（Dart `:328-374` 的同一口径）。
        val size = withContext(Dispatchers.IO) { readOrientedSize(wallpaperPath) }
        imageSize = size
        imageUnavailable = size == null
    }

    val transformState = rememberTransformableState { zoomChange, panChange, _ ->
        // 顺序与 Dart 一致：先算新倍数，再用**新倍数**下的溢出量折算拖动
        // （`:742-762`；分母取小的那一版会让放大后「拖一点就飞」）。
        val nextScale = SettingsWallpaperPositionPage.scaleAfterPinch(scale, zoomChange.toDouble())
        val image = imageSize
        val overflowX = if (image != null) {
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = viewport.width,
                viewportHeight = viewport.height,
                imageWidth = image.width,
                imageHeight = image.height,
                horizontal = true,
                scale = nextScale,
            )
        } else {
            0.0
        }
        val overflowY = if (image != null) {
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = viewport.width,
                viewportHeight = viewport.height,
                imageWidth = image.width,
                imageHeight = image.height,
                horizontal = false,
                scale = nextScale,
            )
        } else {
            0.0
        }
        alignX = SettingsWallpaperPositionPage.alignAfterDrag(
            previousAlign = alignX,
            dragDelta = panChange.x.toDouble(),
            overflowExtent = overflowX,
        )
        alignY = SettingsWallpaperPositionPage.alignAfterDrag(
            previousAlign = alignY,
            dragDelta = panChange.y.toDouble(),
            overflowExtent = overflowY,
        )
        scale = nextScale
    }

    val snapshot = remember(wallpaperPath, alignX, alignY, scale, viewport) {
        HomeBackdropSnapshot(
            wallpaperPath = wallpaperPath,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
            // 取景页看的是原图（Dart 的 `Image` 不套模糊，`:774-822`）。
            blurSigma = 0.0,
            decodeWidthPx = HomeBackgroundModel.decodeWidthPx(
                viewport.width.takeIf { it > 0 },
            ),
            scope = HomeBackdropScope.DEFAULT,
            pageColorArgb = Color.Black.toArgb(),
            // 取景时背景不跟周页滑动。
            followsWeekPager = false,
        )
    }

    /** 「完成」：写回并返回。Dart `_confirm`（`:497-507`）+ `:1069-1091`。 */
    fun confirm() {
        val path = wallpaperPath ?: return onBack()
        // 现读一份再合并写：与 BingGalleryHost / 外观编辑页同一条落盘路径，
        // 不会把本页不拥有的键覆盖掉。
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = store.load(),
            path = path,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
        ) ?: return onBack()
        val saved = runCatching { store.save(next) }
        if (saved.isFailure) {
            Log.e(LOG_TAG, "save wallpaper framing failed", saved.exceptionOrNull())
            Toast.makeText(
                context,
                SettingsStringsExt2.saveFailed.zh,
                Toast.LENGTH_SHORT,
            ).show()
            return
        }
        onBack()
    }

    QingyuPageTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                // 壁纸解码出来之前的那层底。Dart 也是 `Scaffold(backgroundColor: Colors.black)`：
                // 取景器里的黑是**固定语义色**（照片衬底），不跟主题明暗走。
                .background(Color.Black),
        ) {
            when {
                hasWallpaper && !imageUnavailable -> HomeWallpaperBackdrop(
                    snapshot = snapshot,
                    modifier = Modifier
                        .fillMaxSize()
                        .onSizeChanged { viewport = it }
                        .transformable(transformState),
                )

                else -> Box(modifier = Modifier.fillMaxSize())
            }

            // 没有壁纸 / 图片文件丢了：一句实话 + 只剩「退出」可用（Dart 在进页前就会
            // 拦掉这两种情况，`:1135-1166`；这里兜住「从壳的页面索引直接进来」）。
            if (!hasWallpaper || imageUnavailable) {
                QingyuCard(
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 24.dp),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    Column {
                        Text(
                            text = if (!hasWallpaper) {
                                SettingsStringsExt1.homePageImageNotSelected.zh
                            } else {
                                SettingsStringsExt1.homePageWallpaperFileMissingTitle.zh
                            },
                            style = MiuixTheme.textStyles.body1,
                            color = MiuixTheme.colorScheme.onBackground,
                        )
                        if (imageUnavailable) {
                            Text(
                                text = SettingsStringsExt1.homePageWallpaperFileMissingSubtitle.zh,
                                style = MiuixTheme.textStyles.body2,
                                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    }
                }
            }

            // 顶部悬浮操作条：退出 / 标题 / 完成（Dart `:596-644`）。
            QingyuCard(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .statusBarsPadding()
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .fillMaxWidth(),
                insideMargin = QingyuCardDefaults.ContentInsideMargin,
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(
                        text = SettingsWallpaperPositionPage.EXIT.zh,
                        onClick = onBack,
                    )
                    Text(
                        text = SettingsWallpaperPositionPage.TITLE.zh,
                        modifier = Modifier.weight(1f),
                        style = MiuixTheme.textStyles.body1,
                        color = MiuixTheme.colorScheme.onBackground,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                    )
                    TextButton(
                        text = SettingsWallpaperPositionPage.DONE.zh,
                        onClick = { confirm() },
                        enabled = hasWallpaper && !imageUnavailable,
                        colors = ButtonDefaults.textButtonColorsPrimary(),
                    )
                }
            }

            // 底部「重置」（Dart `:650-669`；没有 onPickNewImage 时只留这一颗）。
            if (hasWallpaper && !imageUnavailable) {
                QingyuCard(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                        .padding(horizontal = 12.dp, vertical = 24.dp)
                        .fillMaxWidth(),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,
                ) {
                    TextButton(
                        text = SettingsWallpaperPositionPage.RESET.zh,
                        onClick = {
                            alignX = WallpaperFraming.DEFAULT.alignX
                            alignY = WallpaperFraming.DEFAULT.alignY
                            scale = WallpaperFraming.DEFAULT.scale
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

/**
 * 读图片的原始尺寸并按 EXIF 摆正（只读头部，不解码像素）。
 *
 * 与 Dart `_resolveImageSize`（`:332-374`）同一件事；方向规则复用
 * `HomeBackgroundModel.exifRotationDegrees` / `orientedSize`，保证与首页画出来的
 * 裁剪窗口同源（90°/270° 的照片宽高对调后，拖动溢出量才对得上）。
 *
 * 文件缺失 / 损坏返回 null：本页据此显示「图片文件已丢失」，而不是让异常冒到全局。
 */
private fun readOrientedSize(path: String): HomeBackdropSize? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    val orientation = runCatching {
        ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
    }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
    return HomeBackgroundModel.orientedSize(
        width = bounds.outWidth,
        height = bounds.outHeight,
        rotationDegrees = HomeBackgroundModel.exifRotationDegrees(orientation),
    )
}

private const val LOG_TAG = "wallpaper-position-picker"
