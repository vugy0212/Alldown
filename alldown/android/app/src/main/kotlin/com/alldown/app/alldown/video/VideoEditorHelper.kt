package com.alldown.app.alldown.video

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.effect.Crop
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min

object VideoEditorHelper {

    private const val TAG = "VideoEditorHelper"

    /**
     * Hardware-accelerated Video Crop, Zoom, Pan & Trim using Jetpack Media3 Transformer.
     * Supports aspect ratios: "1:1", "9:16", "16:9", "4:5", "original".
     * [zoom] range: 1.0f to 3.0f
     * [panX], [panY] range: -1.0f to +1.0f
     */
    fun cropAndTrimVideo(
        context: Context,
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        cropRatio: String,
        zoom: Float = 1.0f,
        panX: Float = 0.0f,
        panY: Float = 0.0f,
        callback: (Boolean, String?) -> Unit
    ) {
        val mainHandler = Handler(Looper.getMainLooper())

        try {
            Log.d(TAG, "cropAndTrimVideo: input=$inputPath, output=$outputPath, startMs=$startMs, endMs=$endMs, ratio=$cropRatio, zoom=$zoom, panX=$panX, panY=$panY")

            val inFile = File(inputPath)
            if (!inFile.exists()) {
                val err = "Input video file does not exist: $inputPath"
                Log.e(TAG, err)
                mainHandler.post { callback(false, err) }
                return
            }

            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            if (outFile.exists()) outFile.delete()

            val clippingConfiguration = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(startMs)
                .setEndPositionMs(endMs)
                .build()

            val mediaItem = MediaItem.Builder()
                .setUri(Uri.fromFile(inFile))
                .setClippingConfiguration(clippingConfiguration)
                .build()

            val effectsList = mutableListOf<Effect>()
            val safeZoom = zoom.coerceIn(1.0f, 4.0f)
            val safePanX = panX.coerceIn(-1.0f, 1.0f)
            val safePanY = panY.coerceIn(-1.0f, 1.0f)

            val needsCrop = cropRatio != "original" || safeZoom > 1.01f || safePanX != 0f || safePanY != 0f

            if (needsCrop) {
                val targetRatio = when (cropRatio) {
                    "1:1" -> 1.0f
                    "9:16" -> 9.0f / 16.0f
                    "16:9" -> 16.0f / 9.0f
                    "4:5" -> 4.0f / 5.0f
                    else -> null
                }

                val retriever = MediaMetadataRetriever()
                var origW = 1920f
                var origH = 1080f
                try {
                    retriever.setDataSource(inputPath)
                    val rawW = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloat() ?: 1920f
                    val rawH = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloat() ?: 1080f
                    val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
                    origW = if (rotation == 90 || rotation == 270) rawH else rawW
                    origH = if (rotation == 90 || rotation == 270) rawW else rawH
                } finally {
                    try {
                        retriever.release()
                    } catch (_: Exception) {}
                }

                val origRatio = origW / origH
                var visibleFracX = 1.0f
                var visibleFracY = 1.0f

                if (targetRatio != null) {
                    if (origRatio > targetRatio) {
                        visibleFracX = targetRatio / origRatio
                        visibleFracY = 1.0f
                    } else {
                        visibleFracX = 1.0f
                        visibleFracY = origRatio / targetRatio
                    }
                }

                val windowHalfW = (visibleFracX / safeZoom).coerceIn(0.05f, 1.0f)
                val windowHalfH = (visibleFracY / safeZoom).coerceIn(0.05f, 1.0f)

                val maxPanX = (1.0f - windowHalfW).coerceAtLeast(0f)
                val maxPanY = (1.0f - windowHalfH).coerceAtLeast(0f)

                val centerX = (safePanX * maxPanX).coerceIn(-maxPanX, maxPanX)
                val centerY = (safePanY * maxPanY).coerceIn(-maxPanY, maxPanY)

                val left = (centerX - windowHalfW).coerceIn(-1.0f, 1.0f)
                val right = (centerX + windowHalfW).coerceIn(-1.0f, 1.0f)
                val bottom = (centerY - windowHalfH).coerceIn(-1.0f, 1.0f)
                val top = (centerY + windowHalfH).coerceIn(-1.0f, 1.0f)

                effectsList.add(Crop(left, right, bottom, top))
            }

            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setEffects(Effects(emptyList(), effectsList))
                .build()

            val transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        Log.i(TAG, "Transformer export completed successfully -> $outputPath")
                        // Immediately register file in Samsung/Android Gallery MediaStore
                        MediaScannerConnection.scanFile(context, arrayOf(outputPath), arrayOf("video/mp4"), null)
                        mainHandler.post { callback(true, null) }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        Log.e(TAG, "Transformer export error: ${exportException.message}", exportException)
                        mainHandler.post { callback(false, exportException.message) }
                    }
                })
                .build()

            transformer.start(editedMediaItem, outputPath)
        } catch (e: Exception) {
            Log.e(TAG, "Exception during cropAndTrimVideo setup: ${e.message}", e)
            mainHandler.post { callback(false, e.message) }
        }
    }

    /**
     * Hardware-accelerated Audio Extraction & Trim from any video file using Jetpack Media3 Transformer.
     * Strips video track (removeVideo=true) and outputs pristine audio (.m4a / .mp4 audio) in seconds.
     */
    fun extractAndTrimAudio(
        context: Context,
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        callback: (Boolean, String?) -> Unit
    ) {
        val mainHandler = Handler(Looper.getMainLooper())

        try {
            Log.d(TAG, "extractAndTrimAudio: input=$inputPath, output=$outputPath, startMs=$startMs, endMs=$endMs")

            val inFile = File(inputPath)
            if (!inFile.exists()) {
                val err = "Input media file does not exist: $inputPath"
                Log.e(TAG, err)
                mainHandler.post { callback(false, err) }
                return
            }

            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            if (outFile.exists()) outFile.delete()

            val clippingConfiguration = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(startMs)
                .setEndPositionMs(endMs)
                .build()

            val mediaItem = MediaItem.Builder()
                .setUri(Uri.fromFile(inFile))
                .setClippingConfiguration(clippingConfiguration)
                .build()

            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setRemoveVideo(true)
                .build()

            val transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        Log.i(TAG, "Audio extraction completed successfully -> $outputPath")
                        MediaScannerConnection.scanFile(context, arrayOf(outputPath), arrayOf("audio/mp4", "audio/m4a"), null)
                        mainHandler.post { callback(true, null) }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        Log.e(TAG, "Audio extraction error: ${exportException.message}", exportException)
                        mainHandler.post { callback(false, exportException.message) }
                    }
                })
                .build()

            transformer.start(editedMediaItem, outputPath)
        } catch (e: Exception) {
            Log.e(TAG, "Exception during extractAndTrimAudio setup: ${e.message}", e)
            mainHandler.post { callback(false, e.message) }
        }
    }

    /**
     * Converts a selected video segment into an animated GIF (.gif) with optional crop, zoom & pan.
     * Uses Floyd-Steinberg dithering and adaptive palette for true HD quality.
     */
    fun createGif(
        context: Context,
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        cropRatio: String,
        zoom: Float = 1.0f,
        panX: Float = 0.0f,
        panY: Float = 0.0f,
        fps: Int = 10,
        maxWidth: Int = 420,
        callback: (Boolean, String?) -> Unit
    ) {
        val mainHandler = Handler(Looper.getMainLooper())

        Thread {
            val retriever = MediaMetadataRetriever()
            var fos: FileOutputStream? = null
            try {
                Log.d(TAG, "createGif: input=$inputPath, output=$outputPath, startMs=$startMs, endMs=$endMs, fps=$fps")

                val inFile = File(inputPath)
                if (!inFile.exists()) {
                    val err = "Input video file does not exist: $inputPath"
                    Log.e(TAG, err)
                    mainHandler.post { callback(false, err) }
                    return@Thread
                }

                val outFile = File(outputPath)
                outFile.parentFile?.mkdirs()
                if (outFile.exists()) outFile.delete()

                retriever.setDataSource(inputPath)
                fos = FileOutputStream(outFile)

                val encoder = AnimatedGifEncoder()
                val safeFps = fps.coerceIn(5, 15)
                val frameDelayMs = 1000 / safeFps
                encoder.setDelay(frameDelayMs)
                encoder.setRepeat(0) // Infinite loop
                encoder.start(fos)

                val targetRatio = when (cropRatio) {
                    "1:1" -> 1.0f
                    "9:16" -> 9.0f / 16.0f
                    "16:9" -> 16.0f / 9.0f
                    "4:5" -> 4.0f / 5.0f
                    else -> null
                }

                val stepMs = frameDelayMs.toLong()
                var currentMs = startMs

                while (currentMs <= endMs) {
                    val frameUs = currentMs * 1000L
                    val rawFrame = retriever.getFrameAtTime(frameUs, MediaMetadataRetriever.OPTION_CLOSEST)
                        ?: retriever.getFrameAtTime(frameUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)

                    if (rawFrame != null) {
                        val processed = processFrameForGif(rawFrame, targetRatio, zoom, panX, panY, maxWidth)
                        encoder.addFrame(processed)
                        if (processed != rawFrame) {
                            processed.recycle()
                        }
                        rawFrame.recycle()
                    }
                    currentMs += stepMs
                }

                encoder.finish()
                Log.i(TAG, "createGif: Successfully generated GIF -> $outputPath")

                // Immediately index into Android/Samsung Gallery
                MediaScannerConnection.scanFile(context, arrayOf(outputPath), arrayOf("image/gif"), null)

                mainHandler.post { callback(true, null) }
            } catch (e: Exception) {
                Log.e(TAG, "Exception during createGif: ${e.message}", e)
                mainHandler.post { callback(false, e.message) }
            } finally {
                try {
                    fos?.close()
                } catch (e: Exception) {}
                try {
                    retriever.release()
                } catch (e: Exception) {}
            }
        }.start()
    }

    private fun processFrameForGif(
        src: Bitmap,
        targetRatio: Float?,
        zoom: Float,
        panX: Float,
        panY: Float,
        targetMaxWidth: Int = 420
    ): Bitmap {
        var bmp = src

        val srcW = src.width.toFloat()
        val srcH = src.height.toFloat()
        val srcRatio = srcW / srcH

        var baseW = srcW
        var baseH = srcH

        if (targetRatio != null) {
            if (srcRatio > targetRatio) {
                baseH = srcH
                baseW = srcH * targetRatio
            } else {
                baseW = srcW
                baseH = srcW / targetRatio
            }
        }

        // Apply Zoom (1.0f to 4.0f)
        val safeZoom = zoom.coerceIn(1.0f, 4.0f)
        val cropW = (baseW / safeZoom).toInt().coerceIn(10, src.width)
        val cropH = (baseH / safeZoom).toInt().coerceIn(10, src.height)

        // Apply Pan (-1.0f to 1.0f)
        val maxOffsetX = (src.width - cropW).coerceAtLeast(0)
        val maxOffsetY = (src.height - cropH).coerceAtLeast(0)

        val safePanX = panX.coerceIn(-1.0f, 1.0f)
        val safePanY = panY.coerceIn(-1.0f, 1.0f)

        val startX = (((safePanX + 1.0f) / 2.0f) * maxOffsetX).toInt().coerceIn(0, maxOffsetX)
        val startY = (((1.0f - safePanY) / 2.0f) * maxOffsetY).toInt().coerceIn(0, maxOffsetY)

        bmp = Bitmap.createBitmap(src, startX, startY, cropW, cropH)

        // Scale to designated width for chosen quality profile (Low 320px, Medium 420px, High 540px)
        val maxWidth = targetMaxWidth.coerceIn(240, 720)
        if (bmp.width > maxWidth) {
            val scale = maxWidth.toFloat() / bmp.width.toFloat()
            val targetH = (bmp.height * scale).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(bmp, maxWidth, targetH, true)
            if (bmp != src) bmp.recycle()
            bmp = scaled
        }

        return bmp
    }
}
