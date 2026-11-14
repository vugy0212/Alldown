package com.alldown.app.alldown.audio

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log

class AudioFxManager {
    private val TAG = "AllDownAudioFx"
    private var currentSessionId: Int = 0

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null

    private var isEqEnabled: Boolean = false
    private var isBassEnabled: Boolean = false
    private var bassStrength: Int = 0
    private var isLoudnessEnabled: Boolean = false
    private var loudnessGainMb: Int = 0

    fun updateAudioSessionId(sessionId: Int) {
        if (sessionId <= 0 || sessionId == currentSessionId) return
        Log.d(TAG, "updateAudioSessionId: switching from $currentSessionId to $sessionId")
        currentSessionId = sessionId

        // 1. LoudnessEnhancer (Crucial for Samsung S25 Ultra / Android 14+):
        try {
            loudnessEnhancer?.release()
        } catch (_: Exception) {}
        loudnessEnhancer = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try {
                loudnessEnhancer = LoudnessEnhancer(sessionId).apply {
                    enabled = isLoudnessEnabled
                    if (loudnessGainMb > 0) {
                        setTargetGain(loudnessGainMb)
                    }
                }
                Log.d(TAG, "LoudnessEnhancer bound to session $sessionId (gain=$loudnessGainMb, enabled=$isLoudnessEnabled)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to bind LoudnessEnhancer to session $sessionId: ${e.message}")
            }
        }

        // 2. Re-bind Equalizer to new session preserving levels
        val savedBandLevels = mutableMapOf<Short, Short>()
        try {
            equalizer?.let { eq ->
                for (b in 0 until eq.numberOfBands) {
                    savedBandLevels[b.toShort()] = eq.getBandLevel(b.toShort())
                }
                eq.release()
            }
        } catch (_: Exception) {}
        equalizer = null

        try {
            equalizer = Equalizer(0, sessionId).apply {
                enabled = isEqEnabled
                for ((b, lvl) in savedBandLevels) {
                    if (b < numberOfBands) {
                        setBandLevel(b, lvl)
                    }
                }
            }
            Log.d(TAG, "Equalizer bound to session $sessionId (enabled=$isEqEnabled)")
        } catch (e: Exception) {
            Log.w(TAG, "Equalizer re-bind error on session $sessionId: ${e.message}")
        }

        // 3. Re-bind BassBoost to new session
        try {
            bassBoost?.release()
        } catch (_: Exception) {}
        bassBoost = null

