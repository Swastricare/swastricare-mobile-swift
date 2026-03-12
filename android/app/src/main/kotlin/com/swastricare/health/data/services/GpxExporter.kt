package com.swastricare.health.data.services

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.swastricare.health.data.model.RoutePoint
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object GpxExporter {

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    fun exportToGpx(
        context: Context,
        routePoints: List<RoutePoint>,
        activityType: String,
        activityName: String = "$activityType Workout"
    ): File? {
        if (routePoints.size < 2) return null

        val gpxContent = buildString {
            appendLine("""<?xml version="1.0" encoding="UTF-8"?>""")
            appendLine("""<gpx version="1.1" creator="SwastriCare" xmlns="http://www.topografix.com/GPX/1/1">""")
            appendLine("  <metadata>")
            appendLine("    <name>${escapeXml(activityName)}</name>")
            appendLine("    <time>${isoFormat.format(Date(routePoints.first().timestamp))}</time>")
            appendLine("  </metadata>")
            appendLine("  <trk>")
            appendLine("    <name>${escapeXml(activityName)}</name>")
            appendLine("    <type>${escapeXml(activityType)}</type>")
            appendLine("    <trkseg>")
            for (point in routePoints) {
                append("      <trkpt lat=\"${point.latitude}\" lon=\"${point.longitude}\">")
                if (point.altitude != 0.0) append("<ele>${point.altitude}</ele>")
                append("<time>${isoFormat.format(Date(point.timestamp))}</time>")
                appendLine("</trkpt>")
            }
            appendLine("    </trkseg>")
            appendLine("  </trk>")
            appendLine("</gpx>")
        }

        val fileName = "swastricare_${activityType.lowercase()}_${System.currentTimeMillis()}.gpx"
        val file = File(context.cacheDir, fileName)
        file.writeText(gpxContent)
        return file
    }

    fun shareGpxFile(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/gpx+xml"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Export GPX"))
    }

    private fun escapeXml(text: String): String =
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}
