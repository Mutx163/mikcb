package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import com.mutx163.qingyu.weather.BingWallpaperItem
import com.mutx163.qingyu.weather.BingWallpaperResolution
import com.mutx163.qingyu.weather.DownloadFailure
import com.mutx163.qingyu.weather.WallpaperHistoryEntry
import com.mutx163.qingyu.weather.WallpaperTargetSize
import com.mutx163.qingyu.weather.isMissingTierFailure
import com.mutx163.qingyu.weather.pushWallpaperHistory
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate

/**
 * Bing 每日壁纸图库的**下载与落盘**链路（纯 JVM 部分）。
 *
 * Dart 侧这段在 `BingWallpaperService.download` + `BingWallpaperStore`（HTTP/流式进度/
 * 落盘/验尺寸/台账）里，约 400 行且全是 IO。这里把它切成两块：
 *
 * - **可 JVM 直测的**：档位阶梯（缺档退一档）、文件名/目标尺寸、落盘文件复用判据、
 *   下载字节是不是真图片、写完设置后的历史与要删的文件（本文件）；
 * - **留在宿主的**：真 HTTP、真写盘、`Context.filesDir`、界面状态（`BingGalleryHost`）。
 *
 * ## 三个口径（都对 Dart 负责，写在单测里钉住）
 *
 * 1. **缺档才退档**：只有 `Status`（多为 404）与 `NotImage`（Bing 回 HTML 错误页）值得
 *    换一档重下；断网/空 body/写盘失败换档也必然失败，直接把失败交回用户
 *    （[isMissingTierFailure]，`weather/BingDownloadMode.kt` 已单测过判据，这里只消费）；
 * 2. **同名文件即缓存**：文件名由 `dateKey + 档位 + 实际像素` 拼（[BingWallpaperItem.fileName]），
 *    所以「同名且非空」就等于「这张这个尺寸已经下过了」，重复点不重复下；
 * 3. **落盘先写 `.part` 再改名**：中途失败/被杀不会留一个「大小非 0 但内容半截」的文件，
 *    否则下次进来会把它当成已下过的整图用（首页裂图，且用户无从修复）。
 */

/** 下载结果。`statusCode < 0` = 拿不到响应（断网/超时），不是 HTTP 状态码。 */
sealed interface BingGalleryDownloadResult {
    data class Success(
        val file: File,
        val resolution: BingWallpaperResolution,
        /** true = 命中同名旧文件，本次没发请求。 */
        val reused: Boolean,
    ) : BingGalleryDownloadResult

    data class Failure(val statusCode: Int) : BingGalleryDownloadResult
}

/** 下载时收到的字节进度（[total] <= 0 = 服务端没给 Content-Length）。 */
fun interface BingGalleryProgress {
    fun onProgress(received: Long, total: Long)
}

/** 一次 HTTP 取字节的结果：状态码 + body。 */
data class BingGalleryBytes(val statusCode: Int, val body: ByteArray)

/** 「GET 一个 URL，拿字节」的接缝（清单走 [BingGalleryHttp]，图片走这个，两者共用一个真实实现）。 */
interface BingGalleryBinaryHttp {
    fun get(url: String, progress: BingGalleryProgress): BingGalleryBytes
}

/**
 * 真实实现：JDK [HttpURLConnection] + 流式读，边读边回调进度（Dart 的 `onProgress` 同口径）。
 *
 * 断网/超时统一返回 `statusCode = -1` 的空 body —— 与 Dart 用 `-1` 表示「拿不到响应」一致。
 */
