package apoorva.module

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream

/// Bridges Android's document picker to native Swift. Swift calls these statics through `AnyDynamicObject`
/// (see `AndroidTextFilePicker.swift`) and polls `state()`, because Swift closures can't be passed to Kotlin.
class FilePicker {
    companion object {
        /// Set by `MainActivity`, which owns the `OpenDocument` activity-result launcher.
        @Volatile var launcher: (() -> Unit)? = null

        /// 0 = waiting for the user, 1 = a file was read, 2 = cancelled or unreadable.
        @Volatile private var resultState = 0
        @Volatile private var resultText = ""
        @Volatile private var resultName = ""

        @JvmStatic
        fun launch(): Boolean {
            val start = launcher ?: return false
            resultState = 0
            resultText = ""
            resultName = ""
            Handler(Looper.getMainLooper()).post { start() }
            return true
        }

        @JvmStatic
        fun state(): Int = resultState

        @JvmStatic
        fun text(): String = resultText

        @JvmStatic
        fun fileName(): String = resultName

        /// Largest file accepted; a CSV import this size is already far beyond a shop's item list.
        private const val MAX_BYTES = 5 * 1024 * 1024

        /// Called on the main thread by the activity-result callback, so the read happens on a worker thread.
        fun deliver(context: Context, uri: Uri?) {
            if (uri == null) {
                resultState = 2
                return
            }
            val resolver = context.applicationContext.contentResolver
            Thread {
                try {
                    val bytes = resolver.openInputStream(uri)?.use { input ->
                        val out = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (out.size() + count > MAX_BYTES) return@use null
                            out.write(buffer, 0, count)
                        }
                        out.toByteArray()
                    }
                    if (bytes == null) {
                        resultState = 2
                        return@Thread
                    }
                    var name = "import.csv"
                    resolver.query(uri, null, null, null, null)?.use { cursor ->
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0 && cursor.moveToFirst()) {
                            name = cursor.getString(index) ?: name
                        }
                    }
                    resultText = String(bytes, Charsets.UTF_8)
                    resultName = name
                    resultState = 1
                } catch (e: Exception) {
                    resultState = 2
                }
            }.start()
        }
    }
}
