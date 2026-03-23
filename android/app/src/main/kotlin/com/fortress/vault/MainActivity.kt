package com.fortress.vault

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// VaultX MainActivity
// MUST extend FlutterFragmentActivity (not FlutterActivity) for local_auth.
// super.configureFlutterEngine() MUST be called first before any custom channels
// so GeneratedPluginRegistrant runs and registers local_auth properly.
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // !! Call super FIRST — this runs GeneratedPluginRegistrant which
        // registers local_auth. If you add channels before super(), local_auth
        // won't have a valid FragmentActivity reference and throws no_fragment_activity.
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "fortress/window").setMethodCallHandler { call, result ->
            when (call.method) {
                "enable"  -> { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE);   result.success(null) }
                "disable" -> { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(null) }
                else      -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "vaultx/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "openBiometricSettings" -> { openBiometricSettings(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun openBiometricSettings() {
        val intents = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            intents.add(Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            intents.add(Intent(Settings.ACTION_FINGERPRINT_ENROLL).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
        intents.add(Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
        intents.add(Intent(Settings.ACTION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })

        for (intent in intents) {
            try { startActivity(intent); return } catch (_: Exception) {}
        }
    }
}
