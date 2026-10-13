package com.shafayatb.snapendance.attendance

import android.graphics.Color
import android.os.Bundle
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.shafayatb.snapendance.attendance.location.FusedLocationSource
import com.shafayatb.snapendance.attendance.office.DataStoreOfficeStore
import com.shafayatb.snapendance.attendance.office.officeDataStore
import com.shafayatb.snapendance.attendance.ui.AttendanceRoot
import com.shafayatb.snapendance.attendance.ui.AttendanceViewModel
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme

/**
 * Native attendance screen, opened from the Flutter home in the same task. The back arrow and
 * system Back both finish it, returning to Flutter.
 */
class AttendanceActivity : ComponentActivity() {
    // No DI library (plan D11): the factory builds the real location source, store, and clocks.
    private val viewModel: AttendanceViewModel by viewModels {
        viewModelFactory {
            initializer {
                AttendanceViewModel(
                    locationSource = FusedLocationSource(applicationContext),
                    officeStore = DataStoreOfficeStore(applicationContext.officeDataStore),
                    elapsedRealtimeMillis = SystemClock::elapsedRealtime,
                    currentTimeMillis = System::currentTimeMillis,
                )
            }
        }
    }

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
                AttendanceRoot(viewModel = viewModel, onNavigateBack = ::finish)
            }
        }
    }
}
