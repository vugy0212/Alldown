package com.alldown.app.alldown.audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.util.Log
import com.alldown.app.alldown.MainActivity
import io.flutter.plugin.common.MethodChannel

class MediaSessionManager(
    private val context: Context,
    private var methodChannel: MethodChannel?
) {
    private val TAG = "AllDownMediaSession"
    private val CHANNEL_ID = "alldown_audio_player_channel"
    private val CHANNEL_NAME = "AllDown Audio Player"
    private val NOTIFICATION_ID = 2002

    private var mediaSession: MediaSession? = null
    private var isReceiverRegistered = false
    private var isActionReceiverRegistered = false

    private var currentTitle: String = "AllDown Audio"
    private var currentArtist: String = ""
    private var isPlaying: Boolean = false
    private var currentPositionMs: Long = 0L
    private var currentDurationMs: Long = 0L

    private val becomingNoisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                Log.d(TAG, "Headphones disconnected -> Pausing audio")
                methodChannel?.invokeMethod("onMediaPause", null)
            }
        }
    }

    private val mediaActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.alldown.app.MEDIA_PREV" -> methodChannel?.invokeMethod("onMediaSkipPrevious", null)
                "com.alldown.app.MEDIA_PLAY_PAUSE" -> methodChannel?.invokeMethod("onMediaPlayPause", null)
                "com.alldown.app.MEDIA_NEXT" -> methodChannel?.invokeMethod("onMediaSkipNext", null)
                "com.alldown.app.MEDIA_CLOSE" -> {
                    methodChannel?.invokeMethod("onMediaStop", null)
                    stopMedia()
                }
            }
        }
    }

    init {
        createNotificationChannel()
        initMediaSession()
        registerActionReceiver()
    }

    fun setChannel(channel: MethodChannel) {
        this.methodChannel = channel
    }

    private fun registerActionReceiver() {
        if (!isActionReceiverRegistered) {
            try {
                val filter = IntentFilter().apply {
                    addAction("com.alldown.app.MEDIA_PREV")
                    addAction("com.alldown.app.MEDIA_PLAY_PAUSE")
                    addAction("com.alldown.app.MEDIA_NEXT")
                    addAction("com.alldown.app.MEDIA_CLOSE")
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    context.registerReceiver(mediaActionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    context.registerReceiver(mediaActionReceiver, filter)
                }
                isActionReceiverRegistered = true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register media action receiver: ${e.message}")
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Shows lock screen and active audio playback controls"
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                manager.createNotificationChannel(channel)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create notification channel: ${e.message}")
            }
        }
    }

    private fun initMediaSession() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                mediaSession = MediaSession(context, "AllDownMediaSession").apply {
                    setCallback(object : MediaSession.Callback() {
                        override fun onPlay() {
                            methodChannel?.invokeMethod("onMediaPlay", null)
                        }

                        override fun onPause() {
                            methodChannel?.invokeMethod("onMediaPause", null)
                        }

                        override fun onSkipToNext() {
                            methodChannel?.invokeMethod("onMediaSkipNext", null)
                        }

                        override fun onSkipToPrevious() {
                            methodChannel?.invokeMethod("onMediaSkipPrevious", null)
                        }

                        override fun onSeekTo(pos: Long) {
                            methodChannel?.invokeMethod("onMediaSeekTo", pos)
                        }

                        override fun onStop() {
                            methodChannel?.invokeMethod("onMediaStop", null)
                        }
                    })
                    isActive = true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize MediaSession: ${e.message}")
            }
        }
    }

    fun updatePlaybackState(
        title: String,
        artist: String,
        isPlaying: Boolean,
        positionMs: Long,
        durationMs: Long,
        hasNext: Boolean,
        hasPrev: Boolean
    ) {
        this.currentTitle = title
        this.currentArtist = artist
        this.isPlaying = isPlaying
        this.currentPositionMs = positionMs
        this.currentDurationMs = durationMs

        if (isPlaying) {
            if (!isReceiverRegistered) {
                try {
                    val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        context.registerReceiver(becomingNoisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        context.registerReceiver(becomingNoisyReceiver, filter)
                    }
                    isReceiverRegistered = true
                } catch (_: Exception) {}
            }
        }

        // Update MediaSession
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && mediaSession != null) {
                val actions = PlaybackState.ACTION_PLAY or
                        PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_PLAY_PAUSE or
                        PlaybackState.ACTION_STOP or
                        PlaybackState.ACTION_SEEK_TO or
                        (if (hasNext) PlaybackState.ACTION_SKIP_TO_NEXT else 0L) or
                        (if (hasPrev) PlaybackState.ACTION_SKIP_TO_PREVIOUS else 0L)

                val state = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
                val stateBuilder = PlaybackState.Builder()
                    .setActions(actions)
                    .setState(state, positionMs, 1.0f)

                mediaSession?.setPlaybackState(stateBuilder.build())

                val metaBuilder = MediaMetadata.Builder()
                    .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                    .putString(MediaMetadata.METADATA_KEY_ARTIST, artist.ifEmpty { "AllDown Music" })
                    .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)

                mediaSession?.setMetadata(metaBuilder.build())
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error updating MediaSession state: ${e.message}")
        }

        try {
            showMediaNotification(hasNext, hasPrev)
        } catch (e: Exception) {
            Log.w(TAG, "Error showing media notification: ${e.message}")
        }
    }

    private fun showMediaNotification(hasNext: Boolean, hasPrev: Boolean) {
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val contentPendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            // Action Intents
            val prevPending = PendingIntent.getBroadcast(
                context,
                1,
                Intent("com.alldown.app.MEDIA_PREV"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val playPausePending = PendingIntent.getBroadcast(
                context,
                2,
                Intent("com.alldown.app.MEDIA_PLAY_PAUSE"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val nextPending = PendingIntent.getBroadcast(
                context,
                3,
                Intent("com.alldown.app.MEDIA_NEXT"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val closePending = PendingIntent.getBroadcast(
                context,
                4,
                Intent("com.alldown.app.MEDIA_CLOSE"),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

            val appIcon = context.applicationInfo.icon
            val smallIconRes = if (appIcon != 0) appIcon else android.R.drawable.stat_sys_download

            builder.setContentTitle(currentTitle)
                .setContentText(currentArtist.ifEmpty { "AllDown Player" })
                .setSmallIcon(smallIconRes)
                .setContentIntent(contentPendingIntent)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying)
                .setAutoCancel(!isPlaying)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_media_previous,
                        "Previous",
                        prevPending
                    ).build()
                )
                builder.addAction(
                    Notification.Action.Builder(
                        if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                        if (isPlaying) "Pause" else "Play",
                        playPausePending
                    ).build()
                )
                builder.addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_media_next,
                        "Next",
                        nextPending
                    ).build()
                )
                builder.addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_menu_close_clear_cancel,
                        "Close",
                        closePending
                    ).build()
                )

                mediaSession?.let {
                    val mediaStyle = Notification.MediaStyle()
                        .setMediaSession(it.sessionToken)
                        .setShowActionsInCompactView(0, 1, 2)
                    builder.style = mediaStyle
                }
            }

            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: Exception) {
            Log.w(TAG, "NotificationManager notify failed: ${e.message}")
        }
    }

    fun stopMedia() {
        isPlaying = false
        if (isReceiverRegistered) {
            try {
                context.unregisterReceiver(becomingNoisyReceiver)
                isReceiverRegistered = false
            } catch (_: Exception) {}
        }
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
        mediaSession?.isActive = false
    }

    fun release() {
        stopMedia()
        if (isActionReceiverRegistered) {
            try {
                context.unregisterReceiver(mediaActionReceiver)
                isActionReceiverRegistered = false
            } catch (_: Exception) {}
        }
        mediaSession?.release()
        mediaSession = null
    }
}
