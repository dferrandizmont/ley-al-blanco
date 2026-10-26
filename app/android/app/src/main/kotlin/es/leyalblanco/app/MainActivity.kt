package es.leyalblanco.app

import android.content.pm.ActivityInfo
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Portrait only on phones; tablets (smallest width of 600 dp or more)
        // rotate freely. Decided here, before the first frame, from the
        // smallest width in dp, so a phone never flashes in landscape.
        requestedOrientation =
            if (resources.configuration.smallestScreenWidthDp < TABLET_MIN_WIDTH_DP) {
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } else {
                ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The Android version for the support e-mail ("Android 16"). Only the
        // release number: never the phone model or any identifier.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "osVersion" -> result.success(Build.VERSION.RELEASE)
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val TABLET_MIN_WIDTH_DP = 600
        const val SYSTEM_CHANNEL = "es.leyalblanco/system"
    }
}
