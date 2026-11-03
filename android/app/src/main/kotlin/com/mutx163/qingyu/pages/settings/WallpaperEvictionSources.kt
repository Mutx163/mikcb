package com.mutx163.qingyu.pages.settings

/**
 * 壁纸淘汰来源判定——真源已下沉共享层
 * [com.mutx163.qingyu.weather.WallpaperEvictionSources]（2026-11-03 跨域引用治理）。
 *
 * 它的两个调用方分属两域：设置域（`BingGalleryApply` 应用壁纸时的淘汰）与课表域
 * （`TimetableProfilesController` 删档案后的独占用图回收）。留在设置域会让课表域
 * 反向 import 设置域，`pages/timetable` 的 L0 编不过；而壁纸纯逻辑的家本来就在
 * 共享 `weather/`（`deletableWallpaperPaths` / `BingWallpaperLedger`）。
 *
 * 本别名让设置域既有调用方（`BingGalleryApply`、composeP1 的 `AppearanceEditorHost`、
 * 各设置测试）一行不改；课表域与新的调用方请直接 import 共享层。
 */
typealias WallpaperEvictionSources =
    com.mutx163.qingyu.weather.WallpaperEvictionSources
