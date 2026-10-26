package com.mutx163.qingyu.weather

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 咬合探针（反 carnivore 测试）：这条测试钉的是「文件名净化真的发生在拼接点」。
 *
 * [人推]：`BingWallpaperItem.fileName` 的文档（lib/models/bing_wallpaper.dart:304-307）
 * 明确承诺 dateKey 来自服务端/同步台账、必须先过 `safeWallpaperNameSegment`
 * 净化——`'../../x'` 这类值能把文件写到壁纸目录之外（2026-10-08 实测）。
 *
 * 探针方向：把实现里 `safeWallpaperNameSegment(dateKey, …)` 临时改成裸拼
 * `dateKey`，本条必须变红（assertFalse 会拿到含 `/` 的文件名）——证明这条测试
 * 有牙齿，不是「永远绿的摆设」。探针记录见交付说明。
 */
class WallpaperFileNameBiteProbeTest {

    @Test
    fun `hostile dateKey never leaks separators into file name`() { // [人推] fileName 必须在拼接前净化外部标识符
        for (hostile in listOf(
            "/../../planted.txt",
            "..\\..\\evil",
            "a/b",
            "中文名",
            "",
            "..",
        )) {
            val name = BingWallpaperItem(
                dateKey = hostile,
                urlBase = "/th?id=OHR.X_EN-US1",
                title = "",
                copyright = "",
            ).fileName(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920))
            assertFalse("dateKey=[$hostile] 的分隔符漏进了文件名: $name", name.contains("/"))
            assertFalse("dateKey=[$hostile] 的反斜杠漏进了文件名: $name", name.contains("\\"))
            assertFalse("dateKey=[$hostile] 的中文字符漏进了文件名: $name", name.any { it.code > 0x7F })
        }
        // 空段特例（清洗后为空 / 完整一段 `.` / `..`）必须退回占位 `day`：
        // 日期位不会以「空段」形态进文件名（wallpaper_bing__standard.jpg 不会出现）。
        for (blank in listOf("", ".", "..")) {
            val name = BingWallpaperItem(
                dateKey = blank,
                urlBase = "/th?id=OHR.X_EN-US1",
                title = "",
                copyright = "",
            ).fileName(BingWallpaperResolution.STANDARD, WallpaperTargetSize(1080, 1920))
            assertTrue("空 dateKey 应退回占位 day: $name", name.startsWith("wallpaper_bing_day_standard.jpg"))
        }
    }
}
