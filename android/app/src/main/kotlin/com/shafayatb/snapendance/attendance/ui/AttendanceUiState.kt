package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.office.SavedOffice

data class AttendanceUiState(
    val office: SavedOffice? = null,
    val isOfficeLoaded: Boolean = false,
    val fixAttempt: FixAttempt? = null,
    val isReplaceConfirmationVisible: Boolean = false,
    val blocker: LocationBlocker? = null,
    val distance: DistanceStatus = DistanceStatus.NoOffice,
    val lastAttendance: AttendanceRecord? = null,
    val isAttendanceLoaded: Boolean = false,
    val isMarkedToday: Boolean = false,
    val isCheckingAttendance: Boolean = false,
) {
    val canMarkAttendance: Boolean
        get() = distance is DistanceStatus.InRange && blocker == null && fixAttempt == null &&
            isAttendanceLoaded && !isMarkedToday && !isCheckingAttendance
}

sealed interface DistanceStatus {
    data object NoOffice : DistanceStatus

    data object Locating : DistanceStatus

    data object Unavailable : DistanceStatus

    data class Weak(
        val distanceMeters: Double,
        val accuracyMeters: Float?,
        val isStale: Boolean,
    ) : DistanceStatus

    data class OutOfRange(val distanceMeters: Double) : DistanceStatus

    data class InRange(val distanceMeters: Double) : DistanceStatus
}

sealed interface LocationBlocker {
    data class PermissionDenied(val canAskAgain: Boolean) : LocationBlocker

    data class ApproximateOnly(val canAskAgain: Boolean) : LocationBlocker

    data object LocationServicesOff : LocationBlocker
}

enum class LocationPermission { Precise, Approximate, None }

data class FixAttempt(
    val latestAccuracyMeters: Float? = null,
)

sealed interface AttendanceAction {
    data object SetOfficeClick : AttendanceAction
    data object ReplaceOfficeConfirm : AttendanceAction
    data object ReplaceOfficeDismiss : AttendanceAction

    data object AllowLocationClick : AttendanceAction

    data class ScreenResumed(val permission: LocationPermission) : AttendanceAction

    data class PermissionResult(
        val permission: LocationPermission,
        val shouldShowRationale: Boolean,
    ) : AttendanceAction

    data object ScreenStopped : AttendanceAction

    data object MarkAttendanceClick : AttendanceAction
}

sealed interface AttendanceEvent {
    data object RequestLocationPermission : AttendanceEvent

    data object NoFix : AttendanceEvent

    data class FixTooInaccurate(val bestAccuracyMeters: Float?) : AttendanceEvent

    data object FixStale : AttendanceEvent

    data object OfficeSaveFailed : AttendanceEvent
    data object OfficeLoadFailed : AttendanceEvent

    data class MarkOutOfRange(val distanceMeters: Double) : AttendanceEvent

    data object MarkNoFix : AttendanceEvent

    data object MarkSaveFailed : AttendanceEvent
    data object AttendanceLoadFailed : AttendanceEvent
}