class JdkBingGalleryBinaryHttp(
    private val connectTimeoutMs: Int = 10_000,
    private val readTimeoutMs: Int = 30_000,
) : BingGalleryBinaryHttp {

    override fun get(url: String, progress: BingGalleryProgress): BingGalleryBytes = try {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = connectTimeoutMs
            readTimeout = readTimeoutMs
            setRequestProperty("User-Agent", "qingyu-kb-compose/1.0")
        }
        try {
            val code = connection.responseCode
            if (code !in 200..299) {
                BingGalleryBytes(code, ByteArray(0))
            } else {
                val total = connection.contentLengthLong
                val out = java.io.ByteArrayOutputStream(if (total > 0) total.toInt() else 64 * 1024)
                connection.inputStream.use { input ->
                    val buffer = ByteArray(16 * 1024)
                    var received = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        out.write(buffer, 0, read)
                        received += read
                        progress.onProgress(received, total)
                    }
                }
                BingGalleryBytes(code, out.toByteArray())
            }
        } finally {
            connection.disconnect()
        }
    } catch (e: IOException) {
        BingGalleryBytes(-1, ByteArray(0))
    } catch (e: RuntimeException) {
        BingGalleryBytes(-1, ByteArray(0))
    }
}

/**
 * 下载并落盘。**不碰界面、不碰设置**：只回答「文件在哪」或「失败码是多少」。
 *
 * @param dir 受管目录（宿主传 `context.filesDir/wallpapers`）。
 */
class BingGalleryDownloader(
    private val dir: File,
    private val http: BingGalleryBinaryHttp = JdkBingGalleryBinaryHttp(),
) {

    /**
     * 按档位阶梯 [BingGalleryApplyPlanner.DOWNLOAD_TIERS] 依次尝试。
     *
     * 命中同名旧文件直接返回（不下载）；缺档就换下一档；其余失败立刻返回。
     */
    fun download(
        item: BingWallpaperItem,
        screen: WallpaperTargetSize,
        onProgress: BingGalleryProgress = BingGalleryProgress { _, _ -> },
    ): BingGalleryDownloadResult {
        var lastFailure = BingGalleryDownloadResult.Failure(-1)
        for (tier in BingGalleryApplyPlanner.DOWNLOAD_TIERS) {
            val plan = BingGalleryApplyPlanner.plan(item, screen, tier)
            val dest = File(dir, plan.fileName)
            if (BingGalleryApplyPlanner.isReusable(dest)) {
                return BingGalleryDownloadResult.Success(dest, tier, reused = true)
            }
            val response = http.get(plan.url, onProgress)
            if (response.statusCode !in 200..299) {
                lastFailure = BingGalleryDownloadResult.Failure(response.statusCode)
                val synthetic = if (response.statusCode < 0) {
                    DownloadFailure.Network
                } else {
                    DownloadFailure.Status
                }
                if (!isMissingTierFailure(synthetic)) return lastFailure
                continue
            }
            if (response.body.isEmpty()) {
                return BingGalleryDownloadResult.Failure(response.statusCode)
            }
            if (!BingGalleryApplyPlanner.looksLikeImage(response.body)) {
                // 状态码 200 但给的是 HTML 错误页：缺档那一类，换下一档再试。
                lastFailure = BingGalleryDownloadResult.Failure(response.statusCode)
                continue
            }
            return if (BingGalleryApplyPlanner.writeAtomically(File(dir, plan.fileName), response.body)) {
                BingGalleryDownloadResult.Success(dest, tier, reused = false)
            } else {
                BingGalleryDownloadResult.Failure(-1)
            }
        }
        return lastFailure
    }
}

/** 一次「点某张 → 该下什么」的完整描述（单测只钉这一层，不摸网也不摸盘）。 */
data class BingGalleryApplyPlan(
    val item: BingWallpaperItem,
    val resolution: BingWallpaperResolution,
    /** 实际请求的像素（档位是下限，屏幕更大时抬到屏幕）。 */
    val targetSize: WallpaperTargetSize,
    val url: String,
    val fileName: String,
)

/**
 * 图库的纯判据集合：清单→状态、点图→下载计划、下载完成→设置怎么写。
 *
 * 全部无副作用，`pages/settings` 的 L0 单测直测（同目录 [SettingsBingWallpaperGalleryPage] 的分工）。
 */
object BingGalleryApplyPlanner {

