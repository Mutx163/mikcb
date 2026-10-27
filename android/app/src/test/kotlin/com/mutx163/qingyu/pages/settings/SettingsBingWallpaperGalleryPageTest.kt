package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Bing 每日壁纸图库（`lib/screens/settings/bing_wallpaper_gallery_page.dart`）结构测试。
 *
 * 这一页的「状态机」比 UI 复杂得多（加载 / 失败 / 显示的是缓存 / 下载中 / 排队中 /
 * 缩略图失败），所以模型层把**块与状态推导**搬过来，UI 只消费。
 *
 * 期望值来源：Dart 源 + ARB + `tools/bing_wallpaper_date_label.dart`。
 */
class SettingsBingWallpaperGalleryPageTest {

    private fun spec(state: BingGalleryState = BingGalleryState()) =
        SettingsBingWallpaperGalleryPage.spec(state)

    // ---------------------------------------------------------------- 页面骨架

    @Test
    fun `页面标题`() {
        // :347-352
        val page = spec()
        assertEquals("settings-bing-wallpaper-gallery", page.id)
        assertEquals("bingWallpaperGalleryTitle", page.titleKey)
        assertEquals("Bing 每日壁纸", page.title)
    }

    @Test
    fun `默认是加载中且一条条目都没有`() {
        // :88-89 `_loading = true` / `_items = const []`
        val page = spec()
        assertEquals(
            BingGalleryBody.LOADING,
            SettingsBingWallpaperGalleryPage.bodyState(BingGalleryState()),
        )
        assertTrue(page.flatten().filterIsInstance<SettingsDescription>().any { it.textKey == "commonLoadingLabel" })
    }

    @Test
    fun `加载完有图时是网格`() {
        // :397-443
        val state = BingGalleryState(loading = false, items = listOf(bingItem("20261005")))
        assertEquals(BingGalleryBody.GRID, SettingsBingWallpaperGalleryPage.bodyState(state))
        val page = spec(state)
        assertEquals(
            listOf("grid.20261005"),
            page.group("gallery.grid").childRowIds(),
        )
    }

    @Test
    fun `一次都没成功过才是失败页`() {
        // :123-130 / :405-409：空清单 = 一次都没成功过；有过缓存不算失败
        val failed = BingGalleryState(loading = false, failed = true)
        assertEquals(BingGalleryBody.FAILURE, SettingsBingWallpaperGalleryPage.bodyState(failed))
        val page = spec(failed)
        assertEquals(
            "没能取到 Bing 每日壁纸，请检查网络后重试",
            page.flatten().filterIsInstance<SettingsDescription>().single { it.textKey == "bingWallpaperGalleryFailed" }.text,
        )
        assertEquals("重试", page.row("gallery.retry").title)
    }

    @Test
    fun `有缓存时要显示来路提示`() {
        // :410-423：与 _failed 分开 —— 上次成功过、这次没拿到，照常显示旧的并说明来路
        val cached = BingGalleryState(
            loading = false,
            items = listOf(bingItem("20261005")),
            showingCached = true,
        )
        assertEquals(BingGalleryBody.GRID, SettingsBingWallpaperGalleryPage.bodyState(cached))
        assertEquals(
            "网络不太顺畅，下面显示的是上次加载的图",
            spec(cached).row("gallery.showingCached").title,
        )
        // 没走缓存时不出现
        val fresh = BingGalleryState(loading = false, items = listOf(bingItem("20261005")))
        assertFalse(spec(fresh).flattenedIds().contains("gallery.showingCached"))
    }

    // ---------------------------------------------------------------- 单张卡

    @Test
    fun `卡片的日期与版权说明`() {
        // :580-597：日期一行 + 版权说明两行；版权为空时退回标题
        val item = BingGalleryItem(
            dateKey = "20261005",
            title = "标题兜底",
            copyright = "© 某某",
            thumbnailUrl = "https://example.com/t.jpg",
        )
        val card = SettingsBingWallpaperGalleryPage.card(item, BingGalleryState(loading = false))
        assertEquals("20261005", card.id)
        assertEquals("© 某某", card.copyright)
        assertEquals(2, card.copyrightMaxLines)
        assertEquals(1, card.dateMaxLines)

        val emptyCopyright = BingGalleryWallpaperCard(
            id = "20261006",
            dateLabel = "10 月 6 日",
            copyright = "标题兜底",
            thumbnailUrl = "t.jpg",
            state = BingWallpaperCardState.IDLE,
            progressLabel = null,
        )
        // 版权为空时 takeIf 退回标题，由模型层算好
        assertEquals(
            "标题兜底",
            SettingsBingWallpaperGalleryPage.copyrightText(
                copyright = "",
                title = "标题兜底",
                thumbFailed = false,
            ),
        )
    }

    @Test
    fun `缩略图加载失败时文案带上轻点重试`() {
        // :587-597 `'${...}（${l10n.wallpaperThumbRetryHint}）'`
        assertEquals(
            "© 某某（轻点重试）",
            SettingsBingWallpaperGalleryPage.copyrightText(
                copyright = "© 某某",
                title = "标题兜底",
                thumbFailed = true,
            ),
        )
    }

