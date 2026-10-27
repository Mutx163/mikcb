package com.mutx163.qingyu.pages.settings

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Bing 每日壁纸图库（`lib/screens/settings/bing_wallpaper_gallery_page.dart:45-628`）
 * 的结构模型。
 *
 * ## 这一页的复杂度不在 UI，在状态
 *
 * 六种互斥/可叠加的状态：加载中、一次都没成功过（失败页）、**显示的是上次结果**、
 * 某张正在下载（带百分比）、某张排队中、某张缩略图加载失败。它们的分支判断散在
 * `build` 与 `_pick` / `_downloadAndApply` 里，所以模型层把**状态推导**搬出来，
 * UI 只消费结果。
 *
 * ## 三个「容易想当然」的口径（都已在测试里钉住）
 *
 * 1. **失败只认「一次都没成功过」**（:123-130 / :176-179）：空清单才是失败；
 *    上次成功过、这次没拿到 → 照常显示旧的 + 一条来路提示，否则网络一抖用户就得
 *    重新挑一遍；
 * 2. **浏览不下载**（:55-59）：缩略图走 480×854 的小图（约 105 KB/张），只有点某一张
 *    才按当前档位下原图；
 * 3. **点缩略图失败的那张只重试缩略图**（:190-199）：用户点的是「这块怎么空了」，
 *    不是「我要这张当壁纸」。
 *
 * ## 不写进模型的行为（接线层照做）
 *
 * 1. 位置编辑页压在**图库之上**（图库留在栈里），位置页「退出」回图库接着挑、
 *    「完成」才让图库自己退出（:24-32，2026-10-06 用户口径）；
 * 2. 台账溢出删文件的白名单是**三路并集**（[evictionWhitelist]）；
 * 3. `Image.network` 失败后不会自己重试，重试必须换 `KeyedSubtree` 的 key
 *    才真的重新发请求（:112-121）。
 */
object SettingsBingWallpaperGalleryPage {

    const val ID = "settings-bing-wallpaper-gallery"

    /** 两列竖卡网格（:427-436）。 */
    const val GRID_CROSS_AXIS_COUNT = 2
    const val GRID_MAIN_AXIS_SPACING = 14.0
    const val GRID_CROSS_AXIS_SPACING = 12.0
    const val GRID_CHILD_ASPECT_RATIO = 0.56

    /** 版权说明最多两行、日期一行（:581-597）。 */
    const val COPYRIGHT_MAX_LINES = 2
    const val DATE_MAX_LINES = 1

    val TITLE = SettingsStringsExt1.bingWallpaperGalleryTitle

    /**
     * 正文的三态（:397-443）：加载中 / 失败页 / 网格。
     *
     * 第四种「显示的是上次结果」不是独立的三态之一 —— 它是网格顶部的一条提示条
     * （:410-423），网格照常渲染。
     */
    fun bodyState(state: BingGalleryState): BingGalleryBody = when {
        state.loading && state.items.isEmpty() -> BingGalleryBody.LOADING
        state.failed -> BingGalleryBody.FAILURE
        else -> BingGalleryBody.GRID
    }

    fun spec(state: BingGalleryState): SettingsPageSpec {
        val nodes = mutableListOf<SettingsNode>()
        when (bodyState(state)) {
            BingGalleryBody.LOADING -> nodes += SettingsDescription(
                id = "gallery.loading",
                textKey = SettingsStringsExt1.commonLoadingLabel.key,
                text = SettingsStringsExt1.commonLoadingLabel.zh,
            )

            BingGalleryBody.FAILURE -> {
                // 给一条可重试的提示而不是空白页 —— 断网时的空白页最像「功能坏了」（:123-124）
                nodes += SettingsDescription(
                    id = "gallery.failed",
                    textKey = SettingsStringsExt1.bingWallpaperGalleryFailed.key,
                    text = SettingsStringsExt1.bingWallpaperGalleryFailed.zh,
                )
                nodes += SettingsGroup(
                    id = "gallery.failureActions",
                    children = listOf(
                        settingsRow(
                            id = "gallery.retry",
                            component = MiuixRowComponent.ARROW,
                            title = SettingsStringsExt1.bingWallpaperGalleryRetry,
                            action = SettingsAction.RUN_NOW,
                            actionTarget = "gallery.retry",
                        ),
                    ),
                )
            }

            BingGalleryBody.GRID -> {
                // 「显示的是上次结果」提示条（:410-423）：与失败页分开
                if (state.showingCached) {
                    nodes += settingsRow(
                        id = "gallery.showingCached",
                        component = MiuixRowComponent.ARROW,
                        title = SettingsStringsExt1.wallpaperGalleryShowingCached,
                    )
                }
                nodes += SettingsGroup(
                    id = "gallery.grid",
                    children = state.items.map { item -> cardRow(item, state) },
                )
            }
        }
        return SettingsPageSpec(
            id = ID,
            titleKey = TITLE.key,
            title = TITLE.zh,
            nodes = nodes,
        )
    }

