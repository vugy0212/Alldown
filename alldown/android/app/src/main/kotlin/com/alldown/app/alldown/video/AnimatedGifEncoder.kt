package com.alldown.app.alldown.video

import android.graphics.Bitmap
import android.graphics.Color
import java.io.IOException
import java.io.OutputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Standard Animated GIF Encoder (GIF89a)
 * Supports frame delay, infinite looping, adaptive color quantization, and LZW compression.
 */
class AnimatedGifEncoder {
    private var width = 0
    private var height = 0
    private var delay = 100 // Frame delay in milliseconds
    private var repeat = 0  // 0 = infinite loop
    private var out: OutputStream? = null
    private var isStarted = false
    private var pixels: ByteArray? = null
    private var indexedPixels: ByteArray? = null
    private var colorDepth = 8
    private var colorTab: ByteArray? = null
    private var usedEntry = BooleanArray(256)
    private var palSize = 7

    fun setDelay(ms: Int) {
        delay = ms
    }

    fun setRepeat(iter: Int) {
        repeat = iter
    }

    fun start(os: OutputStream): Boolean {
        out = os
        var ok = true
        try {
            writeString("GIF89a")
            isStarted = true
        } catch (_: IOException) {
            ok = false
        }
        return ok
    }

    fun addFrame(im: Bitmap): Boolean {
        if (!isStarted || out == null) return false
        var ok = true
        try {
            width = im.width
            height = im.height
            getImagePixels(im)
            analyzePixels()
            if (repeat >= 0) {
                writeNetscapeExt()
            }
            writeGraphicCtrlExt()
            writeImageDesc()
            writePalette()
            writePixels()
        } catch (_: IOException) {
            ok = false
        }
        return ok
    }

    fun finish(): Boolean {
        if (!isStarted) return false
        var ok = true
        isStarted = false
        try {
            out?.write(0x3b) // GIF trailer
            out?.flush()
        } catch (_: IOException) {
            ok = false
        }
        return ok
    }

    private fun getImagePixels(image: Bitmap) {
        val w = image.width
        val h = image.height
        val rgb = IntArray(w * h)
        image.getPixels(rgb, 0, w, 0, 0, w, h)
        pixels = ByteArray(rgb.size * 3)
        var count = 0
        for (color in rgb) {
            pixels!![count++] = Color.red(color).toByte()
            pixels!![count++] = Color.green(color).toByte()
            pixels!![count++] = Color.blue(color).toByte()
        }
    }

    private fun analyzePixels() {
        val len = pixels!!.size
        val nPix = len / 3
        indexedPixels = ByteArray(nPix)
        val nq = NeuQuant(pixels!!, len, 10)
        colorTab = nq.process()

        var k = 0
        for (i in 0 until nPix) {
            val index = nq.map(
                pixels!![k++].toInt() and 0xff,
                pixels!![k++].toInt() and 0xff,
                pixels!![k++].toInt() and 0xff
            )
            usedEntry[index] = true
            indexedPixels!![i] = index.toByte()
        }
        pixels = null
        colorDepth = 8
        palSize = 7
    }

    private fun writeGraphicCtrlExt() {
        out?.write(0x21) // Extension introducer
        out?.write(0xf9) // GCE label
        out?.write(4)    // Block size
        out?.write(0)    // Packed fields (no disposal, no transparency)
        writeShort(delay / 10) // Delay time in 100ths of a second
        out?.write(0)    // Transparent color index
        out?.write(0)    // Block terminator
    }

    private fun writeImageDesc() {
        out?.write(0x2c) // Image separator
        writeShort(0)    // Image left
        writeShort(0)    // Image top
        writeShort(width)
        writeShort(height)
        out?.write(0x80 or 0x07) // Local Color Table flag + depth
    }

    private fun writePalette() {
        colorTab?.let { out?.write(it) }
        val n = (3 * 256) - (colorTab?.size ?: 0)
        for (i in 0 until n) {
            out?.write(0)
        }
    }

    private fun writeNetscapeExt() {
        out?.write(0x21) // Extension introducer
        out?.write(0xff) // App extension label
        out?.write(11)   // Block size
        writeString("NETSCAPE2.0")
        out?.write(3)    // Sub-block size
        out?.write(1)    // Loop sub-block ID
        writeShort(repeat) // Loop count (0 = infinite)
        out?.write(0)    // Block terminator
    }

