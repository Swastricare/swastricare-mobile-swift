package com.swastricare.health.ui.screens.runactivity.components

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint

/**
 * Small dot marker for start/end/current points on the workout map —
 * a compact filled circle with a white border, much smaller than the
 * default Google Maps pin so it doesn't dominate the route.
 */
internal fun createDotMarkerBitmap(fillColor: Int): Bitmap {
    val size = 28
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val cx = size / 2f
    val cy = size / 2f

    // White border
    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    canvas.drawCircle(cx, cy, size / 2f, borderPaint)

    // Colored fill
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = fillColor
        style = Paint.Style.FILL
    }
    canvas.drawCircle(cx, cy, size / 2f - 3f, fillPaint)

    return bitmap
}

internal val MarkerColorStart: Int = android.graphics.Color.parseColor("#22C55E")
internal val MarkerColorEnd: Int = android.graphics.Color.parseColor("#EF4444")
internal val MarkerColorCurrent: Int = android.graphics.Color.parseColor("#00E5FF")