    /** 缩略图尺寸（Dart `:56-59`：480×854，约 105 KB/张，8 张 ≈ 840 KB）。 */
    const val THUMB_WIDTH = 480
    const val THUMB_HEIGHT = 854

    /** 默认档位：Dart `BingWallpaperStore.resolution` 恒返回 `high`（`bing_wallpaper_store.dart:103`）。 */
    val DEFAULT_RESOLUTION: BingWallpaperResolution = BingWallpaperResolution.HIGH

    /** 缺档时的退档阶梯（从大到小，最后一档是 Bing 的预生成尺寸）。 */
    val DOWNLOAD_TIERS: List<BingWallpaperResolution> = listOf(
        BingWallpaperResolution.HIGH,
        BingWallpaperResolution.TALL,
        BingWallpaperResolution.STANDARD,
    )

    /** 点某张时该下什么：URL、文件名、实际像素全部由模型层算（宿主不自己拼串）。 */
    fun plan(
        item: BingWallpaperItem,
        screen: WallpaperTargetSize,
        resolution: BingWallpaperResolution = DEFAULT_RESOLUTION,
    ): BingGalleryApplyPlan {
        val target = resolution.downloadTargetSize(screen)
        return BingGalleryApplyPlan(
            item = item,
            resolution = resolution,
            targetSize = target,
            url = item.downloadUrl(resolution, target),
            fileName = item.fileName(resolution, target),
        )
    }

    /** 同名文件非空即算「已下过」（见类注释口径 2）。 */
    fun isReusable(file: File): Boolean = file.isFile && file.length() > 0L

    /**
     * 字节是不是真图片：JPEG（`FF D8 FF`）或 PNG（`89 50 4E 47`）。
     *
     * Bing 的 resize 接口对不认识的参数会**回一张 HTML 错误页且状态码仍是 200**
     * （Dart `ManagedImageDownloadFailure.notImage`），不验文件头就会把 HTML 写进
     * `.jpg` 里，首页当场裂图。
     */
    fun looksLikeImage(bytes: ByteArray): Boolean {
        if (bytes.size < 4) return false
        val jpeg = bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte() && bytes[2] == 0xFF.toByte()
        val png = bytes[0] == 0x89.toByte() && bytes[1] == 0x50.toByte() &&
            bytes[2] == 0x4E.toByte() && bytes[3] == 0x47.toByte()
        return jpeg || png
    }

    /** 先写 `.part` 再改名（口径 3）。目录不存在时顺手建。 */
    fun writeAtomically(dest: File, bytes: ByteArray): Boolean = try {
        dest.parentFile?.mkdirs()
        val part = File(dest.parentFile, dest.name + ".part")
        part.writeBytes(bytes)
        if (dest.exists()) dest.delete()
        // ⚠️ renameTo 返回 false 是「改名失败」而不是异常（目标被目录占住、跨卷等）：
        // 不看返回值就会把「其实没落盘」当成成功，接着去写设置指向一个不存在的文件。
        val renamed = part.renameTo(dest)
        if (!renamed) part.delete()
        renamed
    } catch (e: IOException) {
        false
    }

    /** 清单条目 → 网格卡需要的形状（缩略图 URL 在这里拼，渲染层不碰模型细节）。 */
    fun galleryItems(items: List<BingWallpaperItem>): List<BingGalleryItem> = items.map { item ->
        BingGalleryItem(
            dateKey = item.dateKey,
            title = item.title,
            copyright = item.copyright,
            thumbnailUrl = item.thumbnailUrl(THUMB_WIDTH, THUMB_HEIGHT),
        )
    }

