package com.tududi.tududi.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.LruCache
import androidx.glance.ImageProvider

/**
 * The daily-progress arc as a bitmap (Glance cannot draw arcs). The bitmap is a white mask that
 * the widget tints with the theme's primary color, over the vector track `ic_ring_track`, so it
 * follows light/dark and Material You without being re-rendered. Geometry mirrors that vector
 * (24-unit viewport, radius 8.5, stroke 3).
 */
object ProgressRing {
    private const val SIZE_PX = 128
    private const val STEPS = 100

    private val cache = LruCache<Int, Bitmap>(24)

    /** Quantises to whole percents so identical looks share one bitmap. */
    fun step(fraction: Float): Int = (fraction.coerceIn(0f, 1f) * STEPS).toInt()

    fun imageFor(fraction: Float): ImageProvider = ImageProvider(bitmapFor(step(fraction)))

    private fun bitmapFor(step: Int): Bitmap = synchronized(cache) {
        cache.get(step) ?: render(step).also { cache.put(step, it) }
    }

    private fun render(step: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(SIZE_PX, SIZE_PX, Bitmap.Config.ARGB_8888)
        val unit = SIZE_PX / 24f
        val stroke = 3f * unit
        val inset = (12f - 8.5f) * unit
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            color = 0xFFFFFFFF.toInt()
        }
        val sweep = 360f * step / STEPS
        // A full ring is drawn as a circle; a zero sweep would otherwise leave a round-cap dot.
        if (step >= STEPS) {
            Canvas(bitmap).drawCircle(SIZE_PX / 2f, SIZE_PX / 2f, 8.5f * unit, paint)
        } else if (step > 0) {
            Canvas(bitmap).drawArc(RectF(inset, inset, SIZE_PX - inset, SIZE_PX - inset), -90f, sweep, false, paint)
        }
        return bitmap
    }
}
