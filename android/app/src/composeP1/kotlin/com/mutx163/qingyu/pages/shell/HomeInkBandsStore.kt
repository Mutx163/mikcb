package com.mutx163.qingyu.pages.shell

import android.content.Context
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel.InkBands

/**
 * 亮度带的磁盘缓存（SharedPreferences）。
 *
 * ## 键与淘汰
 *
 * 键直接用 [wallpaperInkBandsCacheKey] 的结果：壁纸路径 + 解码宽 + 视口 + 取景。
 * 换壁纸 / 改视口 / 调取景都会得到新键，旧值不会被误用；只保留最近 [MAX_ENTRIES] 条，
 * 避免用户反复拖取景把 prefs 撑大。
 *
 * ## 线程
 *
 * 读发生在组合线程（冷启动首帧），SharedPreferences 首次加载后是内存读，开销可接受；
 * 写由测量协程在 IO 线程调用，`apply()` 异步落盘。读写都走同一个 prefs 实例。
 */
class HomeInkBandsStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    /** 读不到 / 坏数据统一返回 null，调用方按「亮度未知」兜底。 */
    fun read(key: String): InkBands? =
        HomeInkBandsCodec.decode(prefs.getString(key, null))

    fun write(key: String, bands: InkBands) {
        val encoded = HomeInkBandsCodec.encode(bands)
        // 编码后读不回来（四项全空 / 全坏值）就别写：否则索引里留一条永远读不到的键。
        if (HomeInkBandsCodec.decode(encoded) == null) return
        val index = prefs.getString(KEY_INDEX, null)
            ?.split('\n')
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
        val next = (listOf(key) + index.filter { it != key }).take(MAX_ENTRIES)
        val editor = prefs.edit().putString(key, encoded)
        for (stale in index.filter { it != key && it !in next }) {
            editor.remove(stale)
        }
        editor.putString(KEY_INDEX, next.joinToString("\n")).apply()
    }

    private companion object {
        const val PREF_NAME = "home_ink_bands"
        const val KEY_INDEX = "__index"
        const val MAX_ENTRIES = 8
    }
}
