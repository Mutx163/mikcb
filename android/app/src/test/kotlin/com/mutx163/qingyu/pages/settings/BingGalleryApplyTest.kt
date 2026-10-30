package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import com.mutx163.qingyu.weather.BingWallpaperItem
import com.mutx163.qingyu.weather.BingWallpaperResolution
import com.mutx163.qingyu.weather.WallpaperTargetSize
import java.io.File
import java.nio.file.Files
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 图库的下载 / 落盘 / 写设置链路（`BingGalleryApplyPlanner` + `BingGalleryDownloader`）。
 *
 * 期望值来源：Dart `bing_wallpaper_gallery_page.dart:190-345`（点图 → 下载 → 记账 →
 * 交回宿主）+ `bing_wallpaper_service.dart`（缺档退档）+ `wallpaper_history.dart`（去重置顶、封顶 10）。
 *
 * 这里钉的几件事，任何一条写错用户都会看见：
 * - 同名文件复用（重复点不重复下、按错档位下成糊图）；
 * - 404 才退档、断网不退档（退档会把一次失败拖成三次超时）；
 * - 200 但 body 是 HTML 时不许写进 `.jpg`（写了首页就是裂图）；
 * - 写设置时历史置顶/封顶、溢出文件要删、正在用的那张不许删。
 */
class BingGalleryApplyTest {

    private val item = BingWallpaperItem(
        dateKey = "20261005",
        urlBase = "/th?id=OHR.AdelieTeacher_ZH-CN5343194378",
        title = "阿德利企鹅",
        copyright = "阿德利企鹅，南极洲 (© Martin Bailey)",
    )

    /** 1080×2400 的手机屏（HIGH 档 1440×3200 会被抬到不低于屏幕）。 */
    private val screen = WallpaperTargetSize(1080, 2400)
    private val today: LocalDate = LocalDate.of(2026, 10, 5)

