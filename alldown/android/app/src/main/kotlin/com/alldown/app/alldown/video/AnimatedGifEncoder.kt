package com.alldown.app.alldown.video

import android.graphics.Bitmap
import android.graphics.Color
import java.io.IOException
import java.io.OutputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Standard Animated GIF Encoder (GIF89a compliant)
 * Correctly emits Logical Screen Descriptor, Netscape Application Extension (looping),
 * Graphic Control Extensions, Local Color Tables, and LZW image data.
 */
class AnimatedGifEncoder {
    private var width = 0
    private var height = 0
    private var delay = 100 // Frame delay in milliseconds
    private var repeat = 0  // 0 = infinite loop
    private var out: OutputStream? = null
    private var isStarted = false
    private var isFirstFrame = true
    private var pixels: ByteArray? = null
    private var indexedPixels: ByteArray? = null
    private var colorDepth = 8
    private var colorTab: ByteArray? = null
    private var usedEntry = BooleanArray(256)

    fun setDelay(ms: Int) {
        delay = ms.coerceAtLeast(20)
    }

    fun setRepeat(iter: Int) {
        repeat = iter
    }

    fun start(os: OutputStream): Boolean {
        out = os
        isStarted = true
        isFirstFrame = true
        return true
    }

    fun addFrame(im: Bitmap): Boolean {
        if (!isStarted || out == null) return false
        try {
            width = im.width
            height = im.height

            if (isFirstFrame) {
                // 1. Header: GIF89a
                writeString("GIF89a")
                // 2. Logical Screen Descriptor (7 bytes)
                writeLogicalScreenDesc()
                // 3. Netscape 2.0 Loop Extension (written ONCE at start)
                if (repeat >= 0) {
                    writeNetscapeExt()
                }
                isFirstFrame = false
            }

            getImagePixels(im)
            analyzePixels()

            // 4. Graphic Control Extension (frame timing)
            writeGraphicCtrlExt()
            // 5. Image Descriptor
            writeImageDesc()
            // 6. Local Color Table (256 colors = 768 bytes)
            writePalette()
            // 7. LZW Encoded Pixels
            writePixels()
            return true
        } catch (_: IOException) {
            return false
        }
    }

    fun finish(): Boolean {
        if (!isStarted) return false
        isStarted = false
        try {
            out?.write(0x3b) // GIF trailer
            out?.flush()
            return true
        } catch (_: IOException) {
            return false
        }
    }

