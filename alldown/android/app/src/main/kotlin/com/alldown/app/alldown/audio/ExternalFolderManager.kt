package com.alldown.app.alldown.audio

import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import java.io.File

object ExternalFolderManager {

    private val AUDIO_EXTENSIONS = setOf("mp3", "m4a", "flac", "wav", "ogg", "aac", "opus")

    fun releaseUriPermission(context: Context, treeUri: Uri) {
        try {
            context.contentResolver.releasePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: Exception) {
            try {
                context.contentResolver.releasePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {}
        }
    }

    fun deleteFile(context: Context, docUri: Uri): Boolean {
        return try {
            DocumentsContract.deleteDocument(context.contentResolver, docUri)
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun renameFile(context: Context, docUri: Uri, newDisplayName: String): String? {
        return try {
            val resultUri = DocumentsContract.renameDocument(context.contentResolver, docUri, newDisplayName)
            resultUri?.toString() ?: docUri.toString()
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun scanAudioFiles(context: Context, treeUri: Uri): List<Map<String, Any>> = scanFolder(context, treeUri)

    fun getFolderDisplayName(context: Context, treeUri: Uri): String {
        return try {
            val docId = DocumentsContract.getTreeDocumentId(treeUri)
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
            context.contentResolver.query(
                docUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    if (idx >= 0) {
                        val name = cursor.getString(idx)
                        if (!name.isNullOrBlank()) return name
                    }
                }
            }
            docId.substringAfterLast(':').substringAfterLast('/').ifEmpty { "Glazbena mapa" }
        } catch (_: Exception) {
            "Glazbena mapa"
        }
    }

    fun scanFolder(context: Context, treeUri: Uri): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        try {
            val rootDocId = DocumentsContract.getTreeDocumentId(treeUri)
            scanDirectory(context, treeUri, rootDocId, results)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return results
    }

    private fun scanDirectory(
        context: Context,
        treeUri: Uri,
        parentDocId: String,
        results: MutableList<Map<String, Any>>
    ) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE
        )

        try {
            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                val sizeIdx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)

                while (cursor.moveToNext()) {
                    val docId = if (idIdx >= 0) cursor.getString(idIdx) ?: continue else continue
                    val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "audio" else "audio"
                    val mime = if (mimeIdx >= 0) cursor.getString(mimeIdx) ?: "" else ""
                    val size = if (sizeIdx >= 0) cursor.getLong(sizeIdx) else 0L

                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        // Subdirectory -> recurse
                        scanDirectory(context, treeUri, docId, results)
                    } else if (isAudioFile(name, mime)) {
                        val fileDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                        val meta = extractMetadata(context, fileDocUri, name)
                        val ext = name.substringAfterLast('.', "mp3").uppercase()

                        results.add(
                            mapOf(
                                "id" to "ext_${fileDocUri.toString().hashCode()}",
                                "title" to meta.title,
                                "artist" to meta.artist,
                                "uri" to fileDocUri.toString(),
                                "durationMs" to meta.durationMs,
                                "sizeBytes" to size,
                                "format" to ext
                            )
                        )
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isAudioFile(name: String, mime: String): Boolean {
        val ext = name.substringAfterLast('.', "").lowercase()
        if (AUDIO_EXTENSIONS.contains(ext)) return true
        if (mime.startsWith("audio/")) return true
        return false
    }

    private data class TrackMeta(
        val title: String,
        val artist: String,
        val durationMs: Long
    )

    private fun extractMetadata(context: Context, docUri: Uri, fallbackName: String): TrackMeta {
        val cleanFallbackTitle = fallbackName.substringBeforeLast('.')
        var title = cleanFallbackTitle
        var artist = "Nepoznati izvođač"
        var durationMs = 0L

        try {
            context.contentResolver.openFileDescriptor(docUri, "r")?.use { pfd ->
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(pfd.fileDescriptor)
                    val metaTitle = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    val metaArtist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    val metaDuration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)

                    if (!metaTitle.isNullOrBlank()) {
                        title = metaTitle.trim()
                    }
                    if (!metaArtist.isNullOrBlank()) {
                        artist = metaArtist.trim()
                    }
                    if (!metaDuration.isNullOrBlank()) {
                        durationMs = metaDuration.toLongOrNull() ?: 0L
                    }
                } finally {
                    try {
                        retriever.release()
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

        return TrackMeta(title, artist, durationMs)
    }
}
