package me.zygotecode.veryminimalist

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.MediaStore
import android.provider.AlarmClock
import android.provider.Settings
import android.net.Uri
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "lock_channel"

    override fun onPause() {
        super.onPause()
        overridePendingTransition(0, 0)
    }

    override fun onResume() {
        super.onResume()
        overridePendingTransition(0, 0)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "openLock" -> {
                        val intent = Intent(this, LockActivity::class.java)
                        startActivity(intent)
                        result.success(null)
                    }

                    "openPhone" -> {
                        val intent = Intent(Intent.ACTION_DIAL)
                        startActivity(intent)
                        result.success(null)
                    }

                    "openCamera" -> {
                        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                        startActivity(intent)
                        result.success(null)
                    }

                    "openClock" -> {
                        try {
                            val intent = Intent(AlarmClock.ACTION_SHOW_ALARMS)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CLOCK_ERROR", e.message, null)
                        }
                    }

                    "openSystemSettings" -> {
                        val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    }

                    "openAppInfo" -> {
                        val packageName = call.argument<String>("package")

                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)

                        result.success(null)
                    }

                    "isDefaultLauncher" -> {
                        try {
                            val intent = Intent(Intent.ACTION_MAIN)
                            intent.addCategory(Intent.CATEGORY_HOME)

                            val resolveInfo = packageManager.resolveActivity(
                                intent,
                                PackageManager.MATCH_DEFAULT_ONLY
                            )

                            val currentLauncher = resolveInfo?.activityInfo?.packageName
                            val isDefault = currentLauncher == packageName

                            result.success(isDefault)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    "openLauncherSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_HOME_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}