    private val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 0x00)
    private val png = byteArrayOf(0x89.toByte(), 0x50.toByte(), 0x4E.toByte(), 0x47.toByte(), 0x00)

    private fun stateOf(vararg keys: String) = BingGalleryState(
        loading = false,
        items = keys.map { BingGalleryItem(it, "t", "c", "https://example/$it.jpg") },
        today = today,
    )

    private fun tempDir(): File = Files.createTempDirectory("bing-gallery-l0").toFile()

    // ------------------------------------------------------------ 下载计划

    @Test
    fun `默认档位是 high 且实际像素不低于屏幕`() {
        val plan = BingGalleryApplyPlanner.plan(item, screen)
        assertEquals(BingWallpaperResolution.HIGH, plan.resolution)
        // HIGH(1440×3200).downloadTargetSize(1080×2400) ⇒ 按高抬到 3200，宽按 9:16 反推 1440
        assertEquals(WallpaperTargetSize(1440, 3200), plan.targetSize)
    }

    @Test
    fun `文件名带日期与档位 便于同名复用`() {
        val plan = BingGalleryApplyPlanner.plan(item, screen)
        assertTrue("文件名应以 wallpaper_bing_ 开头：${plan.fileName}", plan.fileName.startsWith("wallpaper_bing_"))
        assertTrue(plan.fileName.contains("20261005"))
        assertTrue(plan.fileName.contains(BingWallpaperResolution.HIGH.storageKey))
        assertTrue(plan.fileName.endsWith(".jpg"))
    }

    @Test
    fun `下载地址取的是图片 id 而不是整条 urlbase`() {
        val plan = BingGalleryApplyPlanner.plan(item, screen)
        // 把 `/th?id=…` 整串塞进 resize 的 id= 会得到 `id=/th?id=…` ⇒ 实测 404
        assertFalse("URL 不该出现 id=/th：${plan.url}", plan.url.contains("id=/th"))
        assertTrue(plan.url.contains("OHR.AdelieTeacher_ZH-CN5343194378_UHD.jpg"))
        assertTrue(plan.url.startsWith("https://www.bing.com/th?"))
    }

    @Test
    fun `退档阶梯从大到小且最后一档是预生成尺寸`() {
        assertEquals(
            listOf(
                BingWallpaperResolution.HIGH,
                BingWallpaperResolution.TALL,
                BingWallpaperResolution.STANDARD,
            ),
            BingGalleryApplyPlanner.DOWNLOAD_TIERS,
        )
    }

    // ------------------------------------------------------------ 状态推导

    @Test
    fun `拉到非空清单就是正常网格`() {
        val next = BingGalleryApplyPlanner.stateAfterFetch(
            BingGalleryState(),
            listOf(item),
            today,
        )
        assertFalse(next.loading)
        assertFalse(next.failed)
        assertFalse(next.showingCached)
        assertEquals(1, next.items.size)
        assertEquals("20261005", next.items[0].dateKey)
        assertEquals(today, next.today)
    }

    @Test
    fun `一次都没成功过时 空清单就是失败页`() {
        val next = BingGalleryApplyPlanner.stateAfterFetch(BingGalleryState(), emptyList(), today)
        assertTrue(next.failed)
        assertFalse(next.loading)
        assertFalse(next.showingCached)
        assertEquals(BingGalleryBody.FAILURE, SettingsBingWallpaperGalleryPage.bodyState(next))
    }

    @Test
    fun `上次成功过 这次空清单 照常显示旧的并标出来路`() {
        val cached = stateOf("20261001", "20261002")
        val next = BingGalleryApplyPlanner.stateAfterFetch(cached, emptyList(), today)
        assertFalse("显示的是旧的那份，不算失败页", next.failed)
        assertTrue(next.showingCached)
        assertEquals(2, next.items.size)
        assertEquals(BingGalleryBody.GRID, SettingsBingWallpaperGalleryPage.bodyState(next))
    }

    @Test
    fun `开拉清掉上次的失败标记`() {
        val failed = BingGalleryApplyPlanner.stateAfterFailure(BingGalleryState(), today)
        assertTrue(failed.failed)
        val loading = BingGalleryApplyPlanner.stateLoading(failed, today)
        assertTrue(loading.loading)
        assertFalse(loading.failed)
    }

    @Test
    fun `缩略图失败 与 点它重试`() {
        val failed = BingGalleryApplyPlanner.stateThumbFailed(stateOf("20261005"), "20261005")
        assertTrue(failed.failedThumbs.contains("20261005"))
        assertEquals(
            BingWallpaperCardState.THUMB_FAILED,
            SettingsBingWallpaperGalleryPage
                .card(failed.items[0], failed).state,
        )
        val retried = BingGalleryApplyPlanner.stateThumbRetried(failed, "20261005")
        assertTrue(retried.failedThumbs.isEmpty())
    }

    @Test
    fun `下载中 进度 结束 三个状态`() {
        val started = BingGalleryApplyPlanner.stateDownloading(stateOf("20261005"), "20261005")
        assertEquals("20261005", started.downloadingDateKey)
        assertEquals(-1, started.downloadingPercent)
        assertNull(started.queuedDateKey)

        val half = BingGalleryApplyPlanner.stateProgress(started, 42)
        assertEquals(42, half.downloadingPercent)
        assertEquals(
            BingWallpaperCardState.DOWNLOADING,
            SettingsBingWallpaperGalleryPage.card(half.items[0], half).state,
        )

        val done = BingGalleryApplyPlanner.stateDownloadDone(half)
        assertNull(done.downloadingDateKey)
        assertEquals(-1, done.downloadingPercent)
    }

    @Test
    fun `下载中点另一张是排队 不是忽略`() {
        val downloading = BingGalleryApplyPlanner.stateDownloading(stateOf("20261005", "20261004"), "20261005")
        val queued = BingGalleryApplyPlanner.stateQueued(downloading, "20261004")
        assertEquals("20261004", queued.queuedDateKey)
        // 排队那张立刻显示「排队中」，用户看得见点到了
        assertEquals(
            BingWallpaperCardState.QUEUED,
            SettingsBingWallpaperGalleryPage.card(queued.items[1], queued).state,
        )
    }

    @Test
    fun `网格条目带 480x854 缩略图地址`() {
        val items = BingGalleryApplyPlanner.galleryItems(listOf(item))
        assertEquals(1, items.size)
        assertTrue(items[0].thumbnailUrl.contains("w=480"))
        assertTrue(items[0].thumbnailUrl.contains("h=854"))
    }

    // ------------------------------------------------------------ 下载器

    private class FakeBinaryHttp(
        private val respond: (url: String) -> BingGalleryBytes,
    ) : BingGalleryBinaryHttp {
        val requested = mutableListOf<String>()
        override fun get(url: String, progress: BingGalleryProgress): BingGalleryBytes {
            requested += url
            val bytes = respond(url)
            progress.onProgress(bytes.body.size.toLong(), bytes.body.size.toLong())
            return bytes
        }
    }

    @Test
    fun `下载成功写到受管目录`() {
        val dir = tempDir()
        val http = FakeBinaryHttp { BingGalleryBytes(200, jpeg) }
        val result = BingGalleryDownloader(dir, http).download(item, screen)
        assertTrue(result is BingGalleryDownloadResult.Success)
        val success = result as BingGalleryDownloadResult.Success
        assertTrue(success.file.isFile)
        assertEquals(jpeg.size.toLong(), success.file.length())
        assertFalse(success.reused)
        assertEquals(1, http.requested.size)
        dir.deleteRecursively()
    }

    @Test
    fun `同名文件已存在就不再发请求`() {
        val dir = tempDir()
        val http = FakeBinaryHttp { BingGalleryBytes(200, jpeg) }
        val downloader = BingGalleryDownloader(dir, http)
        downloader.download(item, screen)
        val again = downloader.download(item, screen)
        assertTrue(again is BingGalleryDownloadResult.Success)
        assertTrue((again as BingGalleryDownloadResult.Success).reused)
        assertEquals("第二次不该再打网络", 1, http.requested.size)
        dir.deleteRecursively()
    }

    @Test
    fun `缺档 404 时退一档重下`() {
        val dir = tempDir()
        val http = FakeBinaryHttp { url ->
            // high / tall 走 resize（URL 里带 w=1440 / h=3200 那组），standard 走预生成后缀
            if (url.contains("w=1440")) BingGalleryBytes(404, ByteArray(0)) else BingGalleryBytes(200, jpeg)
        }
        val result = BingGalleryDownloader(dir, http).download(item, screen)
        assertTrue(result is BingGalleryDownloadResult.Success)
        val success = result as BingGalleryDownloadResult.Success
        assertEquals(BingWallpaperResolution.TALL, success.resolution)
        assertEquals(2, http.requested.size)
        assertNotNull(success.file.name)
        dir.deleteRecursively()
    }

    @Test
    fun `断网不退档 一次就如实失败`() {
        val dir = tempDir()
        val http = FakeBinaryHttp { BingGalleryBytes(-1, ByteArray(0)) }
        val result = BingGalleryDownloader(dir, http).download(item, screen)
        assertTrue(result is BingGalleryDownloadResult.Failure)
        assertEquals(-1, (result as BingGalleryDownloadResult.Failure).statusCode)
        assertEquals("断网换档也必然失败，不许连打三次", 1, http.requested.size)
        dir.deleteRecursively()
    }

    @Test
    fun `状态码 200 但 body 是 HTML 时不许落盘`() {
        val dir = tempDir()
        val html = "<html>error</html>".toByteArray()
        val http = FakeBinaryHttp { BingGalleryBytes(200, html) }
        val result = BingGalleryDownloader(dir, http).download(item, screen)
        assertTrue(result is BingGalleryDownloadResult.Failure)
        // 三档都试过（HTML 属「缺档」那一类）
        assertEquals(3, http.requested.size)
        assertEquals(0, dir.listFiles()?.size ?: 0)
        dir.deleteRecursively()
    }

    @Test
    fun `PNG 也认 但空 body 直接失败`() {
        assertTrue(BingGalleryApplyPlanner.looksLikeImage(png))
        assertTrue(BingGalleryApplyPlanner.looksLikeImage(jpeg))
        assertFalse(BingGalleryApplyPlanner.looksLikeImage("<html".toByteArray()))
        assertFalse(BingGalleryApplyPlanner.looksLikeImage(ByteArray(0)))
    }

    @Test
    fun `写盘失败不留半截文件`() {
        val dir = tempDir()
        // `.part` 那个名字被一个「目录」占住 ⇒ 写临时文件必抛 IOException
        val plan = BingGalleryApplyPlanner.plan(item, screen)
        File(dir, plan.fileName + ".part").mkdirs()
        val http = FakeBinaryHttp { BingGalleryBytes(200, jpeg) }
        val result = BingGalleryDownloader(dir, http).download(item, screen)
        assertTrue(result is BingGalleryDownloadResult.Failure)
        // 目标文件一字节都没留下（半截文件会被下次当成已下过的整图）
        assertFalse(File(dir, plan.fileName).exists())
        dir.deleteRecursively()
    }

    // ------------------------------------------------------------ 写设置

    @Test
    fun `落盘后壁纸路径指过去 取景归位 `() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/old/a.jpg",
            homePageWallpaperAlignX = 0.8,
            homePageWallpaperAlignY = -0.5,
            homePageWallpaperScale = 2.0,
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(current, "/new/bing.jpg", nowMs = 1000L)
        assertEquals("/new/bing.jpg", outcome.settings.homePageWallpaperPath)
        assertEquals(0.0, outcome.settings.homePageWallpaperAlignX, 0.0)
        assertEquals(0.0, outcome.settings.homePageWallpaperAlignY, 0.0)
        assertEquals(1.0, outcome.settings.homePageWallpaperScale, 0.0)
        // 旧的壁纸不该被当成「最近使用」自动补记
        assertFalse(outcome.settings.wallpaperHistory.any { it.key == "/old/a.jpg" })
        assertEquals("/new/bing.jpg", outcome.settings.wallpaperHistory.first().key)
        assertEquals(1000L, outcome.settings.wallpaperHistory.first().usedAt)
    }

    @Test
    fun `历史去重置顶 且封顶 10 条`() {
        val history = (1..10).map { i ->
            WallpaperHistoryRowModel(key = "/p/$i.jpg", usedAt = i.toLong())
        }
        val current = TimetableSettingsModel(wallpaperHistory = history)
        // 重挑一张已经在历史里的：去重后总数仍是 10，什么都不该被挤出去
        val same = BingGalleryApplyPlanner.settingsAfterApply(current, "/p/5.jpg", nowMs = 99L)
        assertEquals(10, same.settings.wallpaperHistory.size)
        assertEquals("/p/5.jpg", same.settings.wallpaperHistory.first().key)
        assertEquals(99L, same.settings.wallpaperHistory.first().usedAt)
        assertEquals(1, same.settings.wallpaperHistory.count { it.key == "/p/5.jpg" })
        assertEquals(emptyList<String>(), same.filesToDelete)

        // 挑一张新的：11 条 → 封顶 10，最旧那条（/p/10.jpg）被挤出去要删
        val fresh = BingGalleryApplyPlanner.settingsAfterApply(current, "/p/new.jpg")
        assertEquals(10, fresh.settings.wallpaperHistory.size)
        assertEquals("/p/new.jpg", fresh.settings.wallpaperHistory.first().key)
        assertEquals(listOf("/p/10.jpg"), fresh.filesToDelete)
    }

    @Test
    fun `正在用的那张不许被溢出回收删掉`() {
        val history = (1..10).map { i -> WallpaperHistoryRowModel(key = "/p/$i.jpg") }
        val current = TimetableSettingsModel(wallpaperHistory = history)
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(current, "/p/new.jpg")
        // 白名单里放的是**写完之后**的设置：当前壁纸 + 历史，evicted 天然不在里面
        val whitelist = BingGalleryApplyPlanner.deletionWhitelist(outcome.settings, keep = "/p/new.jpg")
        assertTrue(whitelist.contains("/p/new.jpg"))
        assertTrue(whitelist.contains("/p/1.jpg"))
        assertFalse(whitelist.contains("/p/10.jpg"))
        assertTrue(outcome.filesToDelete.none { it == "/p/new.jpg" })
    }

    @Test
    fun `历史里有脏条目时不清空整份设置`() {
        val current = TimetableSettingsModel(
            wallpaperHistory = listOf(
                WallpaperHistoryRowModel(key = "/p/1.jpg"),
                WallpaperHistoryRowModel(key = "   "),
            ),
        )
        val outcome = BingGalleryApplyPlanner.settingsAfterApply(current, "/p/2.jpg")
        assertEquals(2, outcome.settings.wallpaperHistory.size)
        assertEquals("/p/2.jpg", outcome.settings.wallpaperHistory.first().key)
    }
}
