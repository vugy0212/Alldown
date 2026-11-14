package com.alldown.app.alldown.service

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

class AudioPlaybackService : Service() {

    companion object {
        private const val TAG = "AudioPlaybackService"
        const val NOTIFICATION_ID = 2002

        const val ACTION_START = "ACTION_START_AUDIO"
        const val ACTION_PAUSE = "ACTION_PAUSE_AUDIO"
        const val ACTION_STOP = "ACTION_STOP_AUDIO"

        private var wakeLock: PowerManager.WakeLock? = null
        private var latestNotification: Notification? = null
        private var isServiceRunning: Boolean = false

        fun startOrUpdateService(context: Context, notification: Notification, isPlaying: Boolean) {
            latestNotification = notification
            if (isPlaying) {
                val intent = Intent(context, AudioPlaybackService::class.java).apply {
                    action = ACTION_START
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start/update AudioPlaybackService: ${e.message}")
                }
            } else {
                if (isServiceRunning) {
                    val intent = Intent(context, AudioPlaybackService::class.java).apply {
                        action = ACTION_PAUSE
                    }
                    try {
                        context.startService(intent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to send pause to AudioPlaybackService: ${e.message}")
                    }
                } else {
                    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    manager?.notify(NOTIFICATION_ID, notification)
                }
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, AudioPlaybackService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop AudioPlaybackService: ${e.message}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                acquireWakeLock()
                val notif = latestNotification ?: buildFallbackNotification()
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            notif,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notif)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "startForeground error: ${e.message}")
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    manager?.notify(NOTIFICATION_ID, notif)
                }
            }
            ACTION_PAUSE -> {
                releaseWakeLock()
                latestNotification?.let { notif ->
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            stopForeground(STOP_FOREGROUND_DETACH)
                        } else {
                            @Suppress("DEPRECATION")
                            stopForeground(false)
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "stopForeground error on pause: ${e.message}")
                    }
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    manager?.notify(NOTIFICATION_ID, notif)
                }
            }
            ACTION_STOP -> {
                releaseWakeLock()
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        stopForeground(STOP_FOREGROUND_REMOVE)
                    } else {
                        @Suppress("DEPRECATION")
                        stopForeground(true)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "stopForeground error on stop: ${e.message}")
                }
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        isServiceRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "AllDown::AudioPlaybackWakeLock"
            )?.apply {
                setReferenceCounted(false)
            }
        }
        try {
            wakeLock?.acquire(12 * 60 * 60 * 1000L) // 12 hours max safety
            Log.d(TAG, "Audio wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire audio wake lock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "Audio wake lock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release audio wake lock: ${e.message}")
        }
    }

    private fun buildFallbackNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "alldown_audio_player_channel")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val appIcon = applicationInfo.icon
        val smallIconRes = if (appIcon != 0) appIcon else android.R.drawable.stat_sys_download
        return builder
            .setContentTitle("AllDown Player")
            .setContentText("Playing audio")
            .setSmallIcon(smallIconRes)
            .build()
    }
}
