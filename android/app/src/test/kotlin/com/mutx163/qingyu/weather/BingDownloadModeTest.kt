package com.mutx163.qingyu.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Bing 下载模式的纯判定（download 链路里不碰网络的分支）。
 *
 * 期望值来源：[Dart推演] lib/services/bing_wallpaper_service.dart 的
 * `download()` 退档链与 `_isMissingTier`——只有「Bing 说这张没有（404）/ 给的不是图」
 * 才值得退档重试，网络/写盘失败退档只会把一次失败拖成两次超时。
 */
class BingDownloadModeTest {

    @Test
    fun `only status and notImage justify a tier fallback`() { // [Dart推演] _isMissingTier
        assertTrue(isMissingTierFailure(DownloadFailure.Status))
        assertTrue(isMissingTierFailure(DownloadFailure.NotImage))
        assertFalse(isMissingTierFailure(DownloadFailure.Network))
        assertFalse(isMissingTierFailure(DownloadFailure.EmptyBody))
        assertFalse(isMissingTierFailure(DownloadFailure.Write))
        assertFalse(isMissingTierFailure(null))
    }

    @Test
    fun `standard tier requests the pregenerated suffix`() { // [Dart推演] standard 有 sizeSuffix → 直接后缀 URL
        val item = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X_EN-US1", title = "", copyright = "")
        assertEquals(
            "https://www.bing.com/th?id=OHR.X_EN-US1_1080x1920.jpg",
            item.downloadUrl(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)),
        )
    }

    @Test
    fun `resize tier requests w h with c4 and qlt95`() { // [Dart推演] 无后缀 → resize URL（同 fullUrl(target)）
        val item = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X_EN-US1", title = "", copyright = "")
        assertEquals(
            item.fullUrl(BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
            item.downloadUrl(BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
        )
    }

    @Test
    fun `expected download size matches the url contract`() { // [Dart推演] 验尺寸的期望值与 URL 同口径
        val item = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X_EN-US1", title = "", copyright = "")
        assertEquals(
            WallpaperTargetSize(1080, 1920),
            item.expectedDownloadSize(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920)),
        )
        assertEquals(
            WallpaperTargetSize(1440, 3200),
            item.expectedDownloadSize(BingWallpaperResolution.HIGH, WallpaperTargetSize(1440, 3200)),
        )
    }
}
