package com.shafayatb.snapendance.attendance

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.shafayatb.snapendance.attendance.ui.AttendanceScreen

/** Native attendance screen, opened from the Flutter home in the same task. */
class AttendanceActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AttendanceScreen()
        }
    }
}
