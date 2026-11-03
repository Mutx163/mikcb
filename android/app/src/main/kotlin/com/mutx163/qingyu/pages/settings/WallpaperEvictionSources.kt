package com.mutx163.qingyu.pages.settings

/**
 * 设置页对共享壁纸淘汰判定的转名。
 *
 * 真源在 `weather/WallpaperEvictionSources.kt`（2026-11-03 下沉：timetable 的档案删除
 * 流程也要用，留在设置页包内会让 timetable 反向依赖整棵设置页）。设置页与既有单测、
 * 以及 `composeP1` 宿主的调用点都按原名使用，因此这里保留一个**只做转名、不含逻辑**
 * 的顶层 typealias，避免跨域改一串 import。
 */
typealias WallpaperEvictionSources = com.mutx163.qingyu.weather.WallpaperEvictionSources