    @Test
    fun `卡片的五种状态`() {
        // :491-493 + :556-575
        val items = listOf(bingItem("20261005"))
        val downloading = BingGalleryState(
            loading = false,
            items = items,
            downloadingDateKey = "20261005",
            downloadingPercent = 42,
        )
        val busy = SettingsBingWallpaperGalleryPage.card(items[0], downloading)
        assertEquals(BingWallpaperCardState.DOWNLOADING, busy.state)
        assertEquals("正在下载 42%", busy.progressLabel)

        // CDN 没给总长时只转圈不报百分比（:608-612）
        val unknown = downloading.copy(downloadingPercent = -1)
        assertEquals("正在下载 …", SettingsBingWallpaperGalleryPage.card(items[0], unknown).progressLabel)

        // 排队中：只给转圈（:564-574）
        val queued = BingGalleryState(loading = false, items = items, queuedDateKey = "20261005")
        assertEquals(BingWallpaperCardState.QUEUED, SettingsBingWallpaperGalleryPage.card(items[0], queued).state)

        // 缩略图失败：占位色块 + 「轻点重试」（:112-121）
        val thumbFailed = BingGalleryState(loading = false, items = items, failedThumbs = setOf("20261005"))
        assertEquals(
            BingWallpaperCardState.THUMB_FAILED,
            SettingsBingWallpaperGalleryPage.card(items[0], thumbFailed).state,
        )

        // 常态
        assertEquals(
            BingWallpaperCardState.IDLE,
            SettingsBingWallpaperGalleryPage.card(items[0], BingGalleryState(loading = false, items = items)).state,
        )
    }

    @Test
    fun `点缩略图失败的那张只重试不下大图`() {
        // :190-199：用户点的是「这块怎么空了」，不是「我要这张当壁纸」
        val state = BingGalleryState(loading = false, failedThumbs = setOf("20261005"))
        assertEquals(
            BingPickIntent.RETRY_THUMB,
            SettingsBingWallpaperGalleryPage.pickIntent(bingItem("20261005"), state),
        )
        // 下载中：排队（:200-208）
        val downloading = state.copy(failedThumbs = emptySet(), downloadingDateKey = "20261004")
        assertEquals(
            BingPickIntent.QUEUE,
            SettingsBingWallpaperGalleryPage.pickIntent(bingItem("20261005"), downloading),
        )
        // 空闲：直接下载
        assertEquals(
            BingPickIntent.DOWNLOAD,
            SettingsBingWallpaperGalleryPage.pickIntent(
                bingItem("20261005"),
                state.copy(failedThumbs = emptySet()),
            ),
        )
    }

    @Test
    fun `下载中的那张再点一次不改队列`() {
        // :201 `if (_queuedItemId != item.dateKey)`
        val state = BingGalleryState(
            loading = false,
            downloadingDateKey = "20261005",
            queuedDateKey = "20261005",
        )
        assertFalse(
            SettingsBingWallpaperGalleryPage.shouldRequeue("20261005", state),
        )
        assertTrue(SettingsBingWallpaperGalleryPage.shouldRequeue("20261006", state))
    }

    @Test
    fun `下载进度按整数百分比节流`() {
        // :104-110 + :243-257：1% 粒度，整数百分比变了才重建
        assertEquals(42, SettingsBingWallpaperGalleryPage.downloadPercent(420, 1000))
        assertEquals(0, SettingsBingWallpaperGalleryPage.downloadPercent(4, 1000))
        // CDN 没给总长（null / 0）→ -1，只转圈
        assertEquals(-1, SettingsBingWallpaperGalleryPage.downloadPercent(500, null))
        assertEquals(-1, SettingsBingWallpaperGalleryPage.downloadPercent(500, 0))
        assertEquals(-1, SettingsBingWallpaperGalleryPage.downloadPercent(null, 1000))
    }

    @Test
    fun `下载失败的两种文案`() {
        // :285-293：拿不到状态码（断网）退回通用文案，拿得到就带状态码
        assertEquals(
            "这张壁纸没能下载成功，请稍后再试",
            SettingsBingWallpaperGalleryPage.downloadFailureMessage(-1).zh,
        )
        assertEquals(
            "壁纸下载失败 503",
            SettingsBingWallpaperGalleryPage.downloadFailureMessage(503).filled("status", "503"),
        )
    }

    @Test
    fun `排队时给一句提示`() {
        // :203-206
        assertEquals("上一张还在下载，这张已排队，马上就好", SettingsStringsExt1.bingWallpaperDownloadQueued.zh)
    }

    // ------------------------------------------------------------ 日期标签

