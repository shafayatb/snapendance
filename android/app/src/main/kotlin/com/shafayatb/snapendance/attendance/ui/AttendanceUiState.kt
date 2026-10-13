package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.office.SavedOffice

/** Everything the attendance screen shows. */
data class AttendanceUiState(
    /** The saved office, or null when none is saved (or it could not be read). */
    val office: SavedOffice? = null,
    /** Non-null while Set Office Location is waiting for a usable fix. */
    val fixAttempt: FixAttempt? = null,
    /** Set Office Location was tapped with an office already saved; the user must confirm. */
    val isReplaceConfirmationVisible: Boolean = false,
    /** Why location cannot be used right now (design A6-A8); Set Office Location is disabled. */
    val blocker: LocationBlocker? = null,
)

/** Something the user must fix before the screen can use location. */
sealed interface LocationBlocker {
    /**
     * Location permission was denied (A6). [canAskAgain] is false once the system no longer shows
     * the dialog, so recovery goes through app settings.
     */
    data class PermissionDenied(val canAskAgain: Boolean) : LocationBlocker

    /**
     * Only approximate location is granted (A7); it is too coarse for a 50 m check. [canAskAgain]
     * is false once the system no longer offers the precise upgrade, so recovery goes through app
     * settings.
     */
    data class ApproximateOnly(val canAskAgain: Boolean) : LocationBlocker

    /** The device's location setting is off (A8). */
    data object LocationServicesOff : LocationBlocker
}

/** The location permission the app holds, as the screen reads it. */
enum class LocationPermission { Precise, Approximate, None }

/** A running Set Office Location attempt. */
data class FixAttempt(
    /** Accuracy of the latest fix received, or null before the first one. */
    val latestAccuracyMeters: Float? = null,
)

sealed interface AttendanceAction {
    data object SetOfficeClick : AttendanceAction
    data object ReplaceOfficeConfirm : AttendanceAction
    data object ReplaceOfficeDismiss : AttendanceAction

    /**
     * The screen reached `ON_RESUME` holding [permission]; services are re-checked too. Also sent
     * when A8's recovery finds location already on, since the notification shade does not pause
     * the screen.
     */
    data class ScreenResumed(val permission: LocationPermission) : AttendanceAction

    /**
     * The location permission request finished. [shouldShowRationale] is the system's
     * `shouldShowRequestPermissionRationale` afterwards: false after a denial means the system
     * will not ask again.
     */
    data class PermissionResult(
        val permission: LocationPermission,
        val shouldShowRationale: Boolean,
    ) : AttendanceAction

    /** The screen reached `ON_STOP`; location is foreground-only, so a running attempt stops. */
    data object ScreenStopped : AttendanceAction
}

/**
 * One-off events: requests the screen carries out, and feedback shown as a snackbar. Nothing is
 * saved when any of these is sent.
 */
sealed interface AttendanceEvent {
    /** Ask for precise location (fine and coarse together). */
    data object RequestLocationPermission : AttendanceEvent

    /** No fix arrived within the attempt's time limit, or the provider could not start. */
    data object NoFix : AttendanceEvent

    /**
     * Current fixes arrived, but none was accurate enough. [bestAccuracyMeters] is the best one,
     * or null if none reported an accuracy.
     */
    data class FixTooInaccurate(val bestAccuracyMeters: Float?) : AttendanceEvent

    /** Only old (cached) fixes arrived. */
    data object FixStale : AttendanceEvent

    data object OfficeSaveFailed : AttendanceEvent
    data object OfficeLoadFailed : AttendanceEvent
}