    private fun writePixels() {
        val encoder = LZWEncoder(width, height, indexedPixels!!, colorDepth)
        out?.let { encoder.encode(it) }
    }

    private fun writeShort(value: Int) {
        out?.write(value and 0xff)
        out?.write((value shr 8) and 0xff)
    }

    private fun writeString(s: String) {
        for (ch in s) {
            out?.write(ch.code)
        }
    }
}

/**
 * NeuQuant Neural-Net Quantization Algorithm
 */
private class NeuQuant(private val thepicture: ByteArray, private val lengthcount: Int, private val samplefac: Int) {
    private val network = Array(256) { DoubleArray(4) }
    private val netindex = IntArray(256)
    private val bias = DoubleArray(256)
    private val freq = DoubleArray(256)
    private val radpower = DoubleArray(32)

    init {
        for (i in 0 until 256) {
            network[i][0] = (i shl 4).toDouble()
            network[i][1] = (i shl 4).toDouble()
            network[i][2] = (i shl 4).toDouble()
            freq[i] = 1.0 / 256.0
            bias[i] = 0.0
        }
    }

    fun process(): ByteArray {
        learn()
        unbiasnet()
        inxbuild()
        val colorTab = ByteArray(256 * 3)
        var k = 0
        for (i in 0 until 256) {
            colorTab[k++] = network[i][0].toInt().coerceIn(0, 255).toByte()
            colorTab[k++] = network[i][1].toInt().coerceIn(0, 255).toByte()
            colorTab[k++] = network[i][2].toInt().coerceIn(0, 255).toByte()
        }
        return colorTab
    }

    fun map(b: Int, g: Int, r: Int): Int {
        var bestd = 1000
        var best = -1
        val i = netindex[g]
        var j = i - 1

        var dist: Int
        var a: Int
        while (j >= 0 || i < 256) {
            if (i < 256) {
                a = network[i][1].toInt() - g
                if (a >= bestd) break
                dist = abs(a) + abs(network[i][0].toInt() - b) + abs(network[i][2].toInt() - r)
                if (dist < bestd) {
                    bestd = dist
                    best = network[i][3].toInt()
                }
            }
            if (j >= 0) {
                a = g - network[j][1].toInt()
                if (a >= bestd) break
                dist = abs(a) + abs(network[j][0].toInt() - b) + abs(network[j][2].toInt() - r)
                if (dist < bestd) {
                    bestd = dist
                    best = network[j][3].toInt()
                }
                j--
            }
        }
        return if (best >= 0) best else 0
    }

    private fun inxbuild() {
        for (i in 0 until 256) {
            network[i][3] = i.toDouble()
        }
        for (i in 0 until 256) {
            netindex[network[i][1].toInt().coerceIn(0, 255)] = i
        }
    }

    private fun unbiasnet() {
        for (i in 0 until 256) {
            network[i][0] = network[i][0].coerceIn(0.0, 255.0)
            network[i][1] = network[i][1].coerceIn(0.0, 255.0)
            network[i][2] = network[i][2].coerceIn(0.0, 255.0)
        }
    }

    private fun learn() {
        val step = max(1, lengthcount / (3 * 100))
        var pix = 0
        val lim = lengthcount
        while (pix < lim) {
            val b = (thepicture[pix].toInt() and 0xff).toDouble()
            val g = (thepicture[pix + 1].toInt() and 0xff).toDouble()
            val r = (thepicture[pix + 2].toInt() and 0xff).toDouble()
            val j = contest(b, g, r)
            altersingle(1.0 / 64.0, j, b, g, r)
            pix += 3 * step
        }
    }

    private fun altersingle(alpha: Double, i: Int, b: Double, g: Double, r: Double) {
        network[i][0] -= alpha * (network[i][0] - b)
        network[i][1] -= alpha * (network[i][1] - g)
        network[i][2] -= alpha * (network[i][2] - r)
    }

