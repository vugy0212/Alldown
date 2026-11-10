package com.alldown.app.alldown.video

import android.graphics.Bitmap
import android.media.MediaScannerConnection
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.util.PriorityQueue
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Professional High-Quality Animated GIF Encoder (GIF89a)
 * Features:
 * - Dynamic 256-color Median-Cut adaptive palette per frame (true-to-life colors)
 * - Floyd-Steinberg Error Diffusion Dithering (eliminates cartoon banding/posterization)
 * - Compliant GIF89a Logical Screen Descriptor & single Netscape 2.0 Loop extension
 * - High-speed LZW compression
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
    private var currentPalette: ByteArray? = null
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
                // 3. Netscape 2.0 Loop Extension (written ONCE at start)
                if (repeat >= 0) {
                    writeNetscapeExt()
                }
                isFirstFrame = false
            }

            // Adaptive palette generation + Floyd-Steinberg Dithering
            quantizeWithDithering(im)

            // 4. Graphic Control Extension
            writeGraphicCtrlExt()
            // 5. Image Descriptor
            writeImageDesc()
            // 6. Local Color Table (256 adaptive colors)
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
        out?.write(0x70) // No global table, 8-bit resolution
        out?.write(0)    // Background index
        out?.write(0)    // Aspect ratio
    }

    private fun writeGraphicCtrlExt() {
        out?.write(0x21) // Extension introducer
        out?.write(0xf9) // GCE label
        out?.write(4)    // Block size
        out?.write(0x04) // Disposal method 1 (do not dispose, keep graphics intact)
        writeShort(delay / 10) // Delay in 100ths of second
        out?.write(0)    // Transparent color index
        out?.write(0)    // Block terminator
    }

    private fun writeImageDesc() {
        out?.write(0x2c) // Image separator
        writeShort(0)
        writeShort(0)
        writeShort(width)
        writeShort(height)
        out?.write(0x87) // Local Color Table flag + 256 colors
    }

    private fun writePalette() {
        currentPalette?.let { out?.write(it) }
    }

    private fun writeNetscapeExt() {
        out?.write(0x21)
        out?.write(0xff)
        out?.write(11)
        writeString("NETSCAPE2.0")
        out?.write(3)
        out?.write(1)
        writeShort(repeat)
        out?.write(0)
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

    /**
     * Extracts an adaptive 256-color palette via Median-Cut,
     * then maps pixels using Floyd-Steinberg Error Diffusion Dithering.
     */
    private fun quantizeWithDithering(image: Bitmap) {
        val w = image.width
        val h = image.height
        val total = w * h
        val rgb = IntArray(total)
        image.getPixels(rgb, 0, w, 0, 0, w, h)

        // 1. Build 256-color adaptive palette using Median-Cut
        val paletteColors = MedianCutQuantizer.quantize(rgb, 256)
        val paletteBytes = ByteArray(256 * 3)
        val palR = IntArray(256)
        val palG = IntArray(256)
        val palB = IntArray(256)

        var pIdx = 0
        for (i in 0 until 256) {
            val c = paletteColors[i]
            val r = (c shr 16) and 0xff
            val g = (c shr 8) and 0xff
            val b = c and 0xff
            palR[i] = r
            palG[i] = g
            palB[i] = b
            paletteBytes[pIdx++] = r.toByte()
            paletteBytes[pIdx++] = g.toByte()
            paletteBytes[pIdx++] = b.toByte()
        }
        currentPalette = paletteBytes

        // 2. Floyd-Steinberg Error Diffusion Dithering
        // Split image into working R, G, B channels with error accumulation
        val rChan = IntArray(total)
        val gChan = IntArray(total)
        val bChan = IntArray(total)
        for (i in 0 until total) {
            val c = rgb[i]
            rChan[i] = (c shr 16) and 0xff
            gChan[i] = (c shr 8) and 0xff
            bChan[i] = c and 0xff
        }

        val outIdx = ByteArray(total)

        for (y in 0 until h) {
            val rowOffset = y * w
            for (x in 0 until w) {
                val idx = rowOffset + x
                val curR = rChan[idx].coerceIn(0, 255)
                val curG = gChan[idx].coerceIn(0, 255)
                val curB = bChan[idx].coerceIn(0, 255)

                // Find closest color in adaptive palette
                var bestDist = Int.MAX_VALUE
                var bestColorIdx = 0
                for (p in 0 until 256) {
                    val dr = curR - palR[p]
                    val dg = curG - palG[p]
                    val db = curB - palB[p]
                    val dist = dr * dr + dg * dg + db * db
                    if (dist < bestDist) {
                        bestDist = dist
                        bestColorIdx = p
                        if (dist == 0) break
                    }
                }

                outIdx[idx] = bestColorIdx.toByte()

                // Compute quantization error
                val errR = curR - palR[bestColorIdx]
                val errG = curG - palG[bestColorIdx]
                val errB = curB - palB[bestColorIdx]

                // Diffuse error:
                // (x + 1, y)     += 7/16
                // (x - 1, y + 1) += 3/16
                // (x,     y + 1) += 5/16
                // (x + 1, y + 1) += 1/16
                if (x + 1 < w) {
                    val target = idx + 1
                    rChan[target] += (errR * 7) shr 4
                    gChan[target] += (errG * 7) shr 4
                    bChan[target] += (errB * 7) shr 4
                }
                if (y + 1 < h) {
                    val nextRowOffset = (y + 1) * w
                    if (x > 0) {
                        val target = nextRowOffset + x - 1
                        rChan[target] += (errR * 3) shr 4
                        gChan[target] += (errG * 3) shr 4
                        bChan[target] += (errB * 3) shr 4
                    }
                    val targetCenter = nextRowOffset + x
                    rChan[targetCenter] += (errR * 5) shr 4
                    gChan[targetCenter] += (errG * 5) shr 4
                    bChan[targetCenter] += (errB * 5) shr 4
                    if (x + 1 < w) {
                        val targetRight = nextRowOffset + x + 1
                        rChan[targetRight] += (errR * 1) shr 4
                        gChan[targetRight] += (errG * 1) shr 4
                        bChan[targetRight] += (errB * 1) shr 4
                    }
                }
            }
        }

        indexedPixels = outIdx
    }
}

