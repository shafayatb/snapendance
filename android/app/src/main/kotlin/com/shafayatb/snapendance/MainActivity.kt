package com.shafayatb.snapendance

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import com.shafayatb.snapendance.attendance.AttendanceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAttendance" -> {
                        try {
                            startActivity(Intent(this, AttendanceActivity::class.java))
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            result.error(ATTENDANCE_UNAVAILABLE, e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasCameraFlash" ->
                        result.success(packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH))
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val NAVIGATION_CHANNEL = "com.shafayatb.snapendance/navigation"
        const val DEVICE_CHANNEL = "com.shafayatb.snapendance/device"
        const val ATTENDANCE_UNAVAILABLE = "ATTENDANCE_UNAVAILABLE"
    }
}