    private fun contest(b: Double, g: Double, r: Double): Int {
        var bestd = Double.MAX_VALUE
        var bestbiasd = bestd
        var best = -1
        var bestpos = -1

        for (i in 0 until 256) {
            val dist = abs(network[i][0] - b) + abs(network[i][1] - g) + abs(network[i][2] - r)
            if (dist < bestd) {
                bestd = dist
                best = i
            }
            val biasdist = dist - (bias[i] / (1 shl 16))
            if (biasdist < bestbiasd) {
                bestbiasd = biasdist
                bestpos = i
            }
        }
        return if (bestpos >= 0) bestpos else best
    }
}

/**
 * LZW Image Data Compression for GIF
 */
private class LZWEncoder(
    private val imgW: Int,
    private val imgH: Int,
    private val pixAry: ByteArray,
    private val initCodeSize: Int
) {
    private var cur_accum = 0
    private var cur_bits = 0
    private val accum = ByteArray(256)
    private val htab = IntArray(5003)
    private val codetab = IntArray(5003)
    private var free_ent = 0
    private var maxcode = 0
    private var n_bits = 0
    private var init_bits = 0
    private var ClearCode = 0
    private var EOFCode = 0
    private var remaining = imgW * imgH
    private var curPixel = 0

    fun encode(os: OutputStream) {
        os.write(initCodeSize)
        remaining = imgW * imgH
        curPixel = 0
        compress(initCodeSize + 1, os)
        os.write(0)
    }

    private fun compress(init_bits: Int, outs: OutputStream) {
        this.init_bits = init_bits
        n_bits = init_bits
        maxcode = (1 shl n_bits) - 1
        ClearCode = 1 shl (init_bits - 1)
        EOFCode = ClearCode + 1
        free_ent = ClearCode + 2

        for (i in 0 until 5003) {
            htab[i] = -1
        }

        output(ClearCode, outs)

        var ent = nextPixel()
        var c = nextPixel()
        while (c != -1) {
            val fcode = (c shl 12) + ent
            var i = (c shl 4) xor ent
            if (htab[i] == fcode) {
                ent = codetab[i]
                c = nextPixel()
                continue
            } else if (htab[i] >= 0) {
                var disp = 5003 - i
                if (i == 0) disp = 1
                var matched = false
                while (true) {
                    i -= disp
                    if (i < 0) i += 5003
                    if (htab[i] == fcode) {
                        ent = codetab[i]
                        matched = true
                        break
                    }
                    if (htab[i] < 0) break
                }
                if (matched) {
                    c = nextPixel()
                    continue
                }
            }

            output(ent, outs)
            ent = c
            if (free_ent < 4096) {
                codetab[i] = free_ent++
                htab[i] = fcode
            } else {
                for (j in 0 until 5003) htab[j] = -1
                free_ent = ClearCode + 2
                output(ClearCode, outs)
                n_bits = this.init_bits
                maxcode = (1 shl n_bits) - 1
            }
            c = nextPixel()
        }
        output(ent, outs)
        output(EOFCode, outs)
    }

    private fun nextPixel(): Int {
        if (remaining == 0) return -1
        remaining--
        return pixAry[curPixel++].toInt() and 0xff
    }

    private fun output(code: Int, outs: OutputStream) {
        cur_accum = cur_accum or (code shl cur_bits)
        cur_bits += n_bits
        while (cur_bits >= 8) {
            char_out((cur_accum and 0xff).toByte(), outs)
            cur_accum = cur_accum shr 8
            cur_bits -= 8
        }
        if (free_ent > maxcode || code == ClearCode) {
            if (code == ClearCode) {
                n_bits = init_bits
                maxcode = (1 shl n_bits) - 1
            } else {
                n_bits++
                maxcode = if (n_bits == 12) 4096 else (1 shl n_bits) - 1
            }
        }
        if (code == EOFCode) {
            while (cur_bits > 0) {
                char_out((cur_accum and 0xff).toByte(), outs)
                cur_accum = cur_accum shr 8
                cur_bits -= 8
            }
            flush_char(outs)
        }
    }

    private var a_count = 0
    private fun char_out(c: Byte, outs: OutputStream) {
        accum[a_count++] = c
        if (a_count >= 254) flush_char(outs)
    }

    private fun flush_char(outs: OutputStream) {
        if (a_count > 0) {
            outs.write(a_count)
            outs.write(accum, 0, a_count)
            a_count = 0
        }
    }
}

