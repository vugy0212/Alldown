package com.alldown.app.alldown.video

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
            val inFile = File(inputPath)
            if (!inFile.exists()) {
                mainHandler.post { callback(false, "Input file does not exist") }
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
                retriever.setDataSource(inputPath)
                val rawW = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloat() ?: 1920f
                val rawH = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloat() ?: 1080f
                val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
                val origW = if (rotation == 90 || rotation == 270) rawH else rawW
                val origH = if (rotation == 90 || rotation == 270) rawW else rawH
                retriever.release()

                val origRatio = origW / origH
                var visibleFractionX = 1.0f
                var visibleFractionY = 1.0f

                if (targetRatio != null) {
                    if (origRatio > targetRatio) {
                        visibleFractionX = targetRatio / origRatio
                    } else if (origRatio < targetRatio) {
                        visibleFractionY = origRatio / targetRatio
                    }
                }

                // Apply Zoom
                val halfW = (visibleFractionX / safeZoom).coerceIn(0.1f, 1.0f)
                val halfH = (visibleFractionY / safeZoom).coerceIn(0.1f, 1.0f)

                // Apply Pan (-1.0 to 1.0)
                val maxPanX = (1.0f - halfW).coerceAtLeast(0f)
                val maxPanY = (1.0f - halfH).coerceAtLeast(0f)
                val centerX = (safePanX * maxPanX).coerceIn(-maxPanX, maxPanX)
                val centerY = (safePanY * maxPanY).coerceIn(-maxPanY, maxPanY)

                val left = (centerX - halfW).coerceIn(-1.0f, 1.0f)
                val right = (centerX + halfW).coerceIn(-1.0f, 1.0f)
                val bottom = (centerY - halfH).coerceIn(-1.0f, 1.0f)
                val top = (centerY + halfH).coerceIn(-1.0f, 1.0f)

                effectsList.add(Crop(left, right, bottom, top))
            }

            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setEffects(Effects(emptyList(), effectsList))
                .build()

            val transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        mainHandler.post { callback(true, null) }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        mainHandler.post { callback(false, exportException.message) }
                    }
                })
                .build()

            transformer.start(editedMediaItem, outputPath)
        } catch (e: Exception) {
            e.printStackTrace()
            mainHandler.post { callback(false, e.message) }
        }
    }

    /**
     * Converts a selected video segment into an animated GIF (.gif) with optional crop, zoom & pan.
     */
    fun createGif(
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        cropRatio: String,
        zoom: Float = 1.0f,
        panX: Float = 0.0f,
        panY: Float = 0.0f,
        fps: Int = 10,
        callback: (Boolean, String?) -> Unit
    ) {
        val mainHandler = Handler(Looper.getMainLooper())

        Thread {
            val retriever = MediaMetadataRetriever()
            var fos: FileOutputStream? = null
            try {
                val inFile = File(inputPath)
                if (!inFile.exists()) {
                    mainHandler.post { callback(false, "Input file does not exist") }
                    return@Thread
                }

                val outFile = File(outputPath)
                outFile.parentFile?.mkdirs()
                if (outFile.exists()) outFile.delete()

                retriever.setDataSource(inputPath)
                fos = FileOutputStream(outFile)

                val encoder = AnimatedGifEncoder()
                val frameDelayMs = 1000 / fps.coerceIn(5, 20)
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
                    val rawFrame = retriever.getFrameAtTime(frameUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    if (rawFrame != null) {
                        val processed = processFrameForGif(rawFrame, targetRatio, zoom, panX, panY)
                        encoder.addFrame(processed)
                        if (processed != rawFrame) {
                            processed.recycle()
                        }
                        rawFrame.recycle()
                    }
                    currentMs += stepMs
                }

                encoder.finish()
                mainHandler.post { callback(true, null) }
            } catch (e: Exception) {
                e.printStackTrace()
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
        panY: Float
    ): Bitmap {
        var bmp = src

        // 1. Calculate crop dimensions with aspect ratio
        val srcRatio = src.width.toFloat() / src.height.toFloat()
        var baseW = src.width.toFloat()
        var baseH = src.height.toFloat()

        if (targetRatio != null) {
            if (srcRatio > targetRatio) {
                baseH = src.height.toFloat()
                baseW = src.height * targetRatio
            } else {
                baseW = src.width.toFloat()
                baseH = src.width / targetRatio
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

        // 0.0 is center, -1.0 is left/bottom, +1.0 is right/top
        val startX = (((safePanX + 1.0f) / 2.0f) * maxOffsetX).toInt().coerceIn(0, maxOffsetX)
        val startY = (((1.0f - safePanY) / 2.0f) * maxOffsetY).toInt().coerceIn(0, maxOffsetY)

        bmp = Bitmap.createBitmap(src, startX, startY, cropW, cropH)

        // 2. Scale down for optimal GIF performance and filesize (max width 420px)
        val maxWidth = 420
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
