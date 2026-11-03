package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import kotlin.math.roundToInt

/**
 * 壁纸「拖动取景」页的**模型层**（Dart `lib/widgets/wallpaper_position_picker_sheet.dart`）。
 *
 * ## 这一页在 Dart 里是什么
 *
 * 它不是一个设置列表，而是一整屏的图片取景器（`:123-828`）：
 * * 预览铺满整屏、与首页同一套 `BoxFit.cover` + 对齐 + 缩放，所见即所得；
 * * 单指拖动与双指捏合走**同一个** scale 手势（`:735-767`），拖动位移按「当前倍数下的
 *   真实溢出量」折算，手指与内容 1:1；
 * * 顶部悬浮「退出 / 标题 / 完成」，底部「重置 / 换壁纸」（`:586-673`）；
 * * 「完成」把路径 + `alignX` / `alignY` / `scale` 交回调用方；「退出」交回
 *   `confirmed = false`，调用方**什么都不写**（`:485-507`）。
 *
 * ## 为什么纯逻辑单独一层
 *
 * 夹取、拖动折算、落盘键与「最近使用」的补记都是可 JVM 直测的纯运算；Compose 那一层
 * 只负责手势与绘制（`composeP1/.../pages/settings/WallpaperPositionPickerPage.kt`）。
 * 与 `BingGalleryApplyPlanner` / `SettingsBackdropFlowPage` 同一分工。
 *
 * ## 与 Dart 的逐项对照
 *
 * | Dart | 这里 | 说明 |
 * |---|---|---|
 * | `kWallpaperMinScale` / `kWallpaperMaxScale`（`home_page_background.dart:586-587`） | [MIN_SCALE] / [MAX_SCALE] | 1 / 4；L0 不能依赖 `pages/shell`，故抄一份并在单测里钉死 |
 * | `wallpaperOverflowDragExtent`（`:54-70`） | [overflowExtent] | `s × cover 尺寸 − 视口`，**不是**「基础溢出 × s」 |
 * | `wallpaperAlignAfterDrag`（`:86-96`） | [alignAfterDrag] | `prev − 2 × delta / overflow`，夹 [-1, 1]；该轴不溢出时归 0 |
 * | `_scaleAtGestureStart * details.scale`（`:743-746`） | [scaleAfterPinch] | Compose 的 `zoomChange` 是增量，乘上去即可 |
 * | `Transform.scale(alignment:)` 的几何 | [alignFraction] | Dart 等价于「放大后的溢出 × 对齐比例」 |
 * | `_confirm`（`:497-507`） | [settingsAfterConfirm] | 写路径 + 三个取景值 + 补记「最近使用」 |
 * | `_switchWallpaper`（`:429-465`） | 页面宿主 + [ManagedWallpaperNaming] / `ManagedWallpaperStore` | 就地换图：URI → 受管目录 → 预览，确认时才写设置 |
 * | `onPickNewImage` 返回 null（`:435-437`） | 不写任何设置 | 取消选图 = 当前取景原样保留 |
 * | 百分比 | [scalePercent] | 取景页本身不显示百分比（Dart 也没有），保留给读数/测试 |
 */
object SettingsWallpaperPositionPage {

    // -------------------------------------------------------------- 文案

    /** 页面标题（ARB `wallpaperPositionPickerTitle`）。 */
    val TITLE = SettingsStringsExt1.wallpaperPositionPickerTitle

    /** 顶部「退出」（ARB `wallpaperPositionPickerExit`，`:609`）。 */
    val EXIT = SettingsStringsExt1.wallpaperPositionPickerExit

    /** 顶部「完成」（ARB `wallpaperPositionPickerDone`，`:634`）。 */
    val DONE = SettingsStringsExt1.wallpaperPositionPickerDone

    /** 底部「重置」（ARB `wallpaperPositionPickerResetTooltip`，`:658`）。 */
    val RESET = SettingsStringsExt1.wallpaperPositionPickerReset

    /** 底部「换壁纸」（ARB `wallpaperPositionPickerSwitchWallpaper`，`:663-667`）。 */
    val SWITCH = SettingsStringsExt1.wallpaperPositionPickerSwitch

    // ------------------------------------------------------------ 数值口径

    /** `kWallpaperMinScale`：1 = 刚好铺满（`home_page_background.dart:586`）。 */
    const val MIN_SCALE = 1.0

    /** `kWallpaperMaxScale`：4 = 够看细节（同文件 `:587`）。 */
    const val MAX_SCALE = 4.0

