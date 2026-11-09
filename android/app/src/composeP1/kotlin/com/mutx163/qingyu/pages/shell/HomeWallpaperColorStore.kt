package com.mutx163.qingyu.pages.shell

import android.content.Context

/**
 * 壁纸主色（平均色）的磁盘缓存 —— 冷启动首帧的「最后一道底色」（2026-11-09）。
 *
 * ## 它解决什么
 *
 * 首帧壁纸现在有三层：**主色 → 缩略图 → 高清图**。缩略图要读盘 + 解 96px，极端情况
 * （文件损坏、存储卡住、图片格式不支持）会解不出来；那时如果背景只剩页面底色
 * （浅色主题近白），又会闪一下白。主色不依赖任何解码：上一次成功解过这张图，
 * 下一次冷启动就能直接拿来铺底。
 *
 * ## 键与淘汰
 *
 * 只存**当前这一张**：路径 + 色值一起写，读时路径对不上就当没缓存。用户换壁纸后
 * 新图第一帧会从缩略图现算并回写，旧壁纸的颜色不会被套到新图上；也不需要淘汰列表。
 *
 * ## 线程
 *
 * 读发生在组合线程（SharedPreferences 首次加载后是内存读，和 [HomeInkBandsStore]
 * 同一口径）；写由组合里的副作用协程 `apply()` 异步落盘，不阻塞绘制。
 */
class HomeWallpaperColorStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    /** 读不到 / 路径不是当前这张 / 从没写过 ⇒ null（调用方回落到页面底色）。 */
    fun read(path: String?): Int? {
        if (path.isNullOrEmpty()) return null
        if (prefs.getString(KEY_PATH, null) != path) return null
        if (!prefs.contains(KEY_COLOR)) return null
        return prefs.getInt(KEY_COLOR, 0)
    }

    fun write(path: String, argb: Int) {
        if (path.isEmpty()) return
        prefs.edit()
            .putString(KEY_PATH, path)
            .putInt(KEY_COLOR, argb)
            .apply()
    }

    private companion object {
        const val PREF_NAME = "home_wallpaper_color"
        const val KEY_PATH = "path"
        const val KEY_COLOR = "argb"
    }
}