        try {
            bassBoost = BassBoost(0, sessionId).apply {
                enabled = isBassEnabled
                if (strengthSupported && bassStrength > 0) {
                    setStrength(bassStrength.toShort())
                }
            }
            Log.d(TAG, "BassBoost bound to session $sessionId (strength=$bassStrength, enabled=$isBassEnabled)")
        } catch (e: Exception) {
            Log.w(TAG, "BassBoost re-bind error on session $sessionId: ${e.message}")
        }
    }

    fun initFx(audioSessionId: Int = currentSessionId) {
        if (audioSessionId > 0 && audioSessionId != currentSessionId) {
            updateAudioSessionId(audioSessionId)
            return
        }

        val targetSession = if (currentSessionId > 0) currentSessionId else 0

        try {
            if (equalizer == null) {
                equalizer = Equalizer(0, targetSession).apply {
                    enabled = isEqEnabled
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Equalizer initialization error: ${e.message}")
        }

        try {
            if (bassBoost == null) {
                bassBoost = BassBoost(0, targetSession).apply {
                    enabled = isBassEnabled
                    if (strengthSupported && bassStrength > 0) {
                        setStrength(bassStrength.toShort())
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "BassBoost initialization error: ${e.message}")
        }

        try {
            if (loudnessEnhancer == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                loudnessEnhancer = LoudnessEnhancer(targetSession).apply {
                    enabled = isLoudnessEnabled
                    if (loudnessGainMb > 0) {
                        setTargetGain(loudnessGainMb)
                    }
                }
                Log.d(TAG, "LoudnessEnhancer initialized on session $targetSession (gain=$loudnessGainMb, enabled=$isLoudnessEnabled)")
            }
        } catch (e: Exception) {
            Log.w(TAG, "LoudnessEnhancer initialization error on session $targetSession: ${e.message}")
        }
    }

    fun getEqualizerParams(): Map<String, Any> {
        initFx()
        val eq = equalizer
        val bb = bassBoost
        val le = loudnessEnhancer

        val numBands = eq?.numberOfBands?.toInt() ?: 0
        val bandFreqs = mutableListOf<Int>()
        val bandLevels = mutableListOf<Int>()
        var minLevel = -1500
        var maxLevel = 1500

        if (eq != null && numBands > 0) {
            try {
                val range = eq.bandLevelRange
                if (range.size >= 2) {
                    minLevel = range[0].toInt()
                    maxLevel = range[1].toInt()
                }
                for (b in 0 until numBands) {
                    bandFreqs.add(eq.getCenterFreq(b.toShort()) / 1000) // Convert to Hz
                    bandLevels.add(eq.getBandLevel(b.toShort()).toInt())
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error querying bands: ${e.message}")
            }
        }

        val presets = mutableListOf<String>()
        val numPresets = eq?.numberOfPresets?.toInt() ?: 0
        if (eq != null && numPresets > 0) {
            for (p in 0 until numPresets) {
                try {
                    presets.add(eq.getPresetName(p.toShort()))
                } catch (_: Exception) {
                    presets.add("Preset $p")
                }
            }
        }

        val currentPreset = eq?.currentPreset?.toInt() ?: -1

        return mapOf(
            "supported" to (eq != null),
            "enabled" to (eq?.enabled ?: false),
            "numBands" to numBands,
            "bandFrequencies" to bandFreqs,
            "minLevel" to minLevel,
            "maxLevel" to maxLevel,
            "bandLevels" to bandLevels,
            "presets" to presets,
            "currentPreset" to currentPreset,
            "bassBoostSupported" to (bb?.strengthSupported ?: false),
            "bassBoostEnabled" to (bb?.enabled ?: false),
            "bassBoostStrength" to (bassStrength),
            "loudnessSupported" to (le != null || Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT),
            "loudnessEnabled" to (isLoudnessEnabled),
            "loudnessGain" to (loudnessGainMb)
        )
    }

    fun setEqualizerEnabled(enabled: Boolean): Boolean {
        isEqEnabled = enabled
        initFx()
        return try {
            equalizer?.enabled = enabled
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to toggle Equalizer: ${e.message}")
            false
        }
    }

    fun setBandLevel(band: Int, level: Int): Boolean {
        initFx()
        return try {
            equalizer?.setBandLevel(band.toShort(), level.toShort())
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set band $band level $level: ${e.message}")
            false
        }
    }

    fun usePreset(presetIndex: Int): Boolean {
        initFx()
        return try {
            if (presetIndex >= 0 && presetIndex < (equalizer?.numberOfPresets ?: 0)) {
                equalizer?.usePreset(presetIndex.toShort())
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to use preset $presetIndex: ${e.message}")
            false
        }
    }

    fun setBassBoost(enabled: Boolean, strength: Int): Boolean {
        isBassEnabled = enabled
        bassStrength = strength.coerceIn(0, 1000)
        initFx()
        return try {
            bassBoost?.enabled = enabled
            if (bassBoost?.strengthSupported == true) {
                bassBoost?.setStrength(bassStrength.toShort())
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set BassBoost: ${e.message}")
            false
        }
    }

    fun setLoudness(enabled: Boolean, gainMb: Int): Boolean {
        isLoudnessEnabled = enabled
        loudnessGainMb = gainMb.coerceIn(0, 3000)
        initFx()
        return try {
            loudnessEnhancer?.let { le ->
                le.enabled = enabled
                if (enabled && loudnessGainMb >= 0) {
                    le.setTargetGain(loudnessGainMb)
                }
                Log.d(TAG, "setLoudness: enabled=$enabled, gain=${loudnessGainMb}mB on session $currentSessionId")
            } ?: run {
                Log.w(TAG, "setLoudness: loudnessEnhancer is null for session $currentSessionId")
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set LoudnessEnhancer: ${e.message}")
            false
        }
    }

    fun release() {
        try {
            equalizer?.release()
            bassBoost?.release()
            loudnessEnhancer?.release()
        } catch (_: Exception) {}
        equalizer = null
        bassBoost = null
        loudnessEnhancer = null
    }
}
