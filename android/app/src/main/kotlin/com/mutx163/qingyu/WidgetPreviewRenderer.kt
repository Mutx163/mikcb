package com.mutx163.qingyu

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 把一张桌面卡片「就地渲染」成图片，供设置页做 1:1 预览。
 *
 * 走的是真实卡片同一条路径：同一份 `res/layout/widget_*.xml`、同一段
 * [BaseQingyuWidgetProvider.buildRemoteViews]、同一套尺寸档与配色判断，
 * 最后只是把 RemoteViews 在进程内 inflate 出来画到 Bitmap 上，而不是交给系统贴到桌面。
 *
 * 之所以不是「用 Flutter 重画一份看起来像的」：卡片布局里有渐变/毛玻璃圆角底、
 * 22 档圆角、随格位尺寸变化的字号档、自适应垂直内边距、课程色贯穿等一堆细节，
 * 任何一处手抄都会随时间漂移。复用同一段代码则天然不会走样。
 *
 * 前提（当前代码全部满足）：10 个布局只用 FrameLayout / LinearLayout / TextView /
 * ImageView / ProgressBar，没有 ListView / StackView 这类必须由桌面进程提供
 * RemoteViewsService 适配器的控件——有的话进程内 inflate 出来会是空白。
 */
internal object WidgetPreviewRenderer {

    /**
     * 渲染一张预览图，返回 PNG 字节；类型不认识或布局解析失败时返回 null。
     *
     * 只能在主线程调用：inflate 出来的 View 要在同一线程完成测量/布局/绘制。
     */
    /**
     * 渲染结果。
     *
     * [png] 是**裁剪到卡片可见边界**的图，[widthDp] / [heightDp] 是它对应的物理尺寸。
     *
     * 为什么不直接返回整张格位图：卡片背景（`widget_card`）在 `widget_root` 的
     * 垂直内边距之内，所以它的可见尺寸比格位小一圈（2×2 的格位是 173dp，
     * 卡片背景只有约 155dp 高）。整张格位图四周带透明边，按格位尺寸显示会让
     * 用户拿「格位 173×173」去比对「看起来扁的卡片」，永远对不上。
     * 裁到内容边界后，图就是卡片本身，尺寸数字与肉眼一致。
     */
    class Result(
        val png: ByteArray,
        val widthDp: Float,
        val heightDp: Float,
    )

    fun render(
        context: Context,
        widgetType: String,
        widthDp: Int,
        heightDp: Int,
        nightMode: Boolean,
        languageTag: String?,
    ): Result? {
        val provider = WidgetProviderCatalog.create(widgetType) ?: return null
        if (widthDp <= 0 || heightDp <= 0) return null

        val themed = themedContext(context, nightMode, languageTag)
        val views = try {
            provider.buildPreviewRemoteViews(themed, widthDp, heightDp, nightMode)
        } catch (_: Throwable) {
            return null
        }

        val host = FrameLayout(themed)
        val view: View = try {
            views.apply(themed, host)
        } catch (_: Throwable) {
            return null
        }

        // 桌面给的格位尺寸 → 像素：与 launcher 一致，按密度换算后取整。
        val density = themed.resources.displayMetrics.density
        val widthPx = max(1, (widthDp * density).roundToInt())
        val heightPx = max(1, (heightDp * density).roundToInt())

        return try {
            view.measure(
                View.MeasureSpec.makeMeasureSpec(widthPx, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(heightPx, View.MeasureSpec.EXACTLY),
            )
            view.layout(0, 0, widthPx, heightPx)

            val full = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
            try {
                view.draw(Canvas(full))
                val bounds = contentBounds(full)
                val cardBitmap = Bitmap.createBitmap(bounds[2], bounds[3], Bitmap.Config.ARGB_8888)
                try {
                    Canvas(cardBitmap).drawBitmap(full, -bounds[0].toFloat(), -bounds[1].toFloat(), null)
                    val png = ByteArrayOutputStream()
                    cardBitmap.compress(Bitmap.CompressFormat.PNG, 100, png)
                    Result(
                        png = png.toByteArray(),
                        widthDp = bounds[2] / density,
                        heightDp = bounds[3] / density,
                    )
                } finally {
                    cardBitmap.recycle()
                }
            } finally {
                full.recycle()
            }
        } catch (_: Throwable) {
            null
        }
    }

    /**
     * 扫描非透明像素的包围盒，返回 `[left, top, width, height]`。
     *
     * 卡片背景是带圆角的 shape，四周透明，所以这个盒子就是「卡片本身」。
     * 全透明（理论上不该发生）时退回整张图，保证不返回 0×0。
     */
    private fun contentBounds(bitmap: Bitmap): IntArray {
        val w = bitmap.width
        val h = bitmap.height
        // 逐行取像素：整张一次性 getPixels 要额外开一块 w*h*4 字节的数组，
        // 4×4 卡片（约 1000×1000）就是 4MB，叠在「整张图 + 裁出的卡片图」
        // 之上，单张峰值能到 12MB，低端机容易顶到上限。
        val row = IntArray(w)
        var minX = w
        var maxX = -1
        var minY = h
        var maxY = -1
        for (y in 0 until h) {
            bitmap.getPixels(row, 0, w, 0, y, w, 1)
            for (x in 0 until w) {
                // alpha > 8：避开圆角抗锯齿产生的极淡像素。
                if ((row[x] ushr 24) > 8) {
                    if (x < minX) minX = x
                    if (x > maxX) maxX = x
                    if (y < minY) minY = y
                    if (y > maxY) maxY = y
                }
            }
        }
        if (maxX < 0) return intArrayOf(0, 0, w, h)
        return intArrayOf(minX, minY, maxX - minX + 1, maxY - minY + 1)
    }

    /**
     * 预览用的 Context：明暗与语言按 App 当前档覆盖。
     *
     * 语言也要覆盖——桌面上卡片的文案跟随「系统的应用语言」，而 App 内可以单独
     * 切换语言；不覆盖的话中文界面里会冒出英文卡片。预览要的是「用户在应用里
     * 看到的样子」，所以以 App 为准。
     */
    private fun themedContext(
        context: Context,
        nightMode: Boolean,
        languageTag: String?,
    ): Context {
        val configuration = Configuration(context.resources.configuration)
        configuration.uiMode = (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            if (nightMode) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        if (!languageTag.isNullOrBlank()) {
            val locale = Locale.forLanguageTag(languageTag)
            if (locale.language.isNotEmpty()) {
                configuration.setLocale(locale)
            }
        }
        return context.createConfigurationContext(configuration)
    }
}