    /** 对齐值下限（Dart `wallpaperAlignAfterDrag` 的 `clamp(-1.0, 1.0)`）。 */
    const val MIN_ALIGN = -1.0

    /** 对齐值上限（同上）。 */
    const val MAX_ALIGN = 1.0

    /**
     * 「调整位置」这一行的页内导航目标（模型 `backdrop.image.adjust`）。
     *
     * 它带点号，是**页内动作 id** 而不是壳的路由串；运行时由壳的
     * `shellPageIdForRoute` 额外映射到取景页（见交付说明里的壳侧 snippet）。
     */
    const val ADJUST_TARGET = "backdrop.image.adjust"

    // ------------------------------------------------------------ 纯函数

    /**
     * 对齐值夹进 [-1, 1]；NaN 按 0（居中）处理。
     *
     * 与 `HomeBackgroundModel.clampAlign` 同口径（本模块的 L0 不编译 `pages/shell`，
     * 所以在单测里把 1 / 4 / ±1 这三个数钉住，防止两处悄悄漂开）。
     */
    fun clampAlign(value: Double): Double =
        if (value.isNaN()) 0.0 else value.coerceIn(MIN_ALIGN, MAX_ALIGN)

    /** 放大倍数夹进 [MIN_SCALE, MAX_SCALE]；NaN 按 1（刚好铺满）处理。 */
    fun clampScale(value: Double): Double =
        if (value.isNaN()) MIN_SCALE else value.coerceIn(MIN_SCALE, MAX_SCALE)

    /**
     * 对齐值 → 0..1 的比例（Dart `(align + 1) / 2`）。
     *
     * 0 = 图片左/上边缘贴住视口，1 = 右/下边缘贴住视口，0.5 = 居中。
     * `HomeBackgroundModel.drawRect` 里同一个换算；单独抽出来是为了能直测。
     */
    fun alignFraction(align: Double): Double = (clampAlign(align) + 1.0) / 2.0

    /** 放大倍数 → 百分比读数（100 = 刚好铺满，400 = 上限）。负/越界先夹再换算。 */
    fun scalePercent(scale: Double): Int = (clampScale(scale) * 100.0).roundToInt()

    /**
     * `BoxFit.cover` 的基准倍率：`max(视口宽/图宽, 视口高/图高)`。
     *
     * 任一维非正时返回 0（不可绘制），调用方据此跳过拖动的溢出计算。
     */
    fun coverScale(
        imageWidth: Int,
        imageHeight: Int,
        viewportWidth: Int,
        viewportHeight: Int,
    ): Double {
        if (imageWidth <= 0 || imageHeight <= 0 || viewportWidth <= 0 || viewportHeight <= 0) {
            return 0.0
        }
        return maxOf(
            viewportWidth.toDouble() / imageWidth,
            viewportHeight.toDouble() / imageHeight,
        )
    }

    /**
     * 以 cover 布局、叠加用户倍数 [scale] 后，图片沿某轴相对视口溢出的像素量。
     *
     * 这个数同时就是「对齐值从 -1 扫到 +1 时内容真正走过的距离」，拖动折算的分母。
     *
     * ⚠️ **不是「基础溢出 × 倍数」**：缩放绕对齐点做，视口那一份不跟着放大，真实溢出是
     * `s × cover 尺寸 − 视口`，比前者更大。分母取小了，放大后拖一点就飞
     * （Dart `:41-53` 的真机口径）。
     *
     * 该轴不溢出（例如竖屏壁纸的垂直方向）时返回 0。
     */
    fun overflowExtent(
        viewportWidth: Int,
        viewportHeight: Int,
        imageWidth: Int,
        imageHeight: Int,
        horizontal: Boolean,
        scale: Double,
    ): Double {
        val base = coverScale(imageWidth, imageHeight, viewportWidth, viewportHeight)
        if (base <= 0.0) return 0.0
        val fitted = (if (horizontal) imageWidth else imageHeight) * base * clampScale(scale)
        val viewport = if (horizontal) viewportWidth else viewportHeight
        return (fitted - viewport).coerceAtLeast(0.0)
    }

