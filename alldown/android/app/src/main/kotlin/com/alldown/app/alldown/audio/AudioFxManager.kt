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

    // Store user's baseline band levels (without preamp boost)
    private val userBandLevels = mutableMapOf<Short, Short>()

    fun updateAudioSessionId(sessionId: Int) {
        if (sessionId <= 0 || sessionId == currentSessionId) return
        Log.d(TAG, "updateAudioSessionId: switching from $currentSessionId to $sessionId")
        currentSessionId = sessionId

        // 1. LoudnessEnhancer (Hardware insert effect)
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

        // 2. Re-bind Equalizer to new session
        try {
            equalizer?.release()
        } catch (_: Exception) {}
        equalizer = null

        try {
            equalizer = Equalizer(0, sessionId).apply {
                applyEqualizerState(this)
            }
            Log.d(TAG, "Equalizer bound to session $sessionId")
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

    private fun applyEqualizerState(eq: Equalizer) {
        // Equalizer is active if user enabled EQ OR if Volume Booster is ON
        eq.enabled = isEqEnabled || (isLoudnessEnabled && loudnessGainMb > 0)
        val numBands = eq.numberOfBands
        val maxLevel = try { eq.bandLevelRange[1] } catch (_: Exception) { 1500.toShort() }
        val minLevel = try { eq.bandLevelRange[0] } catch (_: Exception) { (-1500).toShort() }

        // Dual-Engine amplification: Preamp boost on all bands guarantees volume increase on Samsung
        val preampMb = if (isLoudnessEnabled && loudnessGainMb > 0) {
            // Scale gain up to maxLevel (e.g. up to +15 dB hardware boost)
            (loudnessGainMb * 0.6).toInt().coerceIn(0, maxLevel.toInt())
        } else {
            0
        }

        for (b in 0 until numBands) {
            val userLvl = userBandLevels[b.toShort()] ?: 0.toShort()
            val effectiveLvl = (userLvl + preampMb).coerceIn(minLevel.toInt(), maxLevel.toInt()).toShort()
            try {
                eq.setBandLevel(b.toShort(), effectiveLvl)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to set band $b level $effectiveLvl: ${e.message}")
            }
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
                    applyEqualizerState(this)
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
                    val saved = userBandLevels[b.toShort()]
                    if (saved != null) {
                        bandLevels.add(saved.toInt())
                    } else {
                        bandLevels.add(eq.getBandLevel(b.toShort()).toInt())
                    }
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
            "enabled" to (isEqEnabled),
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
            equalizer?.let { applyEqualizerState(it) }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to toggle Equalizer: ${e.message}")
            false
        }
    }

    fun setBandLevel(band: Int, level: Int): Boolean {
        initFx()
        userBandLevels[band.toShort()] = level.toShort()
        return try {
            equalizer?.let { applyEqualizerState(it) }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set band $band level $level: ${e.message}")
            false
        }
    }

    fun usePreset(presetIndex: Int): Boolean {
        initFx()
        return try {
            val eq = equalizer
            if (eq != null && presetIndex >= 0 && presetIndex < eq.numberOfPresets) {
                eq.usePreset(presetIndex.toShort())
                for (b in 0 until eq.numberOfBands) {
                    userBandLevels[b.toShort()] = eq.getBandLevel(b.toShort())
                }
                applyEqualizerState(eq)
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
            // 1. LoudnessEnhancer target gain
            loudnessEnhancer?.let { le ->
                le.enabled = enabled
                if (enabled && loudnessGainMb >= 0) {
                    le.setTargetGain(loudnessGainMb)
                }
            }
            // 2. Dual-engine preamp boost via Equalizer DSP (guarantees boost on Samsung devices)
            equalizer?.let { eq ->
                applyEqualizerState(eq)
            }
            Log.d(TAG, "setLoudness applied: enabled=$enabled, gain=${loudnessGainMb}mB on session $currentSessionId")
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
