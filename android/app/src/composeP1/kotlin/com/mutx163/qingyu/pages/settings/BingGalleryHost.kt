package com.mutx163.qingyu.pages.settings

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.platform.AndroidImageLoader
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import com.mutx163.qingyu.weather.BingWallpaperItem
import com.mutx163.qingyu.weather.WallpaperTargetSize
import java.io.File
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * Bing 每日壁纸图库的**真宿主**（壳里 `b.bingGallery` 的那条分支）。
 *
 * ## 为什么需要它
 *
 * 这一页的模型层（[SettingsBingWallpaperGalleryPage]）与接口解析（[BingGalleryDataSource]）
 * 都在，唯独壳里一直是 `SettingsScreen(SettingsBingWallpaperGalleryPage.spec(BingGalleryState()), onBack)`
 * ——传的是**默认构造**，所以屏幕上永远是「加载中」，点哪都没有下文。
 * 这个宿主把回路接起来：拉清单 → 缩略图 → 点一张 → 下载落盘 → 写设置 → 返回。
 *
 * ## 一页要做完的四件事
 *
 * 1. **进页就拉清单**（`LaunchedEffect`），失败给失败页 + 重试；上次成功过、这次没拿到
 *    则照常显示旧的并说明来路（判据在 [BingGalleryApplyPlanner.stateAfterFetch]）；
 * 2. **缩略图不下载原图**：480×854 的小图走 [AndroidImageLoader]（内存缓存 + 在途去重），
 *    加载失败的那张打上标记、文案变「轻点重试」，点它**只重试缩略图**；
 * 3. **点一张才下原图**：档位阶梯 / 同名文件复用 / 只认真图片 全在
 *    [BingGalleryDownloader]（纯 JVM，已单测）；
 * 4. **落盘成功后写设置**：壁纸路径 + 取景归位 + 「最近使用」历史（
 *    [BingGalleryApplyPlanner.settingsAfterApply]），写成功才返回上一页。
 *
 * ## 已知差异（照实写，不糊）
 *
 * 1. **没有「调整位置」页**：Dart 在落盘后压在栈上让用户拖动取景（`settings_home_backdrop_flow.dart`），
 *    本仓那一页还没有（F05 认领文件「仍缺」第 3 条）。所以取景一律归位到
 *    居中 / 刚好铺满（`0 / 0 / 1`），不是「取景已经做完」；
 * 2. **没有「下载台账」prefs**：Dart 的 `BingWallpaperStore` 把「哪天哪档下过」记在盘上。
 *    这里用**文件名**当台账（同一天同一档位天然同名，见模型层 `fileName()`），
 *    因此「已下过」判据在换设备/换像素后失效，会重下一次（不会错用糊图）；
 * 3. **多课表保护**：溢出回收的白名单由 [BingGalleryApplyPlanner.settingsAfterApply] 统一组装
 *    ——本份设置（当前壁纸 + 历史）加**盘上所有档案**内嵌的壁纸路径
 *    （[WallpaperEvictionSources] 从 `timetable_profiles` 原始 JSON 读）。档案读不懂时
 *    一张都不删，只记日志；
 * 4. **落盘失败只记日志 + 一句「保存失败」**：与外观编辑页同一处理（那里也是 `Log.e`），
 *    不静默回滚。
 */
private const val LOG_TAG = "BingGalleryHost"

/** 受管壁纸目录（App 私有，卸载即清；不进相册）。 */
private const val WALLPAPER_DIR_NAME = "wallpapers"

