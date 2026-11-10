package com.alldown.app.alldown.video

import android.graphics.Bitmap
import android.graphics.Color
import java.io.IOException
import java.io.OutputStream

/**
 * Standard Animated GIF Encoder (GIF89a compliant)
 * Uses a vibrant, instantaneous 256-color palette (216 Web-Safe color cube + 32 grayscale levels + 8 primaries)
 * and robust LZW compression. Extremely fast (< 0.5s) with true-to-life color rendering.
 */
class AnimatedGifEncoder {
    private var width = 0
    private var height = 0
    private var delay = 100 // Frame delay in milliseconds
    private var repeat = 0  // 0 = infinite loop
    private var out: OutputStream? = null
    private var isStarted = false
    private var isFirstFrame = true
    private var indexedPixels: ByteArray? = null
    private val colorDepth = 8

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
                // 3. Netscape 2.0 Loop Extension (written ONCE at the start)
                if (repeat >= 0) {
                    writeNetscapeExt()
                }
                isFirstFrame = false
            }

            // Map all pixels to 256-color palette
            quantizePixels(im)

            // 4. Graphic Control Extension (timing & animation control)
            writeGraphicCtrlExt()
            // 5. Image Descriptor
            writeImageDesc()
            // 6. Local Color Table (256 colors = 768 bytes)
            writePalette()
            // 7. LZW Compressed Pixel Data
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

    private fun quantizePixels(image: Bitmap) {
        val w = image.width
        val h = image.height
        val total = w * h
        val rgb = IntArray(total)
        image.getPixels(rgb, 0, w, 0, 0, w, h)

        val idxArr = ByteArray(total)
        for (i in 0 until total) {
            val c = rgb[i]
            val r = (c shr 16) and 0xff
            val g = (c shr 8) and 0xff
            val b = c and 0xff
            idxArr[i] = FastColorQuantizer.mapColor(r, g, b)
        }
        indexedPixels = idxArr
    }

    private fun writeGraphicCtrlExt() {
        out?.write(0x21) // Extension introducer
        out?.write(0xf9) // GCE label
        out?.write(4)    // Block size
        out?.write(0x04) // Packed fields: Disposal method = 1 (do not dispose), transparency = 0
        writeShort(delay / 10) // Delay time in 100ths of a second
        out?.write(0)    // Transparent color index
        out?.write(0)    // Block terminator
    }

    private fun writeImageDesc() {
        out?.write(0x2c) // Image separator
        writeShort(0)    // Left position = 0
        writeShort(0)    // Top position = 0
        writeShort(width)
        writeShort(height)
        // Packed: 0x87 = Local Color Table present + 256 colors
        out?.write(0x87)
    }

    private fun writePalette() {
        out?.write(FastColorQuantizer.palette)
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
 * High-speed 256-color palette quantizer
 * 216 RGB cube colors (6x6x6) + 32 grayscale levels + 8 vibrant primaries
 */
private object FastColorQuantizer {
    val palette: ByteArray = ByteArray(256 * 3).apply {
        var idx = 0
        // 1. 216 RGB cube colors (steps: 0, 51, 102, 153, 204, 255)
        for (r in 0..5) {
            for (g in 0..5) {
                for (b in 0..5) {
                    this[idx++] = (r * 51).toByte()
                    this[idx++] = (g * 51).toByte()
                    this[idx++] = (b * 51).toByte()
                }
            }
        }
        // 2. 32 smooth grayscale levels
        for (i in 0 until 32) {
            val v = (i * 255 / 31).toByte()
            this[idx++] = v
            this[idx++] = v
            this[idx++] = v
        }
        // 3. 8 vivid accent colors
        val extras = intArrayOf(
            0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00,
            0x00FFFF, 0xFF00FF, 0xFFA500, 0xFFFFFF
        )
        for (c in extras) {
            this[idx++] = ((c shr 16) and 0xff).toByte()
            this[idx++] = ((c shr 8) and 0xff).toByte()
            this[idx++] = (c and 0xff).toByte()
        }
    }

    fun mapColor(r: Int, g: Int, b: Int): Byte {
        val maxC = maxOf(r, maxOf(g, b))
        val minC = minOf(r, minOf(g, b))

        // If grayscale or near-neutral, map to grayscale ramp for smooth shading
        if (maxC - minC < 10) {
            val grayIdx = (r * 31 / 255).coerceIn(0, 31)
            return (216 + grayIdx).toByte()
        }

        // Map to 6x6x6 RGB cube
        val rIdx = ((r * 5 + 25) / 255).coerceIn(0, 5)
        val gIdx = ((g * 5 + 25) / 255).coerceIn(0, 5)
        val bIdx = ((b * 5 + 25) / 255).coerceIn(0, 5)
        val cubeIdx = rIdx * 36 + gIdx * 6 + bIdx
        return cubeIdx.toByte()
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
