package com.antonpo.applytrack

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    result.success(openAppSettings())
                } else {
                    result.notImplemented()
                }
            }
    }

    // Opens the "App info" page of this app. Battery is one tap away there.
    private fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "com.antonpo.applytrack/app_settings"
    }
}
