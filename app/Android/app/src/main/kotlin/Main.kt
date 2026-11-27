package apoorva.module

import skip.lib.*
import skip.model.*
import skip.foundation.*
import skip.ui.*

import android.Manifest
import android.app.Application
import android.graphics.Color as AndroidColor
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.activity.ComponentActivity
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material3.MaterialTheme
import androidx.core.app.ActivityCompat

internal val logger: SkipLogger = SkipLogger(subsystem = "apoorva.module", category = "Apoorva")

private typealias AppRootView = ApoorvaRootView
private typealias AppDelegate = ApoorvaAppDelegate

/// AndroidAppMain is the `android.app.Application` entry point, and must match `application android:name` in the AndroidMainfest.xml file.
open class AndroidAppMain: Application {
    constructor() {
    }

    override fun onCreate() {
        super.onCreate()
        logger.info("starting app")
        ProcessInfo.launch(applicationContext)
        AppDelegate.shared.onInit()
    }

    companion object {
    }
}

/// AndroidAppMain is initial `androidx.appcompat.app.AppCompatActivity`, and must match `activity android:name` in the AndroidMainfest.xml file.
open class MainActivity: AppCompatActivity {
    constructor() {
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        logger.info("starting activity")
        UIApplication.launch(this)
        enableEdgeToEdge()

        setContent {
            val saveableStateHolder = rememberSaveableStateHolder()
            saveableStateHolder.SaveableStateProvider(true) {
                PresentationRootView(ComposeContext())
                SideEffect { saveableStateHolder.removeState(true) }
            }
        }

        AppDelegate.shared.onLaunch()

        // Example of requesting permissions on startup.
        // These must match the permissions in the AndroidManifest.xml file.
        //let permissions = listOf(
        //    Manifest.permission.ACCESS_COARSE_LOCATION,
        //    Manifest.permission.ACCESS_FINE_LOCATION
        //    Manifest.permission.CAMERA,
        //    Manifest.permission.WRITE_EXTERNAL_STORAGE,
        //)
        //let requestTag = 1
        //ActivityCompat.requestPermissions(self, permissions.toTypedArray(), requestTag)
    }

    override fun onStart() {
        logger.info("onStart")
        super.onStart()
    }

    override fun onResume() {
        super.onResume()
        AppDelegate.shared.onResume()
    }

    override fun onPause() {
        super.onPause()
        AppDelegate.shared.onPause()
    }

    override fun onStop() {
        super.onStop()
        AppDelegate.shared.onStop()
    }

    override fun onDestroy() {
        super.onDestroy()
        AppDelegate.shared.onDestroy()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        AppDelegate.shared.onLowMemory()
    }

    override fun onRestart() {
        logger.info("onRestart")
        super.onRestart()
    }

    override fun onSaveInstanceState(outState: android.os.Bundle): Unit = super.onSaveInstanceState(outState)

    override fun onRestoreInstanceState(bundle: android.os.Bundle) {
        // Usually you restore your state in onCreate(). It is possible to restore it in onRestoreInstanceState() as well, but not very common. (onRestoreInstanceState() is called after onStart(), whereas onCreate() is called before onStart().
        logger.info("onRestoreInstanceState")
        super.onRestoreInstanceState(bundle)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: kotlin.Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        logger.info("onRequestPermissionsResult: ${requestCode}")
    }

    companion object {
    }
}

@Composable
internal fun SyncSystemBarsWithTheme() {
    val dark = MaterialTheme.colorScheme.background.luminance() < 0.5f

    val transparent = AndroidColor.TRANSPARENT
    val style = if (dark) {
        SystemBarStyle.dark(transparent)
    } else {
        SystemBarStyle.light(transparent, transparent)
    }

    val activity = LocalContext.current as? ComponentActivity
    DisposableEffect(style) {
        activity?.enableEdgeToEdge(
            statusBarStyle = style,
            navigationBarStyle = style
        )
        onDispose { }
    }
}

@Composable
internal fun PresentationRootView(context: ComposeContext) {
    val colorScheme = if (isSystemInDarkTheme()) ColorScheme.dark else ColorScheme.light
    Material3ColorScheme({ _, isDark -> apoorvaMaterialColors(isDark) }, content = {
        PresentationRoot(defaultColorScheme = colorScheme, context = context) { ctx ->
            SyncSystemBarsWithTheme()
            val contentContext = ctx.content()
            Box(modifier = ctx.modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                AppRootView().Compose(context = contentContext)
            }
        }
    })
}

/// Skip uses Material 3 dynamic (wallpaper) colours by default, which tinted lists, forms and the area behind the
/// tab bar brown and large titles pink. These fixed colours match ManiDefaultBaseTheme instead.
internal fun apoorvaMaterialColors(isDark: Boolean): androidx.compose.material3.ColorScheme {
    val rgb = { r: Int, g: Int, b: Int -> androidx.compose.ui.graphics.Color(r, g, b) }
    val primary = rgb(94, 197, 174)
    return if (isDark) {
        androidx.compose.material3.darkColorScheme(
            primary = primary, onPrimary = rgb(11, 13, 18),
            background = rgb(11, 13, 18), onBackground = rgb(229, 231, 235),
            surface = rgb(11, 13, 18), onSurface = rgb(229, 231, 235),
            surfaceVariant = rgb(21, 25, 34), onSurfaceVariant = rgb(161, 167, 179),
            surfaceContainer = rgb(21, 25, 34), surfaceContainerLow = rgb(21, 25, 34),
            surfaceContainerHigh = rgb(21, 25, 34), surfaceContainerHighest = rgb(21, 25, 34),
            outline = rgb(38, 43, 54), outlineVariant = rgb(38, 43, 54)
        )
    } else {
        androidx.compose.material3.lightColorScheme(
            primary = rgb(13, 148, 136), onPrimary = rgb(255, 255, 255),
            background = rgb(245, 246, 248), onBackground = rgb(15, 23, 42),
            surface = rgb(245, 246, 248), onSurface = rgb(15, 23, 42),
            surfaceVariant = rgb(255, 255, 255), onSurfaceVariant = rgb(71, 85, 105),
            surfaceContainer = rgb(255, 255, 255), surfaceContainerLow = rgb(255, 255, 255),
            surfaceContainerHigh = rgb(255, 255, 255), surfaceContainerHighest = rgb(255, 255, 255),
            outline = rgb(226, 232, 240), outlineVariant = rgb(226, 232, 240)
        )
    }
}
