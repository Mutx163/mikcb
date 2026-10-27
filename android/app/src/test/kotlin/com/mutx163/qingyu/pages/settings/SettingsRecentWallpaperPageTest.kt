package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「最近使用」缩略图条（`lib/screens/settings/settings_recent_wallpaper.dart`）结构测试。
 *
 * 这一段在 Flutter 侧是**两个 widget**（`RecentWallpaperSection` + 内部的缩略图卡
 * 与角标），不产生独立页面；落到模型后是 [SettingsRecentWallpaperSection]：
 * 段本身的 spec + 单张卡的状态推导。
 *
 * 期望值来源：Dart 源 + ARB。
 */
class SettingsRecentWallpaperPageTest {

    private fun spec(state: RecentWallpaperState) = SettingsRecentWallpaperSection.spec(state)

    // ---------------------------------------------------------------- 段骨架

    @Test
    fun `标题与说明`() {
        // settings_recent_wallpaper.dart:110-119
        val page = spec(RecentWallpaperState(entries = listOf("a.jpg")))
        assertEquals("最近使用", page.title)
        assertEquals("点按切回，点角标移除，最多保留 10 张", page.rows().first().subtitle)
    }

    @Test
    fun `空列表时整段不渲染`() {
        // :816-818 宿主侧的空判定；模型这一层也没有东西可画
        assertTrue(SettingsRecentWallpaperSection.isEmpty(emptyList()))
        assertFalse(SettingsRecentWallpaperSection.isEmpty(listOf("a.jpg")))
        assertEquals(0, spec(RecentWallpaperState(entries = emptyList())).rows().size)
    }

    // ---------------------------------------------------------------- 单张卡

    @Test
    fun `三个尺寸常量对得上 Dart`() {
        // :12 / :18
        assertEquals(116.0, SettingsRecentWallpaperSection.STRIP_HEIGHT, 0.0)
        assertEquals(26.0, SettingsRecentWallpaperSection.LABEL_HEIGHT, 0.0)
        assertEquals(78.0, SettingsRecentWallpaperSection.CARD_WIDTH, 0.0)
    }

    @Test
    fun `当前那张不可移除，其余可移除`() {
        // :128-137：selected ⇒ removable = false
        assertFalse(
            SettingsRecentWallpaperSection.isRemovable(
                SettingsRecentWallpaperSection.cardState("a.jpg", selectedKey = "a.jpg", armedKey = null),
            ),
        )
        assertTrue(
            SettingsRecentWallpaperSection.isRemovable(
                SettingsRecentWallpaperSection.cardState("b.jpg", selectedKey = "a.jpg", armedKey = null),
            ),
        )
    }

    @Test
    fun `已发起移除的那张：压暗、红边、收起角标`() {
        // :261-355：armed ⇒ 描边用危险色、缩略图压一层 60% 黑、角标收起（removable && !armed）
        val armed = SettingsRecentWallpaperSection.cardState("b.jpg", selectedKey = "a.jpg", armedKey = "b.jpg")
        assertEquals(RecentWallpaperCardEdge.DANGER, armed.edge)
        assertTrue(armed.dimmed)
        assertFalse(armed.showRemoveBadge)
        // 未选中且未发起移除：无描边、不压暗、有角标
        val normal = SettingsRecentWallpaperSection.cardState("b.jpg", selectedKey = "a.jpg", armedKey = null)
        assertEquals(RecentWallpaperCardEdge.NONE, normal.edge)
        assertFalse(normal.dimmed)
        assertTrue(normal.showRemoveBadge)
        // 选中那张：主题色描边、不压暗、没有角标
        val selected = SettingsRecentWallpaperSection.cardState("a.jpg", selectedKey = "a.jpg", armedKey = null)
        assertEquals(RecentWallpaperCardEdge.PRIMARY, selected.edge)
        assertFalse(selected.showRemoveBadge)
    }

    @Test
    fun `压暗用叠加而不是改不透明度`() {
        // :293-307：刻意用「叠一层」而不是 Opacity / ColorFiltered
        assertEquals("0x99000000", SettingsRecentWallpaperSection.DIM_OVERLAY_ARGB)
    }

