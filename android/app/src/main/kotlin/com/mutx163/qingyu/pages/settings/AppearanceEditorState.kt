package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.LiquidGlassTuningModel
import com.mutx163.qingyu.app.TimetableHomeViewMode
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel

/**
 * 外观编辑页（沉浸式整页 + 两个底部面板）的**状态契约**。
 *
 * ## 这一层为什么单独存在
 *
 * 本页与设置族其余页长得不一样：它不渲染一份 [SettingsPageSpec] 列表，而是
 * 「真课表页缩尺预览 + 顶部 chrome + 底部两颗圆钮」，两个面板是压在本页上的底部
 * 弹层。所以它需要一份**自己的**状态：面板要读的值、预览要看日还是看周、
 * 壁纸那几根控件各写哪。
 *
 * 真源仍然是 [TimetableSettingsModel]（与设置族共用同一个 `timetable_settings`
 * JSON 与同一套合并写），本文件只是把「这一页要读的键」翻译成一个纯数据对象——
 * 于是「Dart 读哪个键、Kotlin 映射对不对」能在 JVM 单测里逐条断言，不需要真机。
 *
 * ## 与 [MaterialPanelState] 的关系
 *
 * 材质面板那份状态已经在 [SettingsMaterialModel] 里定型（P3-B-1 交付），**不复制
 * 第二份**：[AppearanceEditorState.material] 直接用它，本文件只负责从设置模型推出来。
 *
 * ## 谁拥有这个文件
 *
 * 泳道 `appearance-data`（见 `.agents/compose-phase3/claims/F05-appearance-editor.md`）：
 * 先把键加进 [TimetableSettingsModel]，再把 [AppearanceEditorBridge.toState] 补成
 * 逐键同源。**任何字段语义都要带 Dart 行号**，别凭直觉写默认值。
 */
data class AppearanceEditorState(
    /** 材质面板（材质弹层两个页签共用）。 */
    val material: MaterialPanelState = MaterialPanelState(),
    /** 壁纸面板（壁纸弹层两个页签共用）。 */
    val wallpaper: WallpaperPanelState = WallpaperPanelState(),
    /** 预览看日课表还是周课表；跟首页持久化的视图走（`settings_appearance_editor.dart:203-204`）。 */
    val previewDayView: Boolean = false,
)

/**
 * 壁纸面板的状态。
 *
 * 键与钳制口径照 Dart `lib/models/timetable_settings.dart:559-594`（壁纸本体）与
 * `:746`（随周次滑动），历史条目见 `lib/models/wallpaper_history.dart:20-56`。
 *
 * 与 Dart 一样**只当字符串**：壁纸身份键（[WallpaperHistoryRow.key]）是不透明路径，
 * 内置壁纸前缀、`builtin:` 之类由 ui 层判定，模型层不解释。
 */
data class WallpaperPanelState(
    /** 当前壁纸路径（`homePageWallpaperPath`，null = 没有壁纸）。 */
    val path: String? = null,
    /** 取景水平对齐（`homePageWallpaperAlignX`，-1..1）。 */
    val alignX: Double = 0.0,
    /** 取景垂直对齐（`homePageWallpaperAlignY`，-1..1）。 */
    val alignY: Double = 0.0,
    /** 放大倍数（`homePageWallpaperScale`，[MIN_SCALE]..[MAX_SCALE]）。 */
    val scale: Double = 1.0,
    /** 壁纸模糊（`homePageWallpaperBlurSigma`，[MIN_BLUR]..[MAX_BLUR]）。 */
    val blurSigma: Double = 0.0,
    /** 背景随周次滑动（`homePageBackdropFollowsWeekPager`，:746）。 */
    val followsWeekPager: Boolean = false,
    /** 「最近使用」历史（`wallpaperHistory`，最新在前，上限 10 条）。 */
    val history: List<WallpaperHistoryRow> = emptyList(),
) {
    /** 有没有壁纸——课卡材质那侧的 `hasHomePageBackdrop` 门控就是它。 */
    val hasBackdrop: Boolean get() = !path.isNullOrBlank()

    companion object {
        /** `kWallpaperMinScale`（`lib/utils/home_page_background.dart:586`）。 */
        const val MIN_SCALE = 1.0

        /** `kWallpaperMaxScale`（同文件 :587，注释在 `timetable_screen.dart:1146`）。 */
        const val MAX_SCALE = 4.0

        /** `minHomePageWallpaperBlurSigma`（`timetable_settings.dart:353`）。 */
        const val MIN_BLUR = 0.0

        /** `maxHomePageWallpaperBlurSigma`（`timetable_settings.dart:354`）。 */
        const val MAX_BLUR = 24.0

        /** 历史上限（ARB `homePageWallpaperRecentSubtitle` 里写着这个数）。 */
        const val MAX_HISTORY = 10

        /** 钳制口径照 `clampHomePageWallpaperBlurSigma`（:357-360）。 */
        fun clampBlur(value: Double?): Double =
            (value ?: MIN_BLUR).coerceIn(MIN_BLUR, MAX_BLUR)

        /** 钳制口径与渲染侧共用同一对常量（`home_page_background.dart:568-569`）。 */
        fun clampScale(value: Double?): Double =
            (value ?: MIN_SCALE).coerceIn(MIN_SCALE, MAX_SCALE)
    }
}