    /**
     * 拉取成功后的状态（Dart `_load` 的 `setState` 段）。
     *
     * * 拿到非空清单 → 正常网格，`failed = false`、`showingCached = false`；
     * * 回报空清单但**手上还有上次那份** → 照常显示旧的 + `showingCached = true`
     *   （网络抖一下不该逼用户重新挑）；
     * * 空清单且手上也是空的 → `failed = true`（失败页 + 重试）。
     */
    fun stateAfterFetch(
        current: BingGalleryState,
        items: List<BingWallpaperItem>,
        today: LocalDate,
    ): BingGalleryState {
        val gallery = galleryItems(items)
        if (gallery.isNotEmpty()) {
            return current.copy(
                loading = false,
                items = gallery,
                failed = false,
                showingCached = false,
                today = today,
            )
        }
        return if (current.items.isEmpty()) {
            current.copy(loading = false, failed = true, showingCached = false, today = today)
        } else {
            current.copy(loading = false, failed = false, showingCached = true, today = today)
        }
    }

    /** 网络层直接失败（抛了/超时）：与「空清单」同一条判据。 */
    fun stateAfterFailure(current: BingGalleryState, today: LocalDate): BingGalleryState =
        stateAfterFetch(current, emptyList(), today)

    /** 开拉：清掉上次的失败标记，正文回到「加载中」（Dart `_load` 开头那三行）。 */
    fun stateLoading(current: BingGalleryState, today: LocalDate): BingGalleryState =
        current.copy(loading = true, failed = false, today = today)

    /** 某张缩略图加载失败（Dart `setState(() => _failedThumbs.add(...))`）。 */
    fun stateThumbFailed(current: BingGalleryState, dateKey: String): BingGalleryState =
        current.copy(failedThumbs = current.failedThumbs + dateKey)

    /** 「点失败的那张只重试缩略图」：先把标记去掉，渲染层才会重新发请求（Dart 还带 epoch）。 */
    fun stateThumbRetried(current: BingGalleryState, dateKey: String): BingGalleryState =
        current.copy(failedThumbs = current.failedThumbs - dateKey)

    /** 开始下载某张（同 Dart：清进度、清排队标记）。 */
    fun stateDownloading(current: BingGalleryState, dateKey: String): BingGalleryState =
        current.copy(downloadingDateKey = dateKey, downloadingPercent = -1, queuedDateKey = null)

    /** 下载进度（整数百分比；`-1` = 服务端没给总长，渲染层只显示省略号）。 */
    fun stateProgress(current: BingGalleryState, percent: Int): BingGalleryState =
        current.copy(downloadingPercent = percent)

    /** 下载结束（成功或失败都一样：把「正在下」清掉，排队标记由调用方决定）。 */
    fun stateDownloadDone(current: BingGalleryState): BingGalleryState =
        current.copy(downloadingDateKey = null, downloadingPercent = -1)

    /** 排队（下载中点了另一张）：记下它，当前这张结束后接着下。 */
    fun stateQueued(current: BingGalleryState, dateKey: String): BingGalleryState =
        current.copy(queuedDateKey = dateKey)