    @Test
    fun `标签两行定高与字号`() {
        // :313-337：maxLines 2、fontSize 11、height 1.2，选中或 armed 加粗
        assertEquals(2, SettingsRecentWallpaperSection.LABEL_MAX_LINES)
        assertEquals(11.0, SettingsRecentWallpaperSection.LABEL_FONT_SIZE, 0.0)
        assertEquals(1.2, SettingsRecentWallpaperSection.LABEL_HEIGHT_MULTIPLIER, 1e-9)
        assertTrue(SettingsRecentWallpaperSection.labelBold(selected = true, armed = false))
        assertTrue(SettingsRecentWallpaperSection.labelBold(selected = false, armed = true))
        assertFalse(SettingsRecentWallpaperSection.labelBold(selected = false, armed = false))
    }

    @Test
    fun `角标尺寸与提示文案`() {
        // :362-397：22dp 圆角 10、× 15px、半透明黑底 0.45
        assertEquals(22.0, SettingsRecentWallpaperSection.BADGE_SIZE, 0.0)
        assertEquals(15.0, SettingsRecentWallpaperSection.BADGE_GLYPH_SIZE, 0.0)
        assertEquals("从最近使用中移除", SettingsRecentWallpaperSection.BADGE_TOOLTIP.zh)
    }

    // ------------------------------------------------------------ 确认条

    @Test
    fun `确认条的说明与两颗按钮`() {
        // :169-203
        val page = spec(
            RecentWallpaperState(
                entries = listOf("a.jpg", "b.jpg"),
                selectedKey = "a.jpg",
                armedKey = "b.jpg",
            ),
        )
        assertEquals(
            "将从最近使用中移除，图片文件也会一起删除",
            page.flatten().filterIsInstance<SettingsDescription>().single().text,
        )
        assertEquals(
            listOf("backdrop.recent.confirmDelete", "backdrop.recent.cancelDelete"),
            page.group("backdrop.recent.confirmActions").childRowIds(),
        )
        // 删除是危险操作，取消是次级
        assertTrue(page.row("backdrop.recent.confirmDelete").destructive)
        assertFalse(page.row("backdrop.recent.cancelDelete").destructive)
    }

    @Test
    fun `没发起移除时没有确认条`() {
        val page = spec(RecentWallpaperState(entries = listOf("a.jpg"), selectedKey = "a.jpg"))
        assertFalse(page.flattenedIds().contains("backdrop.recent.confirmActions"))
        assertTrue(page.flatten().filterIsInstance<SettingsDescription>().isEmpty())
    }

    @Test
    fun `armed 的键已经不在列表里时自动清空`() {
        // :80-88 didUpdateWidget：不能让一个已经不存在的 key 继续挂着
        assertEquals(
            null,
            SettingsRecentWallpaperSection.normalizeArmedKey(
                armedKey = "gone.jpg",
                entries = listOf("a.jpg"),
            ),
        )
        assertEquals(
            "a.jpg",
            SettingsRecentWallpaperSection.normalizeArmedKey(
                armedKey = "a.jpg",
                entries = listOf("a.jpg"),
            ),
        )
        assertEquals(
            null,
            SettingsRecentWallpaperSection.normalizeArmedKey(armedKey = null, entries = listOf("a.jpg")),
        )
    }

    @Test
    fun `点已发起移除的那张是取消而不是切壁纸`() {
        // :139-154：armed 时单击与长按都改走「取消」
        assertEquals(
            RecentWallpaperTapIntent.DISARM,
            SettingsRecentWallpaperSection.tapIntent(armed = true, removable = true),
        )
        assertEquals(
            RecentWallpaperTapIntent.SELECT,
            SettingsRecentWallpaperSection.tapIntent(armed = false, removable = true),
        )
        assertEquals(
            RecentWallpaperTapIntent.SELECT,
            SettingsRecentWallpaperSection.tapIntent(armed = false, removable = false),
        )
    }

    @Test
    fun `长按语义：可移除就发起移除，不可移除只解释一句`() {
        // :271-273：onLongPress: armed ? onRequestRemove : (removable ? onRequestRemove : onBlockedRemove)
        assertEquals(
            RecentWallpaperLongPressIntent.DISARM,
            SettingsRecentWallpaperSection.longPressIntent(armed = true, removable = true),
        )
        assertEquals(
            RecentWallpaperLongPressIntent.REQUEST_REMOVE,
            SettingsRecentWallpaperSection.longPressIntent(armed = false, removable = true),
        )
        assertEquals(
            RecentWallpaperLongPressIntent.BLOCKED_EXPLAIN,
            SettingsRecentWallpaperSection.longPressIntent(armed = false, removable = false),
        )
    }

    @Test
    fun `最多保留十张`() {
        assertEquals(10, SettingsRecentWallpaperSection.MAX_ENTRIES)
    }
}
