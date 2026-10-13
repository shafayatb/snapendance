package com.shafayatb.snapendance

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import com.shafayatb.snapendance.attendance.AttendanceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app, opens the native attendance screen when Flutter asks for it, and answers
 * device questions the camera plugin cannot.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Must match the channel name and method in lib/app/native/attendance_launcher.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAttendance" -> {
                        // Only the expected launch failure is caught. The engine still turns any
                        // other exception into an error reply, and logs its stack trace.
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
        // Must match the channel name and method in lib/features/camera/data/plugin_camera_service.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The camera plugin stores any flash mode, with or without a flash unit.
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