    /**
     * 下载成功后要把设置写成什么样（Dart 由 `_HomeBackdropFlow` 做，本仓缺那一层，
     * 所以在纯层把「改成什么」算出来、宿主只负责落盘）。
     *
     * 写三样：壁纸路径 + 取景（新图 → 归位居中、不缩放）+ 「最近使用」历史。
     *
     * ⚠️ **已知差异**：Dart 在这里会先推「调整位置」页让用户取景，本仓那一页还没有
     * （F05 认领文件的「仍缺」第 3 条），所以取景一律归位到 `0 / 0 / 1`（居中、刚好铺满）。
     * 这不是「假装做了取景」，是「还没做取景时的确定行为」。
     */
    fun settingsAfterApply(
        current: TimetableSettingsModel,
        path: String,
        nowMs: Long = System.currentTimeMillis(),
        /**
         * 盘上 `timetable_profiles` 的原始 JSON（其它档案在用图的唯一完整来源）。
         *
         * 缺省 `null` = 盘上没有这份 key（还没有多档案），按「没有别的课表」处理；
         * **读不懂**（不是数组 / 档案 settings 不是对象）时一张都不删，
         * 见 [WallpaperEvictionSources.planEviction]。
         */
        profilesJson: String? = null,
    ): BingGalleryApplyOutcome {
        // 去重置顶 + 封顶在 pushWallpaperHistory 里做，这里只负责写回设置模型
        val pushed = pushWallpaperHistory(
            history = current.wallpaperHistory.map { it.toHistoryEntry() },
            key = path,
            alignX = 0.0,
            alignY = 0.0,
            scale = 1.0,
            usedAt = nowMs,
        )
        val next = current.copy(
            homePageWallpaperPath = path,
            homePageWallpaperAlignX = 0.0,
            homePageWallpaperAlignY = 0.0,
            homePageWallpaperScale = 1.0,
            wallpaperHistory = pushed.history.map { it.toRowModel() },
        )
        // 溢出回收分两层：本份设置（本页已知）+ **盘上所有档案**内嵌的壁纸路径。
        // 别的课表正在用的图只存在于 `timetable_profiles` 原始 JSON
        // （仓储快照的 `TimetableProfile.settings` 只有 core 4 键），少这一层就会把
        // 别的课表正在用的图删掉、切过去时首页裂图。
        val localWhitelist = deletionWhitelist(next, keep = path)
        val plan = WallpaperEvictionSources.planEviction(
            evictedPaths = pushed.evictedPaths.filterNot { it in localWhitelist },
            profilesJson = profilesJson,
            currentPath = next.homePageWallpaperPath,
            draftPath = path,
        )
        return BingGalleryApplyOutcome(
            settings = next,
            filesToDelete = plan.deletable,
            profilesUnreadable = plan.profilesUnreadable,
        )
    }

    /**
     * **本份设置**的溢出回收白名单（Dart `_deleteEvicted` 里属于本页的那几路）：
     * 刚落盘的这张、当前壁纸、以及历史里还留着的每一条。
     *
     * 少写任何一路都会删掉正在用的图：自动换写下的那张**不在历史里**，只按历史当白名单
     * 会把当前壁纸删掉、首页当场裂图。
     *
     * ⚠️ 这只是两层的**第一层**。别的课表正在用的壁纸不在本份设置里，必须由
     * [WallpaperEvictionSources.planEviction] 从盘上档案 JSON 补（[settingsAfterApply]
     * 就是这么接的）。单独拿本函数的结果去删文件 = 只护当前课表。
     */
    fun deletionWhitelist(settings: TimetableSettingsModel, keep: String?): Set<String> = buildSet {
        if (!keep.isNullOrBlank()) add(keep)
        settings.homePageWallpaperPath?.takeIf { it.isNotBlank() }?.let { add(it) }
        settings.wallpaperHistory.forEach { if (it.key.isNotBlank()) add(it.key) }
    }

    /** 清单里有没有「今天」那张（图库顶部提示用）。 */
    fun hasToday(items: List<BingWallpaperItem>, dateKey: String): Boolean =
        items.any { it.dateKey == dateKey }
}

/** 落盘设置的结果：新模型 + 需要删的文件（不删也不崩，只是占盘）。 */
data class BingGalleryApplyOutcome(
    val settings: TimetableSettingsModel,
    val filesToDelete: List<String>,
    /**
     * 档案 JSON 读不懂 ⇒ [filesToDelete] 必为空（宁可留图，不误删）。
     * 给宿主一个显式信号去记日志，而不是静默跳过。
     */
    val profilesUnreadable: Boolean = false,
)

private fun WallpaperHistoryRowModel.toHistoryEntry(): WallpaperHistoryEntry = WallpaperHistoryEntry(
    key = key,
    alignX = alignX,
    alignY = alignY,
    scale = scale,
    usedAt = usedAt,
)

private fun WallpaperHistoryEntry.toRowModel(): WallpaperHistoryRowModel = WallpaperHistoryRowModel(
    key = key,
    alignX = alignX,
    alignY = alignY,
    scale = scale,
    usedAt = usedAt,
)