    @Test
    fun `日期标签三档说法`() {
        // utils/bing_wallpaper_date_label.dart:16-38
        val now = java.time.LocalDate.of(2026, 10, 5)
        assertEquals("今天", SettingsBingWallpaperGalleryPage.dateLabel("20261005", now))
        assertEquals("昨天", SettingsBingWallpaperGalleryPage.dateLabel("20261004", now))
        assertEquals("10 月 3 日", SettingsBingWallpaperGalleryPage.dateLabel("20261003", now))
        // 未来的日期（Bing 的 enddate 偶尔跨到明天）与更早的走同一条月日，
        // 不给「-1 天前」这种负数说法
        assertEquals("10 月 6 日", SettingsBingWallpaperGalleryPage.dateLabel("20261006", now))
    }

    @Test
    fun `日期解析的边界`() {
        // :47-75：长度不对 / 非数字 / 月日越界都算失败，原样退回那串数字
        assertNull(SettingsBingWallpaperGalleryPage.parseDateKey("2026100"))
        assertNull(SettingsBingWallpaperGalleryPage.parseDateKey("202610051"))
        assertNull(SettingsBingWallpaperGalleryPage.parseDateKey("20261345"))
        assertNull(SettingsBingWallpaperGalleryPage.parseDateKey("20260005"))
        assertNull(SettingsBingWallpaperGalleryPage.parseDateKey("  261005"))
        assertNull(SettingsBingWallpaperGalleryPage.parseDateKey("abcdefgh"))
        assertEquals(java.time.LocalDate.of(2026, 10, 5), SettingsBingWallpaperGalleryPage.parseDateKey("20261005"))
    }

    @Test
    fun `解析不出来时原样显示那串数字`() {
        val now = java.time.LocalDate.of(2026, 10, 5)
        assertEquals("20261345", SettingsBingWallpaperGalleryPage.dateLabel("20261345", now))
    }

    // ------------------------------------------------------------ 台账白名单

    @Test
    fun `台账溢出删除时的白名单三路并集`() {
        // :322-341：keep（刚挑中的）+ 宿主传的 protectedPaths + 最近使用
        val whitelist = SettingsBingWallpaperGalleryPage.evictionWhitelist(
            keep = "/w/now.jpg",
            protectedPaths = listOf("/w/other-profile.jpg"),
            history = listOf("/w/old1.jpg", "/w/old2.jpg"),
        )
        assertEquals(
            setOf("/w/now.jpg", "/w/other-profile.jpg", "/w/old1.jpg", "/w/old2.jpg"),
            whitelist,
        )
        // keep 为 null 时安全跳过
        assertEquals(
            setOf("/w/old1.jpg"),
            SettingsBingWallpaperGalleryPage.evictionWhitelist(
                keep = null,
                protectedPaths = emptyList(),
                history = listOf("/w/old1.jpg"),
            ),
        )
    }

    @Test
    fun `网格是两列竖卡`() {
        // :424-441：crossAxisCount 2 / 主轴间距 14 / 交叉轴 12 / childAspectRatio 0.56
        assertEquals(2, SettingsBingWallpaperGalleryPage.GRID_CROSS_AXIS_COUNT)
        assertEquals(14.0, SettingsBingWallpaperGalleryPage.GRID_MAIN_AXIS_SPACING, 0.0)
        assertEquals(12.0, SettingsBingWallpaperGalleryPage.GRID_CROSS_AXIS_SPACING, 0.0)
        assertEquals(0.56, SettingsBingWallpaperGalleryPage.GRID_CHILD_ASPECT_RATIO, 1e-9)
    }

    // ---------------------------------------------------------------- 文案齐备

    @Test
    fun `图库用到的文案键都在`() {
        // :289-291 / :348 / :417 / :472 / :480 / :590 / :611 / :205
        val keys = listOf(
            SettingsStringsExt1.bingWallpaperGalleryTitle,
            SettingsStringsExt1.bingWallpaperGalleryFailed,
            SettingsStringsExt1.bingWallpaperGalleryRetry,
            SettingsStringsExt1.wallpaperGalleryShowingCached,
            SettingsStringsExt1.bingWallpaperDownloadFailed,
            SettingsStringsExt1.bingWallpaperDownloadProgress,
            SettingsStringsExt1.bingWallpaperDownloadStatus,
            SettingsStringsExt1.bingWallpaperDownloadQueued,
            SettingsStringsExt1.wallpaperThumbRetryHint,
        ).map { it.key }
        assertEquals(
            listOf(
                "bingWallpaperGalleryTitle",
                "bingWallpaperGalleryFailed",
                "bingWallpaperGalleryRetry",
                "wallpaperGalleryShowingCached",
                "bingWallpaperDownloadFailed",
                "bingWallpaperDownloadProgress",
                "bingWallpaperDownloadStatus",
                "bingWallpaperDownloadQueued",
                "wallpaperThumbRetryHint",
            ),
            keys,
        )
    }

    /** 造一个图库条目（只有 dateKey 关心的用例用它，版权与标题给固定值）。 */
    private fun bingItem(dateKey: String) = BingGalleryItem(
        dateKey = dateKey,
        title = "今日图",
        copyright = "© 摄影师甲",
        thumbnailUrl = "https://example.com/$dateKey.jpg",
    )
}
