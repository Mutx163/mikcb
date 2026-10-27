package com.mutx163.qingyu.pages.settings

/**
 * P3-B-1「外观与材质」四页用到的 ARB 文案（`lib/l10n/app_zh.arb`，模板语言 zh）。
 *
 * ## 为什么单独一个文件
 *
 * `SettingsStrings.kt` 是设置族共享件（Lead 与另外三条泳道同时在用），本轮四页
 * 的文案一律追加到本文件，互不踩踏。
 *
 * **逐字抄录，不许改写**：每一条都在 [SettingsAppearanceStringsParityTest] 里与
 * ARB 机械比对，键缺失或值被改写都会红。要改界面文字，先改 ARB（六份同步）+
 * 重新生成 `gen-l10n`，再同步这里。
 *
 * 已在 [SettingsStrings] 里有的键（`appearanceEditorTitle` / `generalSettingsTitle` /
 * `courseCardSurfaceStyle*`）**不在这里重复定义**，避免同一段文案出现两份真源。
 */
object SettingsStringsExt1 {

    // ------------------------------------------------------ 外观编辑页（外壳）

    val cancelAction = ArbText("cancelAction", "取消")
    val appearanceEditorDoneAction = ArbText("appearanceEditorDoneAction", "完成")
    val glassDockTabDay = ArbText("glassDockTabDay", "日课表")
    val glassDockTabWeek = ArbText("glassDockTabWeek", "周课表")
    val appearanceEditorWallpaperAction = ArbText("appearanceEditorWallpaperAction", "调整壁纸")
    val appearanceEditorMaterialAction = ArbText("appearanceEditorMaterialAction", "材质")
    val commonLoadingLabel = ArbText("commonLoadingLabel", "加载中")
    val wallpaperSheetTabPicker = ArbText("wallpaperSheetTabPicker", "壁纸")
    val wallpaperSheetTabSettings = ArbText("wallpaperSheetTabSettings", "设置")

    // ------------------------------------------------- 材质面板 · 通用页（:930-1195）

    val frostedGlassModeLabel = ArbText("frostedGlassModeLabel", "默认材质")
    val frostedGlassModeSolid = ArbText("frostedGlassModeSolid", "实体卡片")
    val frostedGlassModeLiquid = ArbText("frostedGlassModeLiquid", "液态玻璃")
    val frostedGlassModeSolidNotice = ArbText(
        "frostedGlassModeSolidNotice",
        "已关闭全 App 模糊：顶栏与玻璃坞按实体渲染，课程卡片的选择暂不生效",
    )
    val homeBandGlassMaterialLabel = ArbText("homeBandGlassMaterialLabel", "首页顶栏玻璃")
    val homeBandGlassMaterialFollow = ArbText("homeBandGlassMaterialFollow", "跟随默认材质")
    val advancedMaterialTitle = ArbText("advancedMaterialTitle", "高级材质")
    val liquidGlassPresetLabel = ArbText("liquidGlassPresetLabel", "液态玻璃预设")
    val liquidGlassRefractionLabel = ArbText("liquidGlassRefractionLabel", "折射强度")
    val liquidGlassRefractionBandLabel = ArbText("liquidGlassRefractionBandLabel", "作用带宽度")
    val liquidGlassRefractionEdgePowLabel =
        ArbText("liquidGlassRefractionEdgePowLabel", "边缘陡缓")
    val liquidGlassDispersionLabel = ArbText("liquidGlassDispersionLabel", "色散")
    val liquidGlassRimStrengthLabel = ArbText("liquidGlassRimStrengthLabel", "边缘高光")
    val liquidGlassRimWidthLabel = ArbText("liquidGlassRimWidthLabel", "高光带宽")
    val liquidGlassBlurSigmaLabel = ArbText("liquidGlassBlurSigmaLabel", "磨砂强度")
    val liquidGlassTintLabel = ArbText("liquidGlassTintLabel", "染色强度")
    val liquidGlassResetAction = ArbText("liquidGlassResetAction", "恢复默认")
    val liquidGlassResetScopeNotice = ArbText(
        "liquidGlassResetScopeNotice",
        "只恢复液态玻璃的调参，不动整体材质与其他设置",
    )
    val liquidGlassDarkBoostLabel = ArbText("liquidGlassDarkBoostLabel", "深色模式玻璃更暗")
    val liquidGlassDarkBoostSubtitle =
        ArbText("liquidGlassDarkBoostSubtitle", "中性灰底、更模糊、边缘高光更弱")
    val liquidGlassDarkIndependentLabel =
        ArbText("liquidGlassDarkIndependentLabel", "独立设置深色档")
    val liquidGlassDarkIndependentSubtitle =
        ArbText("liquidGlassDarkIndependentSubtitle", "默认沿用浅色档；打开后可单独调一套")
    val liquidGlassScopeDockTitle = ArbText("liquidGlassScopeDockTitle", "玻璃坞导航")
    val liquidGlassScopeDockSubtitle =
        ArbText("liquidGlassScopeDockSubtitle", "底部悬浮药丸与加课圆钮")
    val liquidGlassScopeHomeChromeTitle =
        ArbText("liquidGlassScopeHomeChromeTitle", "首页玻璃带")
    val surfaceMaterialSectionTitle = ArbText("surfaceMaterialSectionTitle", "各表面当前材质")
    val surfaceCourseCard = ArbText("surfaceCourseCard", "课程卡片")

    // 只读地图用的三个状态词（`_surfaceMaterialLabel`，:33-41）
    val materialStateOff = ArbText("materialStateOff", "已关闭")
    val materialStateSolid = ArbText("materialStateSolid", "实体")
    val materialStateFrost = ArbText("materialStateFrost", "高斯模糊")
    val headerBlurStyleInspire = ArbText("headerBlurStyleInspire", "渐进模糊")
    val headerBlurStyleGaussian = ArbText("headerBlurStyleGaussian", "高斯模糊")

