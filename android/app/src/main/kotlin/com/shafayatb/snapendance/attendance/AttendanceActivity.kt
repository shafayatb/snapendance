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
import java.util.TimeZone
import com.shafayatb.snapendance.attendance.location.AndroidDistanceCalculator
import com.shafayatb.snapendance.attendance.location.FusedLocationSource
import com.shafayatb.snapendance.attendance.marking.AttendanceEligibility
import com.shafayatb.snapendance.attendance.marking.DataStoreAttendanceStore
import com.shafayatb.snapendance.attendance.marking.attendanceDataStore
import com.shafayatb.snapendance.attendance.office.DataStoreOfficeStore
import com.shafayatb.snapendance.attendance.office.officeDataStore
import com.shafayatb.snapendance.attendance.ui.AttendanceRoot
import com.shafayatb.snapendance.attendance.ui.AttendanceViewModel
import com.shafayatb.snapendance.attendance.ui.theme.AttendanceTheme

class AttendanceActivity : ComponentActivity() {
    private val viewModel: AttendanceViewModel by viewModels {
        viewModelFactory {
            initializer {
                AttendanceViewModel(
                    locationSource = FusedLocationSource(applicationContext),
                    officeStore = DataStoreOfficeStore(applicationContext.officeDataStore),
                    attendanceStore = DataStoreAttendanceStore(applicationContext.attendanceDataStore),
                    eligibility = AttendanceEligibility(AndroidDistanceCalculator),
                    elapsedRealtimeMillis = SystemClock::elapsedRealtime,
                    currentTimeMillis = System::currentTimeMillis,
                    timeZone = TimeZone.getDefault(),
                )
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
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
