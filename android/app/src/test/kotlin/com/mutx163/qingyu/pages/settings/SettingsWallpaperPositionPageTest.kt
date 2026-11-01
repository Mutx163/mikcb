package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸取景页的**纯逻辑**测试（Dart `wallpaper_position_picker_sheet.dart`）。
 *
 * 覆盖四件事：
 * 1. 对齐 / 倍数的夹取与百分比换算；
 * 2. cover 溢出量（拖动折算的分母）——特别是「不是基础溢出 × 倍数」那条；
 * 3. 拖动方向与边界（该轴不溢出时归 0）；
 * 4. 「完成」写回的键与「最近使用」的补记 / 上限。
 *
 * 期望值全部从 Dart 源推出（注释里带行号），不是照抄当前实现。
 */
class SettingsWallpaperPositionPageTest {

    // ------------------------------------------------------------ 夹取 / 换算

    @Test
    fun `对齐值夹进负一到一，NaN 按居中`() {
        // Dart `wallpaperAlignAfterDrag` 的 clamp(-1.0, 1.0)（:95）
        assertEquals(-1.0, SettingsWallpaperPositionPage.clampAlign(-3.0), 0.0)
        assertEquals(1.0, SettingsWallpaperPositionPage.clampAlign(9.0), 0.0)
        assertEquals(0.25, SettingsWallpaperPositionPage.clampAlign(0.25), 0.0)
        // NaN 不能让取景变成不可绘制
        assertEquals(0.0, SettingsWallpaperPositionPage.clampAlign(Double.NaN), 0.0)
    }

    @Test
    fun `放大倍数夹进一到四，NaN 按刚好铺满`() {
        // `kWallpaperMinScale` / `kWallpaperMaxScale`（home_page_background.dart:586-587）
        assertEquals(SettingsWallpaperPositionPage.MIN_SCALE, 1.0, 0.0)
        assertEquals(SettingsWallpaperPositionPage.MAX_SCALE, 4.0, 0.0)
        assertEquals(1.0, SettingsWallpaperPositionPage.clampScale(0.2), 0.0)
        assertEquals(4.0, SettingsWallpaperPositionPage.clampScale(8.0), 0.0)
        assertEquals(2.5, SettingsWallpaperPositionPage.clampScale(2.5), 0.0)
        assertEquals(1.0, SettingsWallpaperPositionPage.clampScale(Double.NaN), 0.0)
    }

    @Test
    fun `对齐值换比例：负一是左或上边缘，零是居中，一是右或下边缘`() {
        // Dart `(align + 1) / 2`（HomeBackgroundModel.drawRect 同一条）
        assertEquals(0.0, SettingsWallpaperPositionPage.alignFraction(-1.0), 0.0)
        assertEquals(0.5, SettingsWallpaperPositionPage.alignFraction(0.0), 0.0)
        assertEquals(1.0, SettingsWallpaperPositionPage.alignFraction(1.0), 0.0)
        // 越界先夹再换算
        assertEquals(1.0, SettingsWallpaperPositionPage.alignFraction(5.0), 0.0)
    }

    @Test
    fun `百分比换算：一百是刚好铺满，四百是上限`() {
        assertEquals(100, SettingsWallpaperPositionPage.scalePercent(1.0))
        assertEquals(150, SettingsWallpaperPositionPage.scalePercent(1.5))
        assertEquals(400, SettingsWallpaperPositionPage.scalePercent(4.0))
        // 越界按夹取后的值换算
        assertEquals(400, SettingsWallpaperPositionPage.scalePercent(9.0))
        assertEquals(100, SettingsWallpaperPositionPage.scalePercent(0.1))
    }

    // ------------------------------------------------------------ 溢出量

    @Test
    fun `cover 基准倍率取宽高两个缩放里更大的那个`() {
        // 4000x3000 的图放进 1080x2400 的竖屏：宽 0.27、高 0.8 -> 取 0.8
        assertEquals(
            0.8,
            SettingsWallpaperPositionPage.coverScale(
                imageWidth = 4000,
                imageHeight = 3000,
                viewportWidth = 1080,
                viewportHeight = 2400,
            ),
            1e-9,
        )
        // 任一维非正 -> 0（调用方据此跳过绘制 / 拖动）
        assertEquals(
            0.0,
            SettingsWallpaperPositionPage.coverScale(0, 3000, 1080, 2400),
            0.0,
        )
    }