/**
 * 「最近使用」里的一条。
 *
 * [key] 是背景身份键（自选图片 = 文件绝对路径）；[alignX] / [alignY] / [scale]
 * 是**用这张图时的取景**——切回历史时要连缩放一起还原，只还原位置等于取景被改了一半
 * （`wallpaper_history.dart:34-36`）。
 */
data class WallpaperHistoryRow(
    val key: String,
    val label: String,
    val alignX: Double = 0.0,
    val alignY: Double = 0.0,
    val scale: Double = 1.0,
    /** 最近一次使用时间（epoch 毫秒）；旧数据缺字段回退 0（排序仍按数组先后）。 */
    val usedAt: Long = 0L,
)

/**
 * 设置模型 → 本页状态。
 *
 * **逐键同源**：下面每一条都注明了 Dart 的读侧出处（`lib/models/timetable_settings.dart`
 * 的字段与 `fromJson` 行号 / `lib/screens/settings/settings_appearance_editor.dart` 的
 * 取值行号）。Dart 那边面板读的是 `_draft`（即设置模型本身），所以这里做的是**搬运**，
 * 不是另立一份口径。
 *
 * 两处「Dart 在渲染侧才夹」的量照原样搬运，由渲染侧收口：
 * - [WallpaperPanelState.scale]：读侧不夹（`:1712-1713`），渲染/编辑侧夹 1~4
 *   （`home_page_background.dart:586-587` 的 `kWallpaperMinScale` / `kWallpaperMaxScale`）；
 * - [WallpaperPanelState.blurSigma]：**读侧就夹**（`:1715-1717` 的
 *   `clampHomePageWallpaperBlurSigma`），所以这里也过一遍 [WallpaperPanelState.clampBlur]。
 */
object AppearanceEditorBridge {

