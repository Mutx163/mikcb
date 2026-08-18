package com.mutx163.qingyu

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import androidx.core.content.ContextCompat

/**
 * Native launch splash: app icon centered with the app label directly beneath it.
 * Used as the window background until Flutter draws its first frame.
 */
class SplashLayerDrawable(
    private val context: android.content.Context,
    private val label: CharSequence,
) : Drawable() {
    private val resources = context.resources
    private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    }
    private val icon: Drawable? =
        ContextCompat.getDrawable(context, R.mipmap.ic_launcher)

    init {
        applyThemeColors()
        textPaint.textSize = resources.displayMetrics.scaledDensity * 20f
    }

    private fun applyThemeColors() {
        backgroundPaint.color = ContextCompat.getColor(
            context,
            R.color.splash_background,
        )
        textPaint.color = ContextCompat.getColor(
            context,
            R.color.splash_text,
        )
    }

    override fun draw(canvas: Canvas) {
        applyThemeColors()
        canvas.drawRect(bounds, backgroundPaint)

        val density = resources.displayMetrics.density
        val iconSize = (96f * density).toInt()
        val gap = 16f * density
        val textHeight = textPaint.fontMetrics.let { it.descent - it.ascent }
        val blockHeight = iconSize + gap + textHeight
        val blockTop = bounds.exactCenterY() - blockHeight / 2f

        val centerX = bounds.exactCenterX().toInt()
        val iconLeft = centerX - iconSize / 2
        val iconTop = blockTop.toInt()
        icon?.setBounds(iconLeft, iconTop, iconLeft + iconSize, iconTop + iconSize)
        // Clip the icon to a rounded rectangle so it matches AppBootBranding's
        // ClipRRect(22dp) — prevents a square→rounded shape jump between stages.
        val cornerRadius = 22f * density
        val clipPath = Path().apply {
            addRoundRect(
                RectF(iconLeft.toFloat(), iconTop.toFloat(),
                      (iconLeft + iconSize).toFloat(), (iconTop + iconSize).toFloat()),
                cornerRadius, cornerRadius,
                Path.Direction.CW,
            )
        }
        canvas.save()
        canvas.clipPath(clipPath)
        icon?.draw(canvas)
        canvas.restore()

        val textBaseline = iconTop + iconSize + gap - textPaint.fontMetrics.ascent
        canvas.drawText(label.toString(), bounds.exactCenterX(), textBaseline, textPaint)
    }

    override fun setAlpha(alpha: Int) {
        backgroundPaint.alpha = alpha
        textPaint.alpha = alpha
        icon?.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        backgroundPaint.colorFilter = colorFilter
        textPaint.colorFilter = colorFilter
        icon?.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.OPAQUE
}
