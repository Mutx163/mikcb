package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 鸣谢名单行「首字头像」的派生逻辑（2026-11-10）。
 *
 * 发布版 `support_donor_tile.dart:22-31 / :129-145` 的观感由三件事决定，这里逐条钉住：
 *
 * 1. **同一个昵称永远同色**（不能每次重组换色，否则滚动时头像会闪）；
 * 2. **不透明**（玻璃卡上半透明水洗会透出壁纸发黑——Dart 侧注释的原话）；
 * 3. 名字不同要**真的分散**到多个色相（全撞一色等于没做头像）。
 *
 * 另钉两个纯格式化口径：首字（含空名的 `♥` 回落）与右栏日期只留 `yyyy-MM-dd`。
 */
class DonorAvatarColorsTest {

    @Test
    fun `同一个昵称亮暗两档都稳定且不透明`() {
        for (dark in listOf(false, true)) {
            val first = donorAvatarColors("张三", dark = dark)
            val again = donorAvatarColors("张三", dark = dark)
            assertEquals("同一个昵称两次取色必须一致（否则滚动时头像会闪）", first, again)
            assertEquals("头像底色必须不透明", 0xFF, first.backgroundArgb ushr 24)
            assertEquals("头像字色必须不透明", 0xFF, first.inkArgb ushr 24)
        }
    }

    @Test
    fun `亮暗两档不是同一组颜色`() {
        val light = donorAvatarColors("张三", dark = false)
        val dark = donorAvatarColors("张三", dark = true)
        assertNotEquals("暗色档必须换一套亮/饱和，否则深色卡上会糊成一块", light, dark)
    }

    @Test
    fun `不同昵称真的分散到多个色相`() {
        val names = listOf("张三", "李四", "王五", "赵六", "钱七", "孙八")
        val backgrounds = names.map { donorAvatarColors(it, dark = false).backgroundArgb }.toSet()
        assertTrue("六个名字至少落入三个色相（发色太挤 = 头像没起作用）：$backgrounds", backgrounds.size >= 3)
    }

    @Test
    fun `首字取昵称第一个字 拉丁字母转大写 空名回落爱心`() {
        assertEquals("张", donorAvatarInitial("张三"))
        assertEquals("A", donorAvatarInitial("alice"))
        assertEquals("♥", donorAvatarInitial(""))
        assertEquals("♥", donorAvatarInitial("   "))
    }

    @Test
    fun `右栏日期只留年月日`() {
        assertEquals("2026-08-30", donorDateLabel("2026-08-30 14:42:22"))
        assertEquals("2026-10-20", donorDateLabel("2026-10-20"))
        assertEquals("", donorDateLabel(null))
        assertEquals("", donorDateLabel("  "))
        assertEquals("2026", donorDateLabel("2026"))
    }
}
