package apoorva.module

import android.app.Activity
import android.content.Intent
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/// Own subclass so this provider's manifest entry can't clash with one merged in from a library.
class StatementFileProvider : FileProvider()

/// Draws a customer statement to a PDF and opens the Android share sheet for it. Swift calls `share` through
/// `AnyDynamicObject` (see `AndroidStatementPDF.swift`) with a plain-text payload, one line per row:
/// `style<TAB>left<TAB>right`, where style is h (shop name), s (subtitle), m (muted), r (row), b (bold row) or d (divider).
class StatementPdf {
    companion object {
        /// Set by `MainActivity` so the share sheet can be started.
        @Volatile var activity: Activity? = null

        private const val PAGE_WIDTH = 595
        private const val PAGE_HEIGHT = 842
        private const val MARGIN = 40f
        private const val BOTTOM = PAGE_HEIGHT - 50f

        @JvmStatic
        fun share(payload: String, fileName: String): Boolean =
            present(fileName, "application/pdf", "Share statement") { write(payload, it) }

        /// Shares a plain-text file (customer CSV/vCard export) through the same provider.
        @JvmStatic
        fun shareText(content: String, fileName: String, mimeType: String): Boolean =
            present(fileName, mimeType, "Share file") { it.writeText(content, Charsets.UTF_8) }

        private fun present(fileName: String, mimeType: String, chooserTitle: String, fill: (File) -> Unit): Boolean {
            val host = activity ?: return false
            return try {
                // A fresh folder per share, so a later export with the same name can't overwrite one still being read.
                val folder = File(host.cacheDir, "statements/" + UUID.randomUUID()).apply { mkdirs() }
                val file = File(folder, fileName.replace(Regex("[^A-Za-z0-9._-]"), "_"))
                fill(file)
                val uri = FileProvider.getUriForFile(host, host.packageName + ".statements", file)
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                host.runOnUiThread { host.startActivity(Intent.createChooser(send, chooserTitle)) }
                true
            } catch (e: Exception) {
                false
            }
        }

        private fun write(payload: String, file: File) {
            val document = PdfDocument()
            val regular = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; color = 0xFF000000.toInt() }
            val bold = Paint(regular).apply { typeface = Typeface.DEFAULT_BOLD }
            val title = Paint(bold).apply { textSize = 18f }
            val subtitle = Paint(regular).apply { textSize = 13f }
            val muted = Paint(regular).apply { color = 0xFF666666.toInt() }
            val rule = Paint().apply { color = 0xFFBBBBBB.toInt(); strokeWidth = 1f }

            var pageNumber = 1
            var page = document.startPage(PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create())
            var y = MARGIN + 18f

            for (line in payload.split("\n")) {
                val parts = line.split("\t")
                val style = parts.getOrElse(0) { "" }
                val left = parts.getOrElse(1) { "" }
                val right = parts.getOrElse(2) { "" }
                val paint = when (style) {
                    "h" -> title
                    "s" -> subtitle
                    "m" -> muted
                    "b" -> bold
                    else -> regular
                }
                val step = if (style == "h") 26f else if (style == "d") 12f else 18f
                if (y + step > BOTTOM) {
                    document.finishPage(page)
                    pageNumber += 1
                    page = document.startPage(PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create())
                    y = MARGIN + 18f
                }
                val canvas = page.canvas
                if (style == "d") {
                    canvas.drawLine(MARGIN, y - 8f, PAGE_WIDTH - MARGIN, y - 8f, rule)
                } else {
                    var text = left
                    val room = PAGE_WIDTH - 2 * MARGIN - (if (right.isEmpty()) 0f else 130f)
                    while (text.length > 1 && paint.measureText(text) > room) text = text.dropLast(1)
                    canvas.drawText(text, MARGIN, y, paint)
                    if (right.isNotEmpty()) {
                        paint.textAlign = Paint.Align.RIGHT
                        canvas.drawText(right, PAGE_WIDTH - MARGIN, y, paint)
                        paint.textAlign = Paint.Align.LEFT
                    }
                }
                y += step
            }
            document.finishPage(page)
            FileOutputStream(file).use { document.writeTo(it) }
            document.close()
        }
    }
}
