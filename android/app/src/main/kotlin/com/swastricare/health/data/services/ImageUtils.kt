package com.swastricare.health.data.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream

object ImageUtils {

    /**
     * Read image from URI, compress to max [maxWidth] px width, and return base64 string.
     */
    fun compressAndEncode(context: Context, uri: Uri, maxWidth: Int = 800): String? {
        return try {
            val inputStream = context.contentResolver.openInputStream(uri) ?: return null
            val original = BitmapFactory.decodeStream(inputStream)
            inputStream.close()

            val scaled = if (original.width > maxWidth) {
                val ratio = maxWidth.toFloat() / original.width
                val newHeight = (original.height * ratio).toInt()
                Bitmap.createScaledBitmap(original, maxWidth, newHeight, true).also {
                    if (it !== original) original.recycle()
                }
            } else {
                original
            }

            val outputStream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
            val bytes = outputStream.toByteArray()
            scaled.recycle()

            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }
}
