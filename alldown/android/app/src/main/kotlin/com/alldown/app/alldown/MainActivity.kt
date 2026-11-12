package com.alldown.app.alldown

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import com.alldown.app.alldown.service.DownloadForegroundService
import com.alldown.app.alldown.video.VideoEditorHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.net.HttpURLConnection
import java.net.URL
import android.webkit.WebView
import org.json.JSONObject
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.alldown.app/downloader"
    private var sharedUrl: String? = null
    private var methodChannel: MethodChannel? = null
    private var headlessWebView: WebView? = null

    inner class HeadlessWebBridge {
        private var callback: ((Int, String) -> Unit)? = null

        fun setCallback(cb: (Int, String) -> Unit) {
            this.callback = cb
        }

        @android.webkit.JavascriptInterface
        fun postResult(code: Int, body: String) {
            callback?.invoke(code, body)
        }
    }
    private val webBridge = HeadlessWebBridge()

    private fun getOrCreateHeadlessWebView(): WebView {
        if (headlessWebView == null) {
            headlessWebView = WebView(this).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.allowFileAccess = true
                settings.allowContentAccess = true
                settings.allowUniversalAccessFromFileURLs = true
                settings.allowFileAccessFromFileURLs = true
                settings.userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
                webChromeClient = object : android.webkit.WebChromeClient() {
                    override fun onConsoleMessage(cm: android.webkit.ConsoleMessage?): Boolean {
                        android.util.Log.d("AllDownWV", "JS [${cm?.messageLevel()}]: ${cm?.message()}")
                        return true
                    }
                }
                addJavascriptInterface(webBridge, "AllDownBridge")
                loadDataWithBaseURL("https://www.dailymotion.com", "<html><body><h1>AllDown</h1></body></html>", "text/html", "UTF-8", null)
            }
        }
        return headlessWebView!!
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            System.setProperty("java.net.preferIPv4Stack", "true")
            System.setProperty("java.net.preferIPv6Addresses", "false")
            if (CookieHandler.getDefault() == null) {
                CookieHandler.setDefault(CookieManager(null, CookiePolicy.ACCEPT_ALL))
            }
            getOrCreateHeadlessWebView()
        } catch (_: Exception) {}
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
        if (intent?.action == Intent.ACTION_SEND && (intent.type?.startsWith("text/") == true || intent.type == "text/plain")) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                val extracted = extractUrl(sharedText)
                sharedUrl = extracted ?: sharedText
            }
        } else if (intent?.action == Intent.ACTION_VIEW) {
            val dataStr = intent.dataString
            if (!dataStr.isNullOrEmpty()) {
                sharedUrl = dataStr
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
                    "showCompletionNotification" -> {
                        val title = call.argument<String>("title") ?: "Media file saved"
                        DownloadForegroundService.showCompletionNotification(applicationContext, title)
                        result.success(true)
                    }
                    "isWifiConnected" -> {
                        result.success(isWifiOrEthernetConnected())
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
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            val success = installApkIntent(path)
                            result.success(success)
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
                    "extractAudio" -> {
                        val input = call.argument<String>("inputPath")
                        val output = call.argument<String>("outputPath")
                        val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
                        val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L
                        if (input != null && output != null) {
                            VideoEditorHelper.extractAndTrimAudio(
                                context = applicationContext,
                                inputPath = input,
                                outputPath = output,
                                startMs = startMs,
                                endMs = endMs
                            ) { success, error ->
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("AUDIO_EXTRACT_ERROR", error ?: "Failed to extract audio", null)
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
                        val maxWidth = call.argument<Int>("maxWidth") ?: 420
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
                                fps = fps,
                                maxWidth = maxWidth
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
                    "nativeHttpGet" -> {
                        val urlStr = call.argument<String>("url")
                        val headers = call.argument<Map<String, String>>("headers")
                        if (urlStr != null) {
                            thread {
                                try {
                                    android.util.Log.d("AllDownNative", "nativeHttpGet start: $urlStr")
                                    val conn = openFollowRedirectsConnection(urlStr, headers)
                                    val code = conn.responseCode
                                    val inputStream = if (code in 200..299) conn.inputStream else conn.errorStream
                                    val text = inputStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""

                                    val resHeaders = HashMap<String, String>()
                                    conn.headerFields.forEach { (k, vList) ->
                                        if (k != null && vList.isNotEmpty()) {
                                            resHeaders[k] = vList.joinToString(", ")
                                        }
                                    }

                                    android.util.Log.d("AllDownNative", "nativeHttpGet status: $code for $urlStr (error-code: ${resHeaders["X-Error-Code"]})")
                                    if (code !in 200..299) {
                                        android.util.Log.e("AllDownNative", "nativeHttpGet error response: headers=$resHeaders body=$text")
                                    }

                                    val resultMap = mapOf(
                                        "statusCode" to code,
                                        "body" to text,
                                        "headers" to resHeaders
                                    )
                                    runOnUiThread { result.success(resultMap) }
                                } catch (e: Exception) {
                                    android.util.Log.e("AllDownNative", "nativeHttpGet exception: ${e.message}", e)
                                    runOnUiThread { result.error("NATIVE_HTTP_ERROR", e.message, null) }
                                }
                            }
                        } else {
                            result.error("INVALID_ARGS", "URL is required", null)
                        }
                    }
                    "nativeDownloadFile" -> {
                        val urlStr = call.argument<String>("url")
                        val outputPath = call.argument<String>("outputPath")
                        val headers = call.argument<Map<String, String>>("headers")
                        val append = call.argument<Boolean>("append") ?: false
                        if (urlStr != null && outputPath != null) {
                            thread {
                                try {
                                    android.util.Log.d("AllDownNative", "nativeDownloadFile start: $urlStr -> $outputPath (append=$append)")
                                    val conn = openFollowRedirectsConnection(urlStr, headers)
                                    val code = conn.responseCode
                                    android.util.Log.d("AllDownNative", "nativeDownloadFile status: $code for $urlStr")
                                    if (code in 200..299) {
                                        val outFile = File(outputPath)
                                        outFile.parentFile?.mkdirs()
                                        var bytesWritten = 0L
                                        conn.inputStream.use { input ->
                                            FileOutputStream(outFile, append).use { output ->
                                                val buffer = ByteArray(32768)
                                                var read: Int
                                                while (input.read(buffer).also { read = it } != -1) {
                                                    output.write(buffer, 0, read)
                                                    bytesWritten += read
                                                }
                                                output.flush()
                                            }
                                        }
                                        runOnUiThread {
                                            result.success(mapOf("statusCode" to code, "bytesWritten" to bytesWritten))
                                        }
                                    } else {
                                        android.util.Log.e("AllDownNative", "nativeDownloadFile error HTTP_$code for $urlStr")
                                        runOnUiThread {
                                            result.error("HTTP_$code", "Download failed with HTTP $code", null)
                                        }
                                    }
                                } catch (e: Exception) {
                                    android.util.Log.e("AllDownNative", "nativeDownloadFile exception: ${e.message}", e)
                                    runOnUiThread { result.error("DOWNLOAD_ERROR", e.message, null) }
                                }
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing url or outputPath", null)
                        }
                    }
                    "webViewFetch" -> {
                        val urlStr = call.argument<String>("url")
                        if (urlStr != null) {
                            runOnUiThread {
                                try {
                                    android.util.Log.d("AllDownNative", "webViewFetch start: $urlStr")
                                    val wv = getOrCreateHeadlessWebView()
                                    val escapedUrl = JSONObject.quote(urlStr)
                                    var responded = false

                                    webBridge.setCallback { code, body ->
                                        if (!responded) {
                                            responded = true
                                            android.util.Log.d("AllDownNative", "webViewFetch bridge received: $code, length: ${body.length}")
                                            runOnUiThread {
                                                result.success(mapOf("statusCode" to code, "body" to body))
                                            }
                                        }
                                    }

                                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                                    handler.postDelayed({
                                        if (!responded) {
                                            responded = true
                                            android.util.Log.e("AllDownNative", "webViewFetch timeout for $urlStr")
                                            result.success(mapOf("statusCode" to 408, "body" to ""))
                                        }
                                    }, 15000)

                                    val js = """
                                        (function() {
                                            try {
                                                console.log("Fetching: " + $escapedUrl);
                                                fetch($escapedUrl, { mode: 'cors', credentials: 'omit' })
                                                    .then(function(r) {
                                                        console.log("Fetch response status: " + r.status);
                                                        return r.text().then(function(t) {
                                                            if (window.AllDownBridge) {
                                                                window.AllDownBridge.postResult(r.status, t);
                                                            } else {
                                                                console.error("AllDownBridge missing on window!");
                                                            }
                                                        });
                                                    })
                                                    .catch(function(e) {
                                                        console.error("Fetch catch: " + e);
                                                        if (window.AllDownBridge) {
                                                            window.AllDownBridge.postResult(500, e.toString());
                                                        }
                                                    });
                                            } catch(err) {
                                                console.error("JS error: " + err);
                                                if (window.AllDownBridge) {
                                                    window.AllDownBridge.postResult(500, err.toString());
                                                }
                                            }
                                        })();
                                    """.trimIndent()
                                    wv.evaluateJavascript(js, null)
                                } catch (e: Exception) {
                                    android.util.Log.e("AllDownNative", "webViewFetch error: ${e.message}", e)
                                    result.error("WEBVIEW_ERROR", e.message, null)
                                }
                            }
                        } else {
                            result.error("INVALID_ARGS", "URL is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun openFollowRedirectsConnection(
        initialUrl: String,
        headers: Map<String, String>?
    ): HttpURLConnection {
        var curUrl = initialUrl
        var redirects = 0
        while (redirects < 8) {
            val url = URL(curUrl)
            val conn = url.openConnection() as HttpURLConnection
            conn.instanceFollowRedirects = false
            conn.connectTimeout = 20000
            conn.readTimeout = 20000
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36")
            headers?.forEach { (k, v) -> conn.setRequestProperty(k, v) }
            val code = conn.responseCode
            if (code in 301..308 && code != 304) {
                val loc = conn.getHeaderField("Location")
                conn.disconnect()
                if (loc != null) {
                    curUrl = if (loc.startsWith("http://") || loc.startsWith("https://")) {
                        loc
                    } else {
                        URL(url, loc).toString()
                    }
                    redirects++
                    continue
                }
            }
            return conn
        }
        val conn = URL(curUrl).openConnection() as HttpURLConnection
        headers?.forEach { (k, v) -> conn.setRequestProperty(k, v) }
        return conn
    }

    private fun isWifiOrEthernetConnected(): Boolean {
        return try {
            val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = cm.activeNetwork ?: return false
            val capabilities = cm.getNetworkCapabilities(network) ?: return false
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        } catch (_: Exception) {
            true
        }
    }

    private fun openFileIntent(path: String) {
        try {
            val file = File(path)
            if (!file.exists()) return

            val authority = "${applicationContext.packageName}.fileprovider"
            val uri = FileProvider.getUriForFile(this, authority, file)
            val lower = path.lowercase()
            val mimeType = when {
                lower.endsWith(".mp3") || lower.endsWith(".m4a") || lower.endsWith(".wav") || lower.endsWith(".ogg") -> "audio/*"
                lower.endsWith(".gif") -> "image/gif"
                lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") -> "image/*"
                else -> "video/*"
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }

    private fun openFolderIntent(path: String) {
        try {
            val folder = File(path)
            val targetDir = if (folder.isDirectory) folder else folder.parentFile
            if (targetDir != null && targetDir.exists()) {
                val authority = "${applicationContext.packageName}.fileprovider"
                val uri = FileProvider.getUriForFile(this, authority, targetDir)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "resource/folder")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                if (intent.resolveActivityInfo(packageManager, 0) != null) {
                    startActivity(intent)
                    return
                }
            }
            val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                type = "*/*"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallbackIntent)
        } catch (_: Exception) {}
    }

    private fun installApkIntent(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false

            val authority = "${applicationContext.packageName}.fileprovider"
            val uri = FileProvider.getUriForFile(this, authority, file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
