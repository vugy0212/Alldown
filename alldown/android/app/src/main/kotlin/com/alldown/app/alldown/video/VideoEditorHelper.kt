package com.alldown.app.alldown.video

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
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
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

object VideoEditorHelper {

    /**
     * Lossless, high-speed video trimming using Android native MediaExtractor + MediaMuxer.
     * Completes in < 1 second with 0% re-encoding quality degradation.
     */
    fun trimVideo(inputPath: String, outputPath: String, startMs: Long, endMs: Long): Boolean {
        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null

        try {
            val inFile = File(inputPath)
            if (!inFile.exists()) return false

            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            if (outFile.exists()) outFile.delete()

            extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val trackCount = extractor.trackCount
            val indexMap = HashMap<Int, Int>(trackCount)
            var bufferSize = -1

            for (i in 0 until trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/") || mime.startsWith("video/")) {
                    extractor.selectTrack(i)
                    val dstIndex = muxer.addTrack(format)
                    indexMap[i] = dstIndex
                    if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                        val newSize = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                        bufferSize = max(bufferSize, newSize)
                    }
                }
            }

            if (bufferSize < 0) {
                bufferSize = 2 * 1024 * 1024 // 2MB default buffer
            }

            val startUs = startMs * 1000L
            val endUs = endMs * 1000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            muxer.start()
            val dstBuf = ByteBuffer.allocate(bufferSize)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(dstBuf, 0)
                if (bufferInfo.size < 0) break

                val sampleTime = extractor.sampleTime
                if (sampleTime > endUs) break

                bufferInfo.presentationTimeUs = max(0L, sampleTime - startUs)
                bufferInfo.flags = extractor.sampleFlags
                val trackIndex = extractor.sampleTrackIndex
                val dstTrack = indexMap[trackIndex]
                if (dstTrack != null && sampleTime >= startUs) {
                    muxer.writeSampleData(dstTrack, dstBuf, bufferInfo)
                }
                extractor.advance()
            }

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        } finally {
            try {
                muxer?.stop()
                muxer?.release()
            } catch (e: Exception) {}
            try {
                extractor?.release()
            } catch (e: Exception) {}
        }
    }

    /**
     * Hardware-accelerated Video Crop & Trim using Jetpack Media3 Transformer.
     * Supports aspect ratios: "1:1", "9:16", "16:9", "4:5", "original".
     */
    fun cropAndTrimVideo(
        context: Context,
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        cropRatio: String,
        callback: (Boolean, String?) -> Unit
    ) {
        val mainHandler = Handler(Looper.getMainLooper())

        // If no crop needed, perform instant lossless stream copy
        if (cropRatio == "original") {
            Thread {
                val ok = trimVideo(inputPath, outputPath, startMs, endMs)
                mainHandler.post {
                    if (ok) callback(true, null) else callback(false, "Failed to trim video")
                }
            }.start()
            return
        }

        try {
            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            if (outFile.exists()) outFile.delete()

            val clippingConfiguration = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(startMs)
                .setEndPositionMs(endMs)
                .build()

            val mediaItem = MediaItem.Builder()
                .setUri(Uri.fromFile(File(inputPath)))
                .setClippingConfiguration(clippingConfiguration)
                .build()

            // Calculate Crop Effect parameters
            val effectsList = mutableListOf<Effect>()
            val targetRatio = when (cropRatio) {
                "1:1" -> 1.0f
                "9:16" -> 9.0f / 16.0f
                "16:9" -> 16.0f / 9.0f
                "4:5" -> 4.0f / 5.0f
                else -> 1.0f
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
            var left = -1.0f
            var right = 1.0f
            var bottom = -1.0f
            var top = 1.0f

            if (origRatio > targetRatio) {
                // Input is wider than target -> crop left & right
                val visibleFraction = targetRatio / origRatio
                left = -visibleFraction
                right = visibleFraction
            } else if (origRatio < targetRatio) {
                // Input is taller than target -> crop top & bottom
                val visibleFraction = origRatio / targetRatio
                bottom = -visibleFraction
                top = visibleFraction
            }

            effectsList.add(Crop(left, right, bottom, top))

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
     * Converts a selected video segment into an animated GIF (.gif) with optional crop.
     */
    fun createGif(
        inputPath: String,
        outputPath: String,
        startMs: Long,
        endMs: Long,
        cropRatio: String,
        fps: Int = 10,
        callback: (Boolean, String?) -> Unit
    ) {
        val mainHandler = Handler(Looper.getMainLooper())

        Thread {
            val retriever = MediaMetadataRetriever()
            var fos: FileOutputStream? = null
            try {
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

                val durationMs = (endMs - startMs).coerceAtLeast(500L)
                val stepMs = frameDelayMs.toLong()
                var currentMs = startMs

                while (currentMs <= endMs) {
                    val frameUs = currentMs * 1000L
                    val rawFrame = retriever.getFrameAtTime(frameUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    if (rawFrame != null) {
                        val processed = processFrameForGif(rawFrame, targetRatio)
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

    private fun processFrameForGif(src: Bitmap, targetRatio: Float?): Bitmap {
        var bmp = src

        // 1. Crop to aspect ratio if specified
        if (targetRatio != null) {
            val srcRatio = src.width.toFloat() / src.height.toFloat()
            val cropW: Int
            val cropH: Int
            if (srcRatio > targetRatio) {
                cropH = src.height
                cropW = (src.height * targetRatio).toInt().coerceIn(1, src.width)
            } else {
                cropW = src.width
                cropH = (src.width / targetRatio).toInt().coerceIn(1, src.height)
            }
            val startX = ((src.width - cropW) / 2).coerceAtLeast(0)
            val startY = ((src.height - cropH) / 2).coerceAtLeast(0)
            bmp = Bitmap.createBitmap(src, startX, startY, cropW, cropH)
        }

        // 2. Scale down for optimal GIF size (max width 420px)
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