    /** 一张卡的状态推导（:489-601）。 */
    fun card(item: BingGalleryItem, state: BingGalleryState): BingGalleryWallpaperCard {
        val thumbFailed = state.failedThumbs.contains(item.dateKey)
        val cardState = when {
            state.downloadingDateKey == item.dateKey -> BingWallpaperCardState.DOWNLOADING
            state.queuedDateKey == item.dateKey -> BingWallpaperCardState.QUEUED
            thumbFailed -> BingWallpaperCardState.THUMB_FAILED
            else -> BingWallpaperCardState.IDLE
        }
        return BingGalleryWallpaperCard(
            id = item.dateKey,
            dateLabel = dateLabel(item.dateKey, state.today),
            copyright = copyrightText(item.copyright, item.title, thumbFailed),
            thumbnailUrl = item.thumbnailUrl,
            state = cardState,
            progressLabel = if (cardState == BingWallpaperCardState.DOWNLOADING) {
                downloadProgressLabel(state.downloadingPercent)
            } else {
                null
            },
        )
    }

    private fun cardRow(item: BingGalleryItem, state: BingGalleryState) = settingsRow(
        id = "grid.${item.dateKey}",
        component = MiuixRowComponent.ARROW,
        // 卡上那两行字由渲染层用 card(...) 取；这里给行标题兜住文案约束
        title = ArbText(NON_ARB_TEXT, copyrightText(item.copyright, item.title, false)),
        // 状态由 card(...) 给出，行这一层只承载「点了要做什么」
        action = SettingsAction.RUN_NOW,
        actionTarget = item.dateKey,
    )

    /**
     * 版权说明那行（:587-597）：版权为空时退回标题；缩略图失败时再挂一句「轻点重试」。
     */
    fun copyrightText(copyright: String, title: String, thumbFailed: Boolean): String {
        val base = copyright.ifEmpty { title }
        return if (thumbFailed) {
            base + "（" + SettingsStringsExt1.wallpaperThumbRetryHint.zh + "）"
        } else {
            base
        }
    }

    /**
     * 点某一张要做什么（:190-211）。
     *
     * 优先级：缩略图失败的那张**且当前没人下载** → 只重试缩略图；有人在下载 → 排队；
     * 否则直接下。
     */
    fun pickIntent(item: BingGalleryItem, state: BingGalleryState): BingPickIntent = when {
        state.failedThumbs.contains(item.dateKey) && state.downloadingDateKey == null ->
            BingPickIntent.RETRY_THUMB
        state.downloadingDateKey != null -> BingPickIntent.QUEUE
        else -> BingPickIntent.DOWNLOAD
    }

    /** 点一张排队中的图是否要真的改队列（:201 `if (_queuedItemId != item.dateKey)`）。 */
    fun shouldRequeue(dateKey: String, state: BingGalleryState): Boolean =
        state.queuedDateKey != dateKey

    /**
     * 下载进度百分比（:104-110）：整数粒度节流；CDN 没给总长（null / 0）返回 -1。
     *
     * 1% 粒度是为了别让 2 MB 图在好网下每收一块就重建一次、网格白抖（:243-245）。
     */
    fun downloadPercent(received: Int?, total: Int?): Int {
        if (total == null || total <= 0 || received == null) return -1
        return received * 100 / total
    }

    /** 下载中那块的中心文案（:608-612）：能算百分比就报数，否则只给省略号。 */
    fun downloadProgressLabel(percent: Int): String =
        if (percent >= 0) {
            SettingsStringsExt1.bingWallpaperDownloadProgress.filled("percent", "$percent%")
        } else {
            SettingsStringsExt1.bingWallpaperDownloadProgress.filled("percent", "…")
        }

    /** 下载失败的文案（:285-293）：拿不到状态码（断网）退回通用文案。 */
    fun downloadFailureMessage(statusCode: Int): ArbText =
        if (statusCode < 0) {
            SettingsStringsExt1.bingWallpaperDownloadFailed
        } else {
            SettingsStringsExt1.bingWallpaperDownloadStatus
        }

    /**
     * 台账溢出删文件时的白名单（:322-341）：三路并集。
     *
     * [keep]（刚挑中的那张）、[protectedPaths]（宿主传进来的「当前壁纸」——
     * 自动换写下的那张**不在历史里**，只按历史当白名单会把它删掉、首页当场裂图）、
     * 以及「最近使用」（别的课表可能正拿某张当壁纸）。
     */
    fun evictionWhitelist(
        keep: String?,
        protectedPaths: List<String>,
        history: List<String>,
    ): Set<String> = buildSet {
        if (!keep.isNullOrEmpty()) add(keep)
        addAll(protectedPaths.filter { it.isNotEmpty() })
        addAll(history.filter { it.isNotEmpty() })
    }

    // ------------------------------------------------------------ 日期标签

