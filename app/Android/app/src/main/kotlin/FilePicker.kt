package apoorva.module

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns

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

        fun deliver(context: Context, uri: Uri?) {
            if (uri == null) {
                resultState = 2
                return
            }
            try {
                val text = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                if (text == null) {
                    resultState = 2
                    return
                }
                var name = "import.csv"
                context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0 && cursor.moveToFirst()) {
                        name = cursor.getString(index) ?: name
                    }
                }
                resultText = text
                resultName = name
                resultState = 1
            } catch (e: Exception) {
                resultState = 2
            }
        }
    }
}