    /**
     * 拖动 [dragDelta] 像素之后的对齐值（Dart `wallpaperAlignAfterDrag`，`:86-96`）。
     *
     * 壁纸跟随手指：手指向右（delta > 0）时内容右移、露出图片左侧，所以对齐值**减小**；
     * 向左拖则增大。超出 [-1, 1] 夹住；该轴没有溢出时归 0（Dart 同口径）。
     *
     * [overflowExtent] 必须是**当前倍数下**的溢出量（[overflowExtent] 的返回），
     * 这样「内容跟着手指走」在任意倍数下都是 1:1。
     */
    fun alignAfterDrag(
        previousAlign: Double,
        dragDelta: Double,
        overflowExtent: Double,
    ): Double {
        if (overflowExtent <= 0.0) return 0.0
        val next = previousAlign - 2.0 * dragDelta / overflowExtent
        return clampAlign(next)
    }

    /**
     * 本次手势的倍率变化 → 新的绝对倍数。
     *
     * Dart 用「手势起点倍数 × 本手势累计 scale」（`:162-164`、`:743-746`）；Compose 的
     * `transformable` 给的是**相对上一次事件的增量** `zoomChange`，所以直接乘当前值。
     * 两端都夹进 [MIN_SCALE, MAX_SCALE]，捏到边缘不会越界。
     */
    fun scaleAfterPinch(currentScale: Double, zoomChange: Double): Double =
        clampScale(clampScale(currentScale) * zoomChange)

    /**
     * 「完成」要写回的那份设置（Dart `_openBackdropPositionEditor` 的确认分支，`:1069-1091`）。
     *
     * 写四样：壁纸路径 + 水平/垂直对齐 + 放大倍数；「最近使用」里这张图同时更新为**新取景**
     * （Dart 先记旧条目、再记新条目，同一 key 去重后留下的就是新取景，故这里一次 push
     * 与批量记等价 —— `wallpaper_history.dart` / [pushWallpaperHistory] 的去重语义）。
     *
     * @param path 当前壁纸路径。空/空白返回 null：没有图就没有可取景的东西，调用方
     *   应当原样返回、不写任何设置。
     * @param usedAtMs 「最近使用」里的使用时间（epoch 毫秒）；单测注入固定值。
     */
    fun settingsAfterConfirm(
        current: TimetableSettingsModel,
        path: String?,
        alignX: Double,
        alignY: Double,
        scale: Double,
        usedAtMs: Long = System.currentTimeMillis(),
    ): TimetableSettingsModel? {
        if (path.isNullOrBlank()) return null
        // 「补历史」只有一处实现（[WallpaperHistoryLedger.applyPicked]）：与壁纸面板的
        // 「相册选图直接应用」「切回最近使用」共用同一份去重 / 置顶 / 10 条上限。
        // 本页此前自己 push 了一份，两处规则迟早漂开。
        return WallpaperHistoryLedger.applyPicked(
            current = current,
            path = path,
            alignX = clampAlign(alignX),
            alignY = clampAlign(alignY),
            scale = clampScale(scale),
            usedAt = usedAtMs,
        )?.settings
    }

    /**
     * 一次取景交互结束时，**本次新落盘但没有任何设置引用**的图（Dart
     * `_discardUnreferencedBackdrops`，`settings_home_backdrop_flow.dart:1097-1130`）。
     *
     * 取景页「换壁纸」每选一张就落一份文件；用户连选两张只确认第二张、或选完直接
     * 退出时，前一张/这张就成了没人引用的垃圾。判据是「谁在引用它」，不是「哪张是
     * 新的」：当前壁纸与「最近使用」里的一律不动，只清剩下的。
     *
     * 纯运算（不摸盘）；真删文件由宿主在设置落盘**之后**调用。
     */
    fun unreferencedPicked(
        pickedPaths: Collection<String>,
        settings: TimetableSettingsModel?,
    ): List<String> {
        if (pickedPaths.isEmpty()) return emptyList()
        val referenced = buildSet {
            settings?.homePageWallpaperPath?.takeIf { it.isNotBlank() }?.let(::add)
            settings?.wallpaperHistory?.forEach { row ->
                if (row.key.isNotBlank()) add(row.key)
            }
        }
        return pickedPaths.filter { it.isNotBlank() && it !in referenced }.distinct()
    }
}

/** 一组取景值（对齐 -1..1，倍数 1..4）。 */
data class WallpaperFraming(
    val alignX: Double = 0.0,
    val alignY: Double = 0.0,
    val scale: Double = 1.0,
) {
    companion object {
        /** Dart 的出厂 / 重置档：居中 + 刚好铺满（`:473-483`）。 */
        val DEFAULT = WallpaperFraming()
    }
}