    // --------------------------------------------- 材质面板 · 课程卡片页（:1215-1317）

    val courseCardMaterialMasterOffHint = ArbText(
        "courseCardMaterialMasterOffHint",
        "整体材质为实体卡片时按实体渲染，此设置暂不生效",
    )

    // -------------------------------------------------- 壁纸流程（选图 / 设置）

    val homePageWallpaperTitle = ArbText("homePageWallpaperTitle", "背景图片")
    val homePageImageNotSelected = ArbText("homePageImageNotSelected", "未选择")
    val homePagePickImageAction = ArbText("homePagePickImageAction", "选择图片")
    val homePageAdjustPositionAction = ArbText("homePageAdjustPositionAction", "调整位置")
    val homePageClearImageAction = ArbText("homePageClearImageAction", "清除图片")
    val homePageWallpaperFileMissingTitle =
        ArbText("homePageWallpaperFileMissingTitle", "图片文件已丢失")
    val homePageWallpaperFileMissingSubtitle =
        ArbText("homePageWallpaperFileMissingSubtitle", "首页当前显示的是纯色背景。点这里重新选一张")
    val homePageWallpaperFileMissingToast = ArbText(
        "homePageWallpaperFileMissingToast",
        "壁纸文件已丢失，已恢复为纯色背景，请重新选择一张",
    )
    val homePageBackdropFollowsWeekPagerTitle =
        ArbText("homePageBackdropFollowsWeekPagerTitle", "背景随周次滑动")
    val homePageBackdropFollowsWeekPagerSubtitle =
        ArbText("homePageBackdropFollowsWeekPagerSubtitle", "切周时背景与课表一起移动")
    val homePageWallpaperBlurTitle = ArbText("homePageWallpaperBlurTitle", "壁纸模糊")
    val homePageWallpaperBlurOff = ArbText("homePageWallpaperBlurOff", "关闭")
    val bingWallpaperAutoApplyTitle = ArbText("bingWallpaperAutoApplyTitle", "每天自动更换")
    val bingWallpaperAutoApplySubtitle =
        ArbText("bingWallpaperAutoApplySubtitle", "所有课表共用，只换当前这份")
    val bingWallpaperAutoApplyApplying = ArbText("bingWallpaperAutoApplyApplying", "正在换成今天的壁纸")
    val bingWallpaperAutoApplyAlreadyDone =
        ArbText("bingWallpaperAutoApplyAlreadyDone", "今天已经换过啦")
    val bingWallpaperAutoApplyStale =
        ArbText("bingWallpaperAutoApplyStale", "Bing 还没放出今天的图，先用 {date} 那张顶一下")
    val wallpaperHistoryRemoveInUseToast =
        ArbText("wallpaperHistoryRemoveInUseToast", "正在使用这张壁纸，请先换成别的再删除")
    val wallpaperHistoryRemovedToast = ArbText("wallpaperHistoryRemovedToast", "已从最近使用中删除")
    val wallpaperHistoryRemoveUndo = ArbText("wallpaperHistoryRemoveUndo", "撤销")

    // ----------------------------------------------------- 「最近使用」缩略图条

    val homePageWallpaperRecentTitle = ArbText("homePageWallpaperRecentTitle", "最近使用")
    val homePageWallpaperRecentSubtitle =
        ArbText("homePageWallpaperRecentSubtitle", "点按切回，点角标移除，最多保留 10 张")
    val homePageWallpaperRecentImageLabel = ArbText("homePageWallpaperRecentImageLabel", "照片")
    val wallpaperHistoryRemoveBadgeTooltip =
        ArbText("wallpaperHistoryRemoveBadgeTooltip", "从最近使用中移除")
    val wallpaperHistoryRemoveConfirmHint =
        ArbText("wallpaperHistoryRemoveConfirmHint", "将从最近使用中移除，图片文件也会一起删除")
    val deleteAction = ArbText("deleteAction", "删除")

    // ---------------------------------------------------------- Bing 每日壁纸图库

    val bingWallpaperGalleryTitle = ArbText("bingWallpaperGalleryTitle", "Bing 每日壁纸")
    val bingWallpaperGalleryFailed =
        ArbText("bingWallpaperGalleryFailed", "没能取到 Bing 每日壁纸，请检查网络后重试")
    val bingWallpaperGalleryRetry = ArbText("bingWallpaperGalleryRetry", "重试")
    val wallpaperGalleryShowingCached =
        ArbText("wallpaperGalleryShowingCached", "网络不太顺畅，下面显示的是上次加载的图")
    val bingWallpaperDownloadFailed =
        ArbText("bingWallpaperDownloadFailed", "这张壁纸没能下载成功，请稍后再试")
    val bingWallpaperDownloadProgress = ArbText("bingWallpaperDownloadProgress", "正在下载 {percent}")
    val bingWallpaperDownloadStatus = ArbText("bingWallpaperDownloadStatus", "壁纸下载失败 {status}")
    val bingWallpaperDownloadQueued =
        ArbText("bingWallpaperDownloadQueued", "上一张还在下载，这张已排队，马上就好")
    val wallpaperThumbRetryHint = ArbText("wallpaperThumbRetryHint", "轻点重试")

    // 日期标签（`lib/utils/bing_wallpaper_date_label.dart:16-38`）
    val bingWallpaperDateToday = ArbText("bingWallpaperDateToday", "今天")
    val bingWallpaperDateYesterday = ArbText("bingWallpaperDateYesterday", "昨天")
    val bingWallpaperDateMonthDay = ArbText("bingWallpaperDateMonthDay", "{month} 月 {day} 日")
}
