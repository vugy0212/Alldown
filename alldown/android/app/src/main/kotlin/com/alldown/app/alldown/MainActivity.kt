package com.alldown.app.alldown

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import com.alldown.app.alldown.service.DownloadForegroundService
import com.alldown.app.alldown.video.VideoEditorHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.alldown.app/downloader"
    private var sharedUrl: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        sharedUrl?.let { url ->
            methodChannel?.invokeMethod("onUrlShared", url)
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                val extracted = extractUrl(sharedText)
                sharedUrl = extracted ?: sharedText
            }
        }
    }

    private fun extractUrl(text: String): String? {
        val urlPattern = "https?://[^\\s]+".toRegex()
        return urlPattern.find(text)?.value
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedUrl" -> {
                        val current = sharedUrl
                        sharedUrl = null
                        result.success(current)
                    }
                    "startForegroundService" -> {
                        val title = call.argument<String>("title") ?: "Downloading media..."
                        DownloadForegroundService.startService(applicationContext, title)
                        result.success(true)
                    }
                    "updateNotificationProgress" -> {
                        val title = call.argument<String>("title") ?: "Downloading..."
                        val progress = call.argument<Int>("progress") ?: 0
                        val speed = call.argument<String>("speed") ?: ""
                        val eta = call.argument<String>("eta") ?: ""
                        DownloadForegroundService.updateProgress(applicationContext, title, progress, speed, eta)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        DownloadForegroundService.stopService(applicationContext)
                        result.success(true)
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            openFileIntent(path)
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Path is required", null)
                        }
                    }
                    "openFolder" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            openFolderIntent(path)
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Path is required", null)
                        }
                    }
                    "trimVideo" -> {
                        val input = call.argument<String>("inputPath")
                        val output = call.argument<String>("outputPath")
                        val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
                        val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L
                        if (input != null && output != null) {
                            VideoEditorHelper.cropAndTrimVideo(
                                context = applicationContext,
                                inputPath = input,
                                outputPath = output,
                                startMs = startMs,
                                endMs = endMs,
                                cropRatio = "original"
                            ) { success, error ->
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("TRIM_ERROR", error ?: "Failed to trim video", null)
                                }
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing paths", null)
                        }
                    }
                    "cropVideo" -> {
                        val input = call.argument<String>("inputPath")
                        val output = call.argument<String>("outputPath")
                        val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
                        val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L
                        val ratio = call.argument<String>("cropRatio") ?: "original"
                        val zoom = (call.argument<Number>("zoom"))?.toFloat() ?: 1.0f
                        val panX = (call.argument<Number>("panX"))?.toFloat() ?: 0.0f
                        val panY = (call.argument<Number>("panY"))?.toFloat() ?: 0.0f
                        if (input != null && output != null) {
                            VideoEditorHelper.cropAndTrimVideo(
                                context = applicationContext,
                                inputPath = input,
                                outputPath = output,
                                startMs = startMs,
                                endMs = endMs,
                                cropRatio = ratio,
                                zoom = zoom,
                                panX = panX,
                                panY = panY
                            ) { success, error ->
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("CROP_ERROR", error ?: "Crop failed", null)
                                }
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing paths", null)
                        }
                    }
                    "createGif" -> {
                        val input = call.argument<String>("inputPath")
                        val output = call.argument<String>("outputPath")
                        val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
                        val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L
                        val ratio = call.argument<String>("cropRatio") ?: "original"
                        val zoom = (call.argument<Number>("zoom"))?.toFloat() ?: 1.0f
                        val panX = (call.argument<Number>("panX"))?.toFloat() ?: 0.0f
                        val panY = (call.argument<Number>("panY"))?.toFloat() ?: 0.0f
                        val fps = call.argument<Int>("fps") ?: 10
                        if (input != null && output != null) {
                            VideoEditorHelper.createGif(
                                context = applicationContext,
                                inputPath = input,
                                outputPath = output,
                                startMs = startMs,
                                endMs = endMs,
                                cropRatio = ratio,
                                zoom = zoom,
                                panX = panX,
                                panY = panY,
                                fps = fps
                            ) { success, error ->
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("GIF_ERROR", error ?: "GIF creation failed", null)
                                }
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing paths", null)
                        }
                    }
                    "scanMediaFile" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mimeType") ?: "*/*"
                        if (path != null) {
                            android.media.MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(path),
                                arrayOf(mime),
                                null
                            )
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Path is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun openFileIntent(path: String) {
        try {
            val file = File(path)
            if (!file.exists()) return

            val uri = Uri.parse(file.absolutePath)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, if (path.endsWith(".mp3") || path.endsWith(".m4a")) "audio/*" else "video/*")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }

    private fun openFolderIntent(path: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(path), "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }
}
