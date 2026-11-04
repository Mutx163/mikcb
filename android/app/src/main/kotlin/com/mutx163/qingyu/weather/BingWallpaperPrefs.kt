package com.mutx163.qingyu.weather

/**
 * Bing 每日壁纸的**设备级** prefs 键（Dart `lib/services/bing_wallpaper_store.dart:11-30`）。
 *
 * 放共享 `weather/` 而不是设置页：台账/开关是设备级存储约定，timetable 的档案删除
 * 流程要读台账 JSON 判「这张图还有没有人在用」，不该为此依赖设置页。设置页的
 * `BingWallpaperStore.PREF_LEDGER` / `PREF_AUTO_APPLY` 仍按原名引用这里。
 */
object BingWallpaperPrefs {
    /** 自动换开关（Dart `bing_wallpaper_store.dart:39`）。 */
    const val AUTO_APPLY = "bing_wallpaper_auto_apply_v1"

    /** 下载台账（JSON 数组，Dart `bing_wallpaper_store.dart:17`）。 */
    const val LEDGER = "bing_wallpaper_v1"
}
