package com.assignment.photo_wall

import android.app.ActivityManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

internal object NativeImageMethods {
    fun decodeDownsampled(arguments: Any?): Map<String, Any> {
        val args = arguments as? Map<*, *>
            ?: throw IllegalArgumentException("Expected image arguments")
        val path = args["path"] as? String
        val bytes = args["bytes"] as? ByteArray
        if ((path == null) == (bytes == null)) {
            throw IllegalArgumentException("Provide exactly one of path or bytes")
        }
        if (path != null && path.isEmpty()) {
            throw IllegalArgumentException("Image path must not be empty")
        }
        if (bytes != null && bytes.isEmpty()) {
            throw IllegalArgumentException("Image bytes must not be empty")
        }
        val maxWidth = args["maxWidth"] as? Int
        val maxHeight = args["maxHeight"] as? Int
        if (maxWidth == null || maxHeight == null || maxWidth <= 0 || maxHeight <= 0) {
            throw IllegalArgumentException("Output dimensions must be positive integers")
        }
        val format = (args["format"] as? String)?.lowercase()
        val compressFormat = when (format) {
            "png" -> Bitmap.CompressFormat.PNG
            "jpg", "jpeg" -> Bitmap.CompressFormat.JPEG
            else -> throw IllegalArgumentException("Unsupported output format")
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        decode(path, bytes, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IllegalArgumentException("Invalid or unsupported image")
        }
        var sampleSize = 1
        while (bounds.outWidth.toDouble() / sampleSize > maxWidth * 2.0 ||
            bounds.outHeight.toDouble() / sampleSize > maxHeight * 2.0
        ) {
            sampleSize *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = decode(path, bytes, options)
            ?: throw IllegalArgumentException("Invalid or unsupported image")
        val scale = minOf(
            1.0,
            maxWidth.toDouble() / decoded.width,
            maxHeight.toDouble() / decoded.height,
        )
        val width = maxOf(1, (decoded.width * scale).roundToInt())
        val height = maxOf(1, (decoded.height * scale).roundToInt())
        val output = if (width == decoded.width && height == decoded.height) {
            decoded
        } else {
            Bitmap.createScaledBitmap(decoded, width, height, true)
        }
        try {
            val compressed = ByteArrayOutputStream().use { stream ->
                if (!output.compress(compressFormat, 90, stream)) {
                    throw IllegalStateException("Could not encode image")
                }
                stream.toByteArray()
            }
            return mapOf("width" to width, "height" to height, "bytes" to compressed)
        } finally {
            if (output !== decoded) output.recycle()
            decoded.recycle()
        }
    }

    fun getMemoryInfo(context: Context): Map<String, Any> {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        return mapOf(
            "availMemBytes" to info.availMem,
            "totalMemBytes" to info.totalMem,
            "thresholdBytes" to info.threshold,
            "lowMemory" to info.lowMemory,
        )
    }

    private fun decode(
        path: String?,
        bytes: ByteArray?,
        options: BitmapFactory.Options,
    ): Bitmap? = if (path != null) {
        BitmapFactory.decodeFile(path, options)
    } else {
        BitmapFactory.decodeByteArray(bytes!!, 0, bytes.size, options)
    }
}
