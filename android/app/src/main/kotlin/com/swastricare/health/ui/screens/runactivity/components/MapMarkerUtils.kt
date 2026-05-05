package com.swastricare.health.ui.screens.runactivity.components

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path

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

/**
 * Small teardrop pin marker for start/end points — keeps the recognizable
 * Google Maps pin silhouette but rendered at roughly half the default size.
 */
internal fun createPinMarkerBitmap(fillColor: Int): Bitmap {
    val width = 36
    val height = 48
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val cx = width / 2f
    val headRadius = width / 2f - 2f
    val headCy = headRadius + 2f

    val pinPath = Path().apply {
        moveTo(cx, height.toFloat() - 2f)
        cubicTo(
            cx - headRadius * 1.4f, headCy + headRadius * 0.2f,
            cx - headRadius, headCy - headRadius * 0.6f,
            cx - headRadius * 0.7f, headCy - headRadius * 0.7f
        )
        cubicTo(
            cx - headRadius * 0.4f, headCy - headRadius,
            cx + headRadius * 0.4f, headCy - headRadius,
            cx + headRadius * 0.7f, headCy - headRadius * 0.7f
        )
        cubicTo(
            cx + headRadius, headCy - headRadius * 0.6f,
            cx + headRadius * 1.4f, headCy + headRadius * 0.2f,
            cx, height.toFloat() - 2f
        )
        close()
    }

    // White outline for contrast
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 3f
    }
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = fillColor
        style = Paint.Style.FILL
    }
    canvas.drawPath(pinPath, fillPaint)
    canvas.drawPath(pinPath, strokePaint)

    // Inner white circle accent
    val innerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    canvas.drawCircle(cx, headCy, headRadius * 0.4f, innerPaint)

    return bitmap
}