    private fun writeLogicalScreenDesc() {
        writeShort(width)
        writeShort(height)
        // Packed fields: 0x70 = No global color table, 8-bit color resolution
        out?.write(0x70)
        out?.write(0) // Background color index
        out?.write(0) // Pixel aspect ratio
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
            val r = pixels!![k++].toInt() and 0xff
            val g = pixels!![k++].toInt() and 0xff
            val b = pixels!![k++].toInt() and 0xff
            val index = nq.map(r, g, b)
            usedEntry[index] = true
            indexedPixels!![i] = index.toByte()
        }
        pixels = null
        colorDepth = 8
    }

    private fun writeGraphicCtrlExt() {
        out?.write(0x21) // Extension introducer
        out?.write(0xf9) // GCE label
        out?.write(4)    // Block size
        out?.write(0x04) // Packed fields: Disposal method = 1 (do not dispose, keep graphic), user input = 0, transparency = 0
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
        // Packed: 0x87 = Local Color Table present (bit 7) + 256 colors (bits 0-2 = 7)
        out?.write(0x87)
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
            // network[i][0] = Blue, network[i][1] = Green, network[i][2] = Red
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
            // RGB order in GIF color table
            colorTab[k++] = network[i][2].toInt().coerceIn(0, 255).toByte() // Red
            colorTab[k++] = network[i][1].toInt().coerceIn(0, 255).toByte() // Green
            colorTab[k++] = network[i][0].toInt().coerceIn(0, 255).toByte() // Blue
        }
        return colorTab
    }

    fun map(r: Int, g: Int, b: Int): Int {
        var bestd = 1000
        var best = -1
        val i = netindex[g]
        var j = i - 1

        var dist: Int
        var a: Int
        var p = i
        while (j >= 0 || p < 256) {
            if (p < 256) {
                a = network[p][1].toInt() - g
                if (a >= bestd) p = 256
                else {
                    p++
                    if (a < 0) a = -a
                    dist = a + abs(network[p - 1][0].toInt() - b) + abs(network[p - 1][2].toInt() - r)
                    if (dist < bestd) {
                        bestd = dist
                        best = p - 1
                    }
                }
            }
            if (j >= 0) {
                a = network[j][1].toInt() - g
                if (a <= -bestd) j = -1
                else {
                    j--
                    if (a < 0) a = -a
                    dist = a + abs(network[j + 1][0].toInt() - b) + abs(network[j + 1][2].toInt() - r)
                    if (dist < bestd) {
                        bestd = dist
                        best = j + 1
                    }
                }
            }
        }
        return if (best >= 0) best else 0
    }

    private fun unbiasnet() {
        for (i in 0 until 256) {
            network[i][0] = network[i][0] / 256.0
            network[i][1] = network[i][1] / 256.0
            network[i][2] = network[i][2] / 256.0
            network[i][3] = i.toDouble()
        }
    }

    private fun inxbuild() {
        var previouscol = 0
        var startpos = 0
        for (i in 0 until 256) {
            var smallpos = i
            var smallval = network[i][1]
            for (j in i + 1 until 256) {
                if (network[j][1] < smallval) {
                    smallpos = j
                    smallval = network[j][1]
                }
            }
            val q = network[i]
            network[i] = network[smallpos]
            network[smallpos] = q

            if (smallval.toInt() != previouscol) {
                netindex[previouscol] = (startpos + i) shr 1
                for (j in previouscol + 1 until smallval.toInt().coerceAtMost(256)) {
                    netindex[j] = i
                }
                previouscol = smallval.toInt().coerceAtMost(255)
                startpos = i
            }
        }
        netindex[previouscol] = (startpos + 255) shr 1
        for (j in previouscol + 1 until 256) {
            netindex[j] = 255
        }
    }

    private fun learn() {
        if (lengthcount < 3) return
        val lengthcountFixed = lengthcount
        val samplepixels = lengthcountFixed / (3 * samplefac)
        var delta = samplepixels / 100
        if (delta == 0) delta = 1
        val alpha = 1.0 / 30.0

        var rad = 32
        val radstep = rad / 8
        if (radstep == 0) rad = 0
        for (i in 0 until rad) {
            radpower[i] = alpha * (((rad * rad - i * i) * 256.0) / (rad * rad))
        }

        var step = 499
        if (lengthcountFixed % 499 == 0) step = 491
        if (lengthcountFixed % 491 == 0) step = 487
        if (lengthcountFixed % 487 == 0) step = 503

        var pix = 0
        var i = 0
        while (i < samplepixels) {
            val b = (thepicture[pix + 2].toInt() and 0xff) shl 4
            val g = (thepicture[pix + 1].toInt() and 0xff) shl 4
            val r = (thepicture[pix].toInt() and 0xff) shl 4
            var j = contest(b.toDouble(), g.toDouble(), r.toDouble())

            altersingle(alpha, j, b.toDouble(), g.toDouble(), r.toDouble())
            if (rad != 0) alterneigh(rad, j, b.toDouble(), g.toDouble(), r.toDouble())

            pix += step * 3
            if (pix >= lengthcountFixed) pix -= lengthcountFixed

            i++
            if (i % delta == 0) {
                rad = max(0, rad - radstep)
            }
        }
    }

    private fun altersingle(alpha: Double, i: Int, b: Double, g: Double, r: Double) {
        network[i][0] -= alpha * (network[i][0] - b)
        network[i][1] -= alpha * (network[i][1] - g)
        network[i][2] -= alpha * (network[i][2] - r)
    }

    private fun alterneigh(rad: Int, i: Int, b: Double, g: Double, r: Double) {
        var lo = i - rad
        if (lo < -1) lo = -1
        var hi = i + rad
        if (hi > 256) hi = 256

        var j = i + 1
        var k = i - 1
        var q = 1
        while (j < hi || k > lo) {
            val a = radpower[q++] / 256.0
            if (j < hi) {
                val p = network[j++]
                p[0] -= a * (p[0] - b)
                p[1] -= a * (p[1] - g)
                p[2] -= a * (p[2] - r)
            }
            if (k > lo) {
                val p = network[k--]
                p[0] -= a * (p[0] - b)
                p[1] -= a * (p[1] - g)
                p[2] -= a * (p[2] - r)
            }
        }
    }

    private fun contest(b: Double, g: Double, r: Double): Int {
        var bestd = Double.MAX_VALUE
        var bestbiasd = bestd
        var bestpos = -1
        var bestbiaspos = bestpos

        for (i in 0 until 256) {
            val n = network[i]
            val dist = abs(n[0] - b) + abs(n[1] - g) + abs(n[2] - r)
            if (dist < bestd) {
                bestd = dist
                bestpos = i
            }
            val biasdist = dist - ((bias[i]) / (1 shl 16))
            if (biasdist < bestbiasd) {
                bestbiasd = biasdist
                bestbiaspos = i
            }
            val betafreq = freq[i] / 1024.0
            freq[i] -= betafreq
            bias[i] += betafreq * 65536.0
        }
        freq[bestpos] += 1.0 / 1024.0
        bias[bestpos] -= 65536.0 / 1024.0
        return if (bestbiaspos >= 0) bestbiaspos else bestpos
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