/**
 * Fast Median-Cut Color Palette Generator
 */
private object MedianCutQuantizer {

    fun quantize(pixels: IntArray, maxColors: Int): IntArray {
        // Sample pixels for fast execution (< 25,000 samples)
        val step = max(1, pixels.size / 25000)
        val sampleCount = (pixels.size + step - 1) / step
        val sampled = IntArray(sampleCount)
        var sIdx = 0
        var i = 0
        while (i < pixels.size && sIdx < sampleCount) {
            sampled[sIdx++] = pixels[i]
            i += step
        }

        val boxes = PriorityQueue<Box>(maxColors) { b1, b2 -> b2.volume.compareTo(b1.volume) }
        boxes.add(Box(sampled, 0, sIdx))

        while (boxes.size < maxColors) {
            val box = boxes.poll() ?: break
            if (box.canSplit()) {
                val (b1, b2) = box.split()
                boxes.add(b1)
                boxes.add(b2)
            } else {
                boxes.add(box)
                break
            }
        }

        val result = IntArray(maxColors)
        var idx = 0
        for (b in boxes) {
            result[idx++] = b.averageColor()
            if (idx >= maxColors) break
        }
        while (idx < maxColors) {
            result[idx] = result[idx - 1]
            idx++
        }
        return result
    }

    private class Box(val colors: IntArray, val start: Int, val end: Int) {
        var minR = 255; var maxR = 0
        var minG = 255; var maxG = 0
        var minB = 255; var maxB = 0

        init {
            for (i in start until end) {
                val c = colors[i]
                val r = (c shr 16) and 0xff
                val g = (c shr 8) and 0xff
                val b = c and 0xff
                if (r < minR) minR = r
                if (r > maxR) maxR = r
                if (g < minG) minG = g
                if (g > maxG) maxG = g
                if (b < minB) minB = b
                if (b > maxB) maxB = b
            }
        }

        val volume: Int get() = (maxR - minR + 1) * (maxG - minG + 1) * (maxB - minB + 1)

        fun canSplit(): Boolean = end - start > 1 && volume > 1

        fun split(): Pair<Box, Box> {
            val rDiff = maxR - minR
            val gDiff = maxG - minG
            val bDiff = maxB - minB

            // Sort by the widest color channel
            if (rDiff >= gDiff && rDiff >= bDiff) {
                quickSelect(colors, start, end - 1, (start + end) / 2) { (it shr 16) and 0xff }
            } else if (gDiff >= bDiff) {
                quickSelect(colors, start, end - 1, (start + end) / 2) { (it shr 8) and 0xff }
            } else {
                quickSelect(colors, start, end - 1, (start + end) / 2) { it and 0xff }
            }

            val mid = (start + end) / 2
            return Pair(Box(colors, start, mid), Box(colors, mid, end))
        }

        fun averageColor(): Int {
            var rSum = 0L; var gSum = 0L; var bSum = 0L
            val count = end - start
            if (count <= 0) return 0
            for (i in start until end) {
                val c = colors[i]
                rSum += (c shr 16) and 0xff
                gSum += (c shr 8) and 0xff
                bSum += c and 0xff
            }
            val r = (rSum / count).toInt().coerceIn(0, 255)
            val g = (gSum / count).toInt().coerceIn(0, 255)
            val b = (bSum / count).toInt().coerceIn(0, 255)
            return (r shl 16) or (g shl 8) or b
        }

        private fun quickSelect(arr: IntArray, left: Int, right: Int, k: Int, key: (Int) -> Int) {
            var l = left
            var r = right
            while (l < r) {
                val pivotIndex = partition(arr, l, r, key)
                if (pivotIndex == k) {
                    return
                } else if (pivotIndex < k) {
                    l = pivotIndex + 1
                } else {
                    r = pivotIndex - 1
                }
            }
        }

        private fun partition(arr: IntArray, left: Int, right: Int, key: (Int) -> Int): Int {
            val pivotValue = key(arr[right])
            var storeIndex = left
            for (i in left until right) {
                if (key(arr[i]) < pivotValue) {
                    val tmp = arr[storeIndex]
                    arr[storeIndex] = arr[i]
                    arr[i] = tmp
                    storeIndex++
                }
            }
            val tmp = arr[storeIndex]
            arr[storeIndex] = arr[right]
            arr[right] = tmp
            return storeIndex
        }
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