@Composable
fun BingGalleryHost(
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
    /** 清单数据源（测试/预览可注入假件；默认真网络）。 */
    dataSource: BingGalleryDataSource? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // 只读：溢出回收前拿盘上所有档案的壁纸路径（与外观编辑页同一份 prefs 口径）。
    val profilesPrefs = remember(context) { PrefsKeyValueStore(context) }
    val source = dataSource ?: remember { BingGalleryDataSource() }
    val today = remember { LocalDate.now() }

    var state by remember { mutableStateOf(BingGalleryState(today = today)) }
    /** 原始清单：下载要用它的 `urlBase`，状态里只有渲染用的缩略图地址。 */
    var items by remember { mutableStateOf<List<BingWallpaperItem>>(emptyList()) }
    /** 一次只下一张；下载中再点别的 → 排队。 */
    var busy by remember { mutableStateOf(false) }
    var queued by remember { mutableStateOf<BingWallpaperItem?>(null) }

    val downloader = remember {
        BingGalleryDownloader(File(context.filesDir, WALLPAPER_DIR_NAME))
    }
    // 屏幕像素：档位是下限，屏幕更大时抬到屏幕（模型层口径，宿主只负责把数给它）。
    val screen = remember {
        val metrics = context.resources.displayMetrics
        WallpaperTargetSize(metrics.widthPixels, metrics.heightPixels)
    }

    fun toast(text: String) {
        Toast.makeText(context, text, Toast.LENGTH_SHORT).show()
    }

    fun load() {
        state = BingGalleryApplyPlanner.stateLoading(state, today)
        scope.launch {
            val fetched = withContext(Dispatchers.IO) {
                runCatching { source.fetch() }.getOrDefault(emptyList())
            }
            items = fetched
            state = BingGalleryApplyPlanner.stateAfterFetch(state, fetched, today)
        }
    }

    /**
     * 落盘并写设置。
     *
     * 顺序有讲究：**先确认文件真的在盘上**（[BingGalleryDownloadResult.Success]），
     * 再写设置，最后才返回 —— 反过来会出现「设置指向一个不存在的文件」，首页裂图。
     */
    fun applyOne(item: BingWallpaperItem) {
        if (busy) {
            if (queued?.dateKey != item.dateKey) {
                queued = item
                state = BingGalleryApplyPlanner.stateQueued(state, item.dateKey)
                toast(SettingsStringsExt1.bingWallpaperDownloadQueued.zh)
            }
            return
        }
        busy = true
        state = BingGalleryApplyPlanner.stateDownloading(state, item.dateKey)
        scope.launch {
            // 下载跑在 IO 线程、Compose 状态只能主线程写：进度经一个 conflated Channel 过桥
            // （下载器每收一块就回调一次，直接跨线程改状态属于危险写法）。
            val progress = Channel<Int>(Channel.CONFLATED)
            val progressJob = launch {
                for (percent in progress) {
                    state = BingGalleryApplyPlanner.stateProgress(state, percent)
                }
            }
            val result = withContext(Dispatchers.IO) {
                downloader.download(item, screen) { received, total ->
                    progress.trySend(
                        SettingsBingWallpaperGalleryPage.downloadPercent(
                            received.toInt(),
                            total.toInt(),
                        ),
                    )
                }
            }
            progress.close()
            progressJob.join()
            state = BingGalleryApplyPlanner.stateDownloadDone(state)
            busy = false
            when (result) {
                is BingGalleryDownloadResult.Failure -> {
                    toast(
                        if (result.statusCode < 0) {
                            SettingsStringsExt1.bingWallpaperDownloadFailed.zh
                        } else {
                            SettingsStringsExt1.bingWallpaperDownloadStatus
                                .filled("status", result.statusCode.toString())
                        },
                    )
                    // 下载失败才替用户把排队那张补上（Dart 同口径：位置页退出不自动接着下，
                    // 因为那次交互已经结束；失败是用户没拿到图，理应先补）。
                    queued?.let { pending ->
                        queued = null
                        applyOne(pending)
                    }
                }

                is BingGalleryDownloadResult.Success -> {
                    val path = result.file.absolutePath
                    // 其它档案在用图的唯一完整来源：盘上 `timetable_profiles` 原始 JSON。
                    // 读 prefs 本身失败时不会删任何文件（下面直接跳过回收）。
                    val profilesRead = runCatching {
                        profilesPrefs.getString(WallpaperEvictionSources.PROFILES_KEY)
                    }
                    val outcome = BingGalleryApplyPlanner.settingsAfterApply(
                        current = store.load(),
                        path = path,
                        profilesJson = profilesRead.getOrNull(),
                    )
                    val saved = runCatching { store.save(outcome.settings) }
                    if (saved.isFailure) {
                        Log.e(LOG_TAG, "保存壁纸设置失败，文件已在 $path", saved.exceptionOrNull())
                        toast(SettingsStringsExt2.saveFailed.zh)
                        return@launch
                    }
                    // 溢出回收：删文件不阻塞交互，删不掉只记日志（不静默失败，但不至于弹错）。
                    // 档案读不到 / 读不懂时**一张都不删**：无法确认别的课表没在用，
                    // 只记日志说明跳过原因（宁可留一张垃圾图，也不能删掉别人正在用的壁纸）。
                    when {
                        profilesRead.isFailure -> Log.w(LOG_TAG, "读不到档案设置，跳过溢出回收（宁可留图，不误删）", profilesRead.exceptionOrNull())

                        outcome.profilesUnreadable -> Log.w(LOG_TAG, "档案设置读不懂，跳过溢出回收（宁可留图，不误删）")

                        else -> withContext(Dispatchers.IO) {
                            outcome.filesToDelete.forEach { evicted ->
                                runCatching { File(evicted).delete() }
                                    .onFailure { Log.w(LOG_TAG, "删不掉被淘汰的壁纸：$evicted") }
                            }
                        }
                    }
                    queued = null
                    // 落盘 + 写设置都成功才退出图库（Dart：只有真落盘才 pop）
                    onBack()
                }
            }
        }
    }

    LaunchedEffect(Unit) { load() }

    QingyuPageScaffold(
        title = SettingsBingWallpaperGalleryPage.TITLE.zh,
        onBack = onBack,
        actions = {
            IconButton(onClick = { if (!state.loading) load() }) {
                Icon(
                    imageVector = MiuixIcons.Refresh,
                    contentDescription = SettingsStringsExt1.bingWallpaperGalleryRetry.zh,
                    modifier = Modifier.size(24.dp),
                )
            }
        },
    ) {
        QingyuPageList(
            innerPadding = PaddingValues(top = innerPadding.calculateTopPadding()),
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(bottom = innerPadding.calculateBottomPadding() + 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            when {
                // 加载中且一条都没有：只给一句「加载中」，不留空白页。
                state.loading && state.items.isEmpty() -> item(key = "loading") {
                    GalleryHint(SettingsStringsExt1.commonLoadingLabel.zh)
                }

                // 一次都没成功过：失败说明 + 重试入口（断网时的空白页最像「功能坏了」）。
                state.failed -> {
                    item(key = "failed") {
                        GalleryHint(SettingsStringsExt1.bingWallpaperGalleryFailed.zh)
                    }
                    item(key = "retry") {
                        QingyuCard(onClick = { load() }) {
                            Text(
                                text = SettingsStringsExt1.bingWallpaperGalleryRetry.zh,
                                style = MiuixTheme.textStyles.body1,
                                modifier = Modifier.padding(16.dp),
                            )
                        }
                    }
                }

                else -> {
                    // 显示的是上次那份：网格照常，顶部一条来路说明。
                    if (state.showingCached) {
                        item(key = "cached") {
                            GalleryHint(SettingsStringsExt1.wallpaperGalleryShowingCached.zh)
                        }
                    }
                    // 两列网格：一行两个卡片（官方列表承载滚动，滚动手感与别的设置页一致）。
                    state.items
                        .chunked(SettingsBingWallpaperGalleryPage.GRID_CROSS_AXIS_COUNT)
                        .forEachIndexed { rowIndex, rowItems ->
                            item(key = "row-$rowIndex") {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(
                                        SettingsBingWallpaperGalleryPage.GRID_CROSS_AXIS_SPACING.dp,
                                    ),
                                ) {
                                    for (galleryItem in rowItems) {
                                        val card = SettingsBingWallpaperGalleryPage.card(galleryItem, state)
                                        BingWallpaperCard(
                                            card = card,
                                            modifier = Modifier.weight(1f),
                                            onClick = {
                                                val raw = items.firstOrNull { it.dateKey == galleryItem.dateKey }
                                                if (raw != null) {
                                                    applyOne(raw)
                                                }
                                            },
                                            onThumbFailed = {
                                                state = BingGalleryApplyPlanner.stateThumbFailed(
                                                    state,
                                                    galleryItem.dateKey,
                                                )
                                            },
                                        )
                                    }
                                    // 奇数张时补一个空位，别让最后一张拉满整行
                                    if (rowItems.size < SettingsBingWallpaperGalleryPage.GRID_CROSS_AXIS_COUNT) {
                                        Spacer(modifier = Modifier.weight(1f))
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
}

/** 一条整宽说明（加载中 / 失败 / 来路提示），与设置族其它页的灰字同口径。 */
@Composable
private fun GalleryHint(text: String) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 8.dp),
    )
}

/**
 * 一张壁纸卡：缩略图 + 日期 + 版权说明。
 *
 * 状态叠加按模型层给的 [BingGalleryWallpaperCard.state] 走，本函数**不自己判断**
 * 「是不是在下载」，否则模型层那套状态机就白写了。
 */
@Composable
private fun BingWallpaperCard(
    card: BingGalleryWallpaperCard,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    onThumbFailed: () -> Unit,
) {
    QingyuCard(modifier = modifier, onClick = onClick) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                // 与 480×854 的缩略图同朝向（模型层 GRID_CHILD_ASPECT_RATIO）
                .aspectRatio(SettingsBingWallpaperGalleryPage.GRID_CHILD_ASPECT_RATIO.toFloat())
                .background(MiuixTheme.colorScheme.surfaceVariant),
        ) {
            val bitmap = rememberThumbnail(card.thumbnailUrl, onThumbFailed)
            if (bitmap != null) {
                Image(
                    bitmap = bitmap,
                    contentDescription = card.dateLabel,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Text(
                    text = if (card.state == BingWallpaperCardState.THUMB_FAILED) {
                        SettingsStringsExt1.wallpaperThumbRetryHint.zh
                    } else {
                        SettingsStringsExt1.commonLoadingLabel.zh
                    },
                    style = MiuixTheme.textStyles.footnote2,
                    color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    modifier = Modifier.align(Alignment.Center),
                )
            }
            // 下载中 / 排队中的角标
            val overlay = when (card.state) {
                BingWallpaperCardState.DOWNLOADING -> card.progressLabel
                BingWallpaperCardState.QUEUED -> SettingsStringsExt1.bingWallpaperDownloadQueued.zh
                else -> null
            }
            if (!overlay.isNullOrEmpty()) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .background(MiuixTheme.colorScheme.surface.copy(alpha = 0.86f))
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = overlay,
                        style = MiuixTheme.textStyles.footnote2,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp)) {
            Text(
                text = card.dateLabel,
                style = MiuixTheme.textStyles.footnote1,
                maxLines = card.dateMaxLines,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = card.copyright,
                style = MiuixTheme.textStyles.footnote2,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                maxLines = card.copyrightMaxLines,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 缩略图：走共享的 [AndroidImageLoader.shutdown] 之外那套内存缓存加载器。
 *
 * 失败时回调一次（打标记 → 文案变「轻点重试」）；点击重试由调用方先清标记，
 * `remember(url)` 的 key 变化才会真的重新发请求。
 */
@Composable
private fun rememberThumbnail(url: String, onFailed: () -> Unit): ImageBitmap? {
    var bitmap by remember(url) { mutableStateOf<ImageBitmap?>(null) }
    val failedCallback = rememberUpdatedState(onFailed)
    LaunchedEffect(url) {
        AndroidImageLoader.shared.load(
            url = url,
            targetWidthPx = BingGalleryApplyPlanner.THUMB_WIDTH,
            targetHeightPx = BingGalleryApplyPlanner.THUMB_HEIGHT,
        ) { loaded ->
            if (loaded == null) {
                failedCallback.value()
            } else {
                bitmap = loaded.asImageBitmap()
            }
        }
    }
    return bitmap
}
