package com.shafayatb.snapendance.attendance

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.shafayatb.snapendance.attendance.ui.AttendanceScreen
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme

/**
 * Native attendance screen, opened from the Flutter home in the same task. The back arrow and
 * system Back both finish it, returning to Flutter.
 */
class AttendanceActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // The screen is light only, so system bars always use dark icons, even in system dark
        // mode. The dark scrim is used only on API 24-25, which cannot draw dark nav-bar icons.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.BLACK),
        )
        super.onCreate(savedInstanceState)
        setContent {
            AttendanceTheme {
                AttendanceScreen(onNavigateBack = ::finish)
            }
        }
    }
}