    @Test
    fun `溢出量是放大之后的溢出，不是基础溢出乘倍数`() {
        // Dart `wallpaperOverflowDragExtent`（:54-70）。实测反例：
        // 基础：fitted = 4000*0.8 x 3000*0.8 = 3200x2400 -> 水平溢出 2120、垂直 0
        assertEquals(
            2120.0,
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = 1080,
                viewportHeight = 2400,
                imageWidth = 4000,
                imageHeight = 3000,
                horizontal = true,
                scale = 1.0,
            ),
            1e-9,
        )
        // 放大 2 倍：s*封面尺寸 − 视口 = 6400-1080 = 5320
        // （若误写成「基础溢出 × 2」会得到 4240，拖动就会比手指快）
        assertEquals(
            5320.0,
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = 1080,
                viewportHeight = 2400,
                imageWidth = 4000,
                imageHeight = 3000,
                horizontal = true,
                scale = 2.0,
            ),
            1e-9,
        )
        // 垂直方向：cover 已铺满，1 倍不溢出；2 倍溢出 4800-2400 = 2400
        assertEquals(
            0.0,
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = 1080,
                viewportHeight = 2400,
                imageWidth = 4000,
                imageHeight = 3000,
                horizontal = false,
                scale = 1.0,
            ),
            0.0,
        )
        assertEquals(
            2400.0,
            SettingsWallpaperPositionPage.overflowExtent(
                viewportWidth = 1080,
                viewportHeight = 2400,
                imageWidth = 4000,
                imageHeight = 3000,
                horizontal = false,
                scale = 2.0,
            ),
            1e-9,
        )
    }

    // ------------------------------------------------------------ 拖动方向

    @Test
    fun `向右拖对齐值减小，向左拖增大`() {
        // Dart `next = previous - 2 * dragDelta / overflow`（:94）
        assertEquals(
            -0.5,
            SettingsWallpaperPositionPage.alignAfterDrag(
                previousAlign = 0.0,
                dragDelta = 250.0,
                overflowExtent = 1000.0,
            ),
            1e-9,
        )
        assertEquals(
            0.5,
            SettingsWallpaperPositionPage.alignAfterDrag(
                previousAlign = 0.0,
                dragDelta = -250.0,
                overflowExtent = 1000.0,
            ),
            1e-9,
        )
    }

    @Test
    fun `拖到边界夹住，不越界`() {
        assertEquals(
            1.0,
            SettingsWallpaperPositionPage.alignAfterDrag(
                previousAlign = 0.9,
                dragDelta = -500.0,
                overflowExtent = 1000.0,
            ),
            0.0,
        )
        assertEquals(
            -1.0,
            SettingsWallpaperPositionPage.alignAfterDrag(
                previousAlign = -0.9,
                dragDelta = 500.0,
                overflowExtent = 1000.0,
            ),
            0.0,
        )
    }

    @Test
    fun `该轴不溢出时拖动归零`() {
        // Dart：`overflowExtent <= 0` 时直接返回 0（:91-93）——
        // 竖屏壁纸的垂直方向在 1 倍下不溢出，拖也不会动。
        assertEquals(
            0.0,
            SettingsWallpaperPositionPage.alignAfterDrag(
                previousAlign = 0.7,
                dragDelta = -500.0,
                overflowExtent = 0.0,
            ),
            0.0,
        )
        assertEquals(
            0.0,
            SettingsWallpaperPositionPage.alignAfterDrag(
                previousAlign = 0.7,
                dragDelta = 500.0,
                overflowExtent = -10.0,
            ),
            0.0,
        )
    }

    @Test
    fun `捏合倍率按增量累乘并夹住`() {
        // Compose `transformable` 的 zoomChange 是相对上一次事件的增量；
        // Dart 的 details.scale 是手势累计值，两者在「乘当前值」后等价（:162-164 / :743-746）。
        assertEquals(1.8, SettingsWallpaperPositionPage.scaleAfterPinch(1.5, 1.2), 1e-9)
        assertEquals(4.0, SettingsWallpaperPositionPage.scaleAfterPinch(2.0, 3.0), 0.0)
        assertEquals(1.0, SettingsWallpaperPositionPage.scaleAfterPinch(1.0, 0.5), 0.0)
    }

    // ------------------------------------------------------------ 写回

    @Test
    fun `完成时写路径与三个取景值`() {
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/current.jpg",
            homePageWallpaperAlignX = 0.25,
            homePageWallpaperAlignY = -0.5,
            homePageWallpaperScale = 1.5,
        )
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = current,
            path = "/w/current.jpg",
            alignX = 0.75,
            alignY = -0.25,
            scale = 3.0,
            usedAtMs = 1_000L,
        ) ?: throw AssertionError("有路径时必须返回新模型")
        assertEquals("/w/current.jpg", next.homePageWallpaperPath)
        assertEquals(0.75, next.homePageWallpaperAlignX, 0.0)
        assertEquals(-0.25, next.homePageWallpaperAlignY, 0.0)
        assertEquals(3.0, next.homePageWallpaperScale, 0.0)
    }

    @Test
    fun `写回前再夹一次，越界值不会落盘`() {
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = TimetableSettingsModel(homePageWallpaperPath = "/w/current.jpg"),
            path = "/w/current.jpg",
            alignX = 5.0,
            alignY = -5.0,
            scale = 99.0,
            usedAtMs = 1L,
        ) ?: throw AssertionError("有路径时必须返回新模型")
        assertEquals(1.0, next.homePageWallpaperAlignX, 0.0)
        assertEquals(-1.0, next.homePageWallpaperAlignY, 0.0)
        assertEquals(4.0, next.homePageWallpaperScale, 0.0)
    }

    @Test
    fun `没有路径时不写任何设置`() {
        // Dart：空路径根本进不了取景页；这里兜底返 null，调用方直接返回。
        val current = TimetableSettingsModel(homePageWallpaperPath = null)
        assertNull(
            SettingsWallpaperPositionPage.settingsAfterConfirm(
                current, null, 0.5, 0.5, 2.0, usedAtMs = 1L,
            ),
        )
        assertNull(
            SettingsWallpaperPositionPage.settingsAfterConfirm(
                current, "   ", 0.5, 0.5, 2.0, usedAtMs = 1L,
            ),
        )
    }

    @Test
    fun `最近使用里这张图更新为新取景并置顶，不产生重复条目`() {
        // Dart 确认后 `remembered = [previous, new]`（:1069-1087）；同一 key 去重后
        // 留下的就是新取景，所以一次 push 与批量记等价（wallpaper_history.dart）。
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/w/current.jpg",
            wallpaperHistory = listOf(
                WallpaperHistoryRowModel(
                    key = "/w/current.jpg",
                    alignX = 0.25,
                    alignY = 0.25,
                    scale = 1.5,
                    usedAt = 100L,
                ),
                WallpaperHistoryRowModel(key = "/w/a.jpg", usedAt = 90L),
                WallpaperHistoryRowModel(key = "/w/b.jpg", usedAt = 80L),
            ),
        )
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = current,
            path = "/w/current.jpg",
            alignX = -0.5,
            alignY = 0.5,
            scale = 2.0,
            usedAtMs = 999L,
        ) ?: throw AssertionError("有路径时必须返回新模型")

        assertEquals(listOf("/w/current.jpg", "/w/a.jpg", "/w/b.jpg"), next.wallpaperHistory.map { it.key })
        val entry = next.wallpaperHistory.first()
        assertEquals(-0.5, entry.alignX, 0.0)
        assertEquals(0.5, entry.alignY, 0.0)
        assertEquals(2.0, entry.scale, 0.0)
        assertEquals(999L, entry.usedAt)
        assertEquals(
            "同一张图不允许在历史里出现两条",
            1,
            next.wallpaperHistory.count { it.key == "/w/current.jpg" },
        )
    }

    @Test
    fun `历史满时补记当前图会在上限处截断`() {
        val full = (1..10).map { i ->
            WallpaperHistoryRowModel(key = "/w/$i.jpg", usedAt = i.toLong())
        }
        val next = SettingsWallpaperPositionPage.settingsAfterConfirm(
            current = TimetableSettingsModel(
                homePageWallpaperPath = "/w/current.jpg",
                wallpaperHistory = full,
            ),
            path = "/w/current.jpg",
            alignX = 0.0,
            alignY = 0.0,
            scale = 1.0,
            usedAtMs = 500L,
        ) ?: throw AssertionError("有路径时必须返回新模型")

        assertEquals(10, next.wallpaperHistory.size)
        assertEquals("/w/current.jpg", next.wallpaperHistory.first().key)
        assertTrue(
            "最旧的一条（列表尾部 = usedAt 最小的 /w/10.jpg）被挤出；" +
                "文件回收是接线层的活，不在纯函数里",
            next.wallpaperHistory.none { it.key == "/w/10.jpg" },
        )
    }
}