    /**
     * 把 Bing 的 `startdate`（形如 `20261005`）显示成用户读的日期
     * （`lib/utils/bing_wallpaper_date_label.dart:16-38`）。
     *
     * 三档说法：**今天 / 昨天** → `M 月 D 日`（不带年，列表最多 8 天不会跨年）→
     * 解析不出来就原样退回那串数字，绝不显示空白。
     *
     * [today] 由调用方注入而不是在这里取：图库页传当天，这样这段逻辑在单测里
     * 能钉住「今天」而不受测试运行时刻影响。
     */
    fun dateLabel(dateKey: String, today: LocalDate): String {
        val parsed = parseDateKey(dateKey) ?: return dateKey
        val daysAgo = ChronoUnit.DAYS.between(parsed, today)
        return when (daysAgo) {
            0L -> SettingsStringsExt1.bingWallpaperDateToday.zh
            1L -> SettingsStringsExt1.bingWallpaperDateYesterday.zh
            // 未来的日期（Bing 的 enddate 偶尔跨到明天）与更早的走同一条月日
            else -> {
                // 模板有两个占位符，`ArbText.filled` 一次只换一个：先换月、再换日
                val withMonth = SettingsStringsExt1.bingWallpaperDateMonthDay
                    .filled("month", parsed.monthValue.toString())
                withMonth.replace("{day}", parsed.dayOfMonth.toString())
            }
        }
    }

    /**
     * 解析 `YYYYMMDD`（`:47-75`）；长度不对、非数字、月日越界都算失败（返回 null）。
     *
     * ⚠️ 先卡「全是数字」再解析：`int.tryParse` 会**默默接受首尾空白**
     * （`'  26'` 解析成 26），于是 `'  261005'` 这种被补位/带空格的脏值会被当成
     * 公元 26 年并正常显示。接口字段是固定宽度的 `YYYYMMDD`，任何非数字都该直接拒。
     *
     * 月日越界那条也别省：接口若给了 `20261345` 这类脏值，日期库会**自动进位**
     * （13 月变成次年 1 月），于是用户看到「1 月 45 日」这种不存在的日期还不报错。
     */
    fun parseDateKey(raw: String): LocalDate? {
        if (raw.length != 8) return null
        if (!raw.all { it in '0'..'9' }) return null
        val year = raw.substring(0, 4).toIntOrNull() ?: return null
        val month = raw.substring(4, 6).toIntOrNull() ?: return null
        val day = raw.substring(6, 8).toIntOrNull() ?: return null
        if (month < 1 || month > 12 || day < 1 || day > 31) return null
        return runCatching { LocalDate.of(year, month, day) }.getOrNull()
    }
}

/** 正文三态（:397-443）。 */
enum class BingGalleryBody { LOADING, FAILURE, GRID }

/** 一张卡的显示状态（:491-493 / :556-575）。 */
enum class BingWallpaperCardState { IDLE, DOWNLOADING, QUEUED, THUMB_FAILED }

/** 点一张要做什么（:190-211）。 */
enum class BingPickIntent { RETRY_THUMB, QUEUE, DOWNLOAD }

/** 一张卡的渲染数据。 */
data class BingGalleryWallpaperCard(
    val id: String,
    val dateLabel: String,
    val copyright: String,
    val thumbnailUrl: String,
    val state: BingWallpaperCardState,
    /** 下载中那块的文案；非下载中为 null。 */
    val progressLabel: String?,
) {
    val copyrightMaxLines: Int get() = SettingsBingWallpaperGalleryPage.COPYRIGHT_MAX_LINES
    val dateMaxLines: Int get() = SettingsBingWallpaperGalleryPage.DATE_MAX_LINES
}

/** 图库条目（`lib/models/bing_wallpaper.dart` 的 `BingWallpaperItem` 子集）。 */
data class BingGalleryItem(
    /** `startdate`，形如 `20261005`。 */
    val dateKey: String,
    val title: String,
    val copyright: String,
    /** 480×854 的缩略图（:56-59）。 */
    val thumbnailUrl: String,
)

/** 图库页的状态（宿主传入）。 */
data class BingGalleryState(
    /** 首次加载 / 下拉刷新进行中（:88-89）。 */
    val loading: Boolean = true,
    val items: List<BingGalleryItem> = emptyList(),
    /** 拉取失败：**只有一次都没成功过**才为 true（:123-130）。 */
    val failed: Boolean = false,
    /** 当前显示的是上次拉到的清单（:126-130）。 */
    val showingCached: Boolean = false,
    /** 正在下载的那张（用条目而不是下标：清单可能被刷新重排，:91-94）。 */
    val downloadingDateKey: String? = null,
    /** 下载中点击的那张（排队）。 */
    val queuedDateKey: String? = null,
    /** 下载进度整数百分比；-1 = CDN 没给总长（:99-110）。 */
    val downloadingPercent: Int = -1,
    /** 缩略图加载失败的 dateKey 集合（:112-117）。 */
    val failedThumbs: Set<String> = emptySet(),
    /** 「今天」的参照日（调用方注入，便于单测钉住日期）。 */
    val today: LocalDate = LocalDate.of(1970, 1, 1),
)