    /**
     * @param model 设置模型（真源）。
     * @return 本页状态；纯函数，不摸盘、不碰 Compose。
     */
    fun toState(model: TimetableSettingsModel): AppearanceEditorState {
        val wallpaper = WallpaperPanelState(
            // `:559` 字段 / `:894` 构造默认 / `:1706` 读侧（null = 没有壁纸）
            path = model.homePageWallpaperPath,
            // `:563` / `:895` / `:1707-1708`（-1..1；读侧不夹）
            alignX = model.homePageWallpaperAlignX,
            // `:567` / `:896` / `:1709-1710`
            alignY = model.homePageWallpaperAlignY,
            // `:580` / `:897` / `:1712-1713`
            scale = model.homePageWallpaperScale,
            // `:587` / `:898` / `:1715-1717`：读侧已按 0~24 收口（`:353-360`），再过一遍保证同口径
            blurSigma = WallpaperPanelState.clampBlur(model.homePageWallpaperBlurSigma),
            // `:746` / `:939` / `:1852-1853`（缺键默认关）
            followsWeekPager = model.homePageBackdropFollowsWeekPager,
            // `:594` / `:899` / `:1718-1720`（历史条目见 `wallpaper_history.dart:20-56`）
            history = model.wallpaperHistory.map { it.toRow() },
        )
        return AppearanceEditorState(
            material = MaterialPanelState(
                // `:655` 字段 / `:925` 构造默认（`:292`）/ `:1773-1774` 读侧
                frostedBlurEnabled = model.frostedBlurEnabled,
                // `:707` / `:935` / `:1829`（Dart 读侧恒 true，见设置模型同名字段的注释）
                homePageHeaderBlurEnabled = model.homePageHeaderBlurEnabled,
                // `:722` / `:937` / `:1837-1846`（读侧已过 sanitize：非三档一律 liquid）
                homeBandGlassMaterial = model.homeBandGlassMaterial,
                // `:671` / `:928` / `:1786-1798`（读侧已与参数键收敛，见 reconcileStoredPreset）
                liquidGlassPreset = model.liquidGlassPreset,
                // `:672` / `:929`；面板读 `_draft.liquidGlassTuning ?? defaults`（`:936`）
                liquidGlassTuning = model.liquidGlassTuning?.toPanelTuning()
                    ?: LiquidGlassTuning.DEFAULTS,
                // `:675` / `:930`；null = 跟随浅色档（面板此时回落到浅色那份，`:1130-1139`）
                liquidGlassTuningDark = model.liquidGlassTuningDark?.toPanelTuning(),
                // `:682` / `:931` / `:1804-1806`（开关语义是「跟随」，显示时取反，`:1106-1109`）
                linkLiquidGlassTuning = model.linkLiquidGlassTuning,
                // `:685` / `:932` / `:1807-1809`
                darkGlassBoostEnabled = model.darkGlassBoostEnabled,
                // `:661` / `:926` / `:1775-1777`
                liquidGlassDockEnabled = model.liquidGlassDockEnabled,
                // `:705` / `:934` / `:1811-1826`
                courseCardGlassPreset = model.courseCardGlassPreset,
                // `:695` / `:933`；null = 出厂卡片档（面板回落到 `CourseGlassTuning.courseCard`）
                courseCardGlassTuning = model.courseCardGlassTuning?.toPanelTuning()
                    ?: LiquidGlassTuning.DEFAULTS,
                // `surface_material.dart:100` 的 `hasHomePageBackdrop`：课卡材质门控要它，
                // 与壁纸面板同一个判据（有壁纸才可能出玻璃）。
                hasHomePageBackdrop = wallpaper.hasBackdrop,
                // `:662` / 读侧 `:1778-1785`（真源在设置模型，不复制第二份）
                courseCardSurfaceStyle = model.courseCardSurfaceStyle.toPanelStyle(),
                // `settings_appearance_editor.dart:203-204`（`_dayPreview`）
                previewDayView = model.timetableHomeViewMode == TimetableHomeViewMode.DAY,
            ),
            wallpaper = wallpaper,
            // 同一条 `_dayPreview`（`:203-204`）：预览看日还是看周，跟首页持久化的视图走。
            previewDayView = model.timetableHomeViewMode == TimetableHomeViewMode.DAY,
        )
    }

    /**
     * 设置模型那份「卡片外观档」→ 面板那份。
     *
     * 两个包各有一个同名枚举（`app.CourseCardSurfaceStyle` 是设置模型的存档枚举，
     * `pages.settings.CourseCardSurfaceStyle` 带 ARB 选项名、给渲染用），**存档值逐字相同**
     * （`solid` / `gaussian` / `refraction`，见 `timetable_settings_extensions.dart:294-350`）。
     * 按 value 映射而不是按 ordinal：以后谁插一档都不会静默错位。
     * `app/` 不能反向依赖 `pages/`（见 `SettingsActionDispatcher` 的类注释），所以这一趟抄写
     * 只能留在本层。
     */
    private fun com.mutx163.qingyu.app.CourseCardSurfaceStyle.toPanelStyle(): CourseCardSurfaceStyle =
        CourseCardSurfaceStyle.entries.firstOrNull { it.value == value } ?: CourseCardSurfaceStyle.SOLID

    /**
     * 设置模型那份参数 → 面板那份参数（同形不同类：模型层不能反向依赖 `pages/`，
     * 见 `app/TimetableSettingsModel.kt` 的 [LiquidGlassTuningModel] 注释）。
     * 这里**只搬八个字段**，不重算、不夹值（模型读侧已收口）。
     */
    private fun LiquidGlassTuningModel.toPanelTuning(): LiquidGlassTuning = LiquidGlassTuning(
        refraction = refraction,
        refractionBand = refractionBand,
        refractionEdgePow = refractionEdgePow,
        dispersion = dispersion,
        rimStrength = rimStrength,
        rimWidth = rimWidth,
        blurSigma = blurSigma,
        tintAlpha = tintAlpha,
    )

    /**
     * 历史条目 → 面板行。
     *
     * [WallpaperHistoryRow.label] 只供调试 / 无障碍读数：Dart 屏上那张缩略图卡下面的字
     * 是**统一文案**（`ARB homePageWallpaperRecentImageLabel`，`settings_recent_wallpaper.dart:135`），
     * 不是文件名；渲染层要上屏仍以 ARB 为准。
     */
    private fun WallpaperHistoryRowModel.toRow(): WallpaperHistoryRow = WallpaperHistoryRow(
        key = key,
        label = SettingsBackdropFlowPage.fileNameOf(key),
        alignX = alignX,
        alignY = alignY,
        scale = scale,
        usedAt = usedAt,
    )
}