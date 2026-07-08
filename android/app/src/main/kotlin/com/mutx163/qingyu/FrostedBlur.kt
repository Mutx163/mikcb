package com.mutx163.qingyu

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.ByteArrayOutputStream

/**
 * Off-screen blur for CFH header snapshots (API 31+ preferred).
 * Prefer [blurRgba] for CFH strips; [blurPng] kept for legacy callers.
 */
object FrostedBlur {
    /** True when [RenderEffect] Gaussian blur is available (API 31+). */
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    /** Flutter rawRgba (R,G,B,A) in, same format out. */
    fun blurRgba(rgba: ByteArray, width: Int, height: Int, radiusPx: Float): ByteArray? {
        if (width <= 0 || height <= 0 || rgba.size < width * height * 4) {
            return null
        }
        val source = rgbaToBitmap(rgba, width, height)
        val blurred = blurBitmap(source, radiusPx) ?: run {
            source.recycle()
            return null
        }
        if (source !== blurred) {
            source.recycle()
        }
        val out = bitmapToRgba(blurred)
        blurred.recycle()
        return out
    }

    private fun rgbaToBitmap(rgba: ByteArray, width: Int, height: Int): Bitmap {
        val pixels = IntArray(width * height)
        var i = 0
        var j = 0
        while (i < width * height) {
            val r = rgba[j].toInt() and 0xff
            val g = rgba[j + 1].toInt() and 0xff
            val b = rgba[j + 2].toInt() and 0xff
            val a = rgba[j + 3].toInt() and 0xff
            pixels[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
            i++
            j += 4
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bitmap
    }

    private fun bitmapToRgba(bitmap: Bitmap): ByteArray {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        val rgba = ByteArray(w * h * 4)
        var i = 0
        var j = 0
        while (i < w * h) {
            val p = pixels[i]
            rgba[j] = (p shr 16 and 0xff).toByte()
            rgba[j + 1] = (p shr 8 and 0xff).toByte()
            rgba[j + 2] = (p and 0xff).toByte()
            rgba[j + 3] = (p shr 24 and 0xff).toByte()
            i++
            j += 4
        }
        return rgba
    }

    fun blurPng(pngBytes: ByteArray, radiusPx: Float): ByteArray? {
        val source = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size) ?: return null
        val blurred = blurBitmap(source, radiusPx) ?: run {
            source.recycle()
            return null
        }
        if (source !== blurred) {
            source.recycle()
        }
        val stream = ByteArrayOutputStream()
        blurred.compress(Bitmap.CompressFormat.PNG, 92, stream)
        blurred.recycle()
        return stream.toByteArray()
    }

    private fun blurBitmap(source: Bitmap, radiusPx: Float): Bitmap? {
        val radius = radiusPx.coerceIn(0.5f, 48f)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            tryRenderEffectBlur(source, radius)?.let { return it }
        }
        return stackBlur(source, radius.toInt().coerceIn(1, 32))
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun tryRenderEffectBlur(source: Bitmap, radius: Float): Bitmap? {
        var output: Bitmap? = null
        return try {
            val effect = RenderEffect.createBlurEffect(radius, radius, Shader.TileMode.CLAMP)
            output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            // Paint.setRenderEffect is API 31+; invoke reflectively for older compile SDK stubs.
            Paint::class.java
                .getMethod("setRenderEffect", RenderEffect::class.java)
                .invoke(paint, effect)
            Canvas(output).drawBitmap(source, 0f, 0f, paint)
            output
        } catch (_: Throwable) {
            output?.recycle()
            null
        }
    }

    /** Stack blur fallback — works on software bitmaps without RenderNode/HW canvas. */
    private fun stackBlur(bitmap: Bitmap, radius: Int): Bitmap {
        val r = radius.coerceIn(1, 32)
        val output = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val w = output.width
        val h = output.height
        val pix = IntArray(w * h)
        output.getPixels(pix, 0, w, 0, 0, w, h)

        val div = r + r + 1
        val red = IntArray(w * h)
        val green = IntArray(w * h)
        val blue = IntArray(w * h)

        var yi = 0
        for (y in 0 until h) {
            var sumR = 0
            var sumG = 0
            var sumB = 0
            for (i in -r..r) {
                val p = pix[yi + i.coerceIn(0, w - 1)]
                sumR += p shr 16 and 0xff
                sumG += p shr 8 and 0xff
                sumB += p and 0xff
            }
            for (x in 0 until w) {
                red[yi + x] = sumR / div
                green[yi + x] = sumG / div
                blue[yi + x] = sumB / div
                val p1 = pix[yi + (x + r + 1).coerceAtMost(w - 1)]
                val p2 = pix[yi + (x - r).coerceAtLeast(0)]
                sumR += (p1 shr 16 and 0xff) - (p2 shr 16 and 0xff)
                sumG += (p1 shr 8 and 0xff) - (p2 shr 8 and 0xff)
                sumB += (p1 and 0xff) - (p2 and 0xff)
            }
            yi += w
        }

        for (x in 0 until w) {
            var sumR = 0
            var sumG = 0
            var sumB = 0
            for (i in -r..r) {
                val idx = (i.coerceIn(0, h - 1)) * w + x
                sumR += red[idx]
                sumG += green[idx]
                sumB += blue[idx]
            }
            var yi2 = x
            for (y in 0 until h) {
                pix[yi2] =
                    -0x1000000 or
                        (sumR / div shl 16) or
                        (sumG / div shl 8) or
                        (sumB / div)
                val idx1 = ((y + r + 1).coerceAtMost(h - 1)) * w + x
                val idx2 = ((y - r).coerceAtLeast(0)) * w + x
                sumR += red[idx1] - red[idx2]
                sumG += green[idx1] - green[idx2]
                sumB += blue[idx1] - blue[idx2]
                yi2 += w
            }
        }

        output.setPixels(pix, 0, w, 0, 0, w, h)
        return output
    }
}
