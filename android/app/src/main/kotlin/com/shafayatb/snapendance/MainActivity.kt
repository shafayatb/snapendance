package com.shafayatb.snapendance

import android.content.Intent
import com.shafayatb.snapendance.attendance.AttendanceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Hosts the Flutter app and opens the native attendance screen when Flutter asks for it. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Must match the channel name and method in lib/app/native/attendance_launcher.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAttendance" -> {
                        startActivity(Intent(this, AttendanceActivity::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val NAVIGATION_CHANNEL = "com.shafayatb.snapendance/navigation"
    }
}
