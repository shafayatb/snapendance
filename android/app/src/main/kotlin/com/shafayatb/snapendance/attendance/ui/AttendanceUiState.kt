package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.office.SavedOffice

/** Everything the attendance screen shows. */
data class AttendanceUiState(
    /** The saved office, or null when none is saved (or it could not be read). */
    val office: SavedOffice? = null,
    /**
     * False until the store's first read finishes. Before that a null [office] means "not known
     * yet", so Set Office Location is disabled.
     */
    val isOfficeLoaded: Boolean = false,
    /** Non-null while Set Office Location is waiting for a usable fix. */
    val fixAttempt: FixAttempt? = null,
    /** Set Office Location was tapped with an office already saved; the user must confirm. */
    val isReplaceConfirmationVisible: Boolean = false,
    /** Why location cannot be used right now (design A6-A8); Set Office Location is disabled. */
    val blocker: LocationBlocker? = null,
    /** What the distance ring shows (A1-A4, A9). */
    val distance: DistanceStatus = DistanceStatus.NoOffice,
    /** The last attendance record, or null when none is saved (or it could not be read). */
    val lastAttendance: AttendanceRecord? = null,
    /** False until the record's first read finishes; marking waits for it. */
    val isAttendanceLoaded: Boolean = false,
    /** [lastAttendance] is from today (device time zone); one mark per day (plan D6). */
    val isMarkedToday: Boolean = false,
    /** Mark Attendance was tapped and is waiting for a fresh fix to re-check the distance. */
    val isCheckingAttendance: Boolean = false,
) {
    /** Mark Attendance is enabled: in range on a usable fix, and not marked today. */
    val canMarkAttendance: Boolean
        get() = distance is DistanceStatus.InRange && blocker == null && fixAttempt == null &&
            isAttendanceLoaded && !isMarkedToday && !isCheckingAttendance
}

/** The live distance to the saved office. Distances are unrounded meters. */
sealed interface DistanceStatus {
    data object NoOffice : DistanceStatus

    /** Waiting for the first fix, or a Set Office Location attempt is running. */
    data object Locating : DistanceStatus

    /** Location updates could not start (for example, no Play services). */
    data object Unavailable : DistanceStatus

    /**
     * The latest fix is too old or too inaccurate to check attendance (A9). [accuracyMeters] is
     * null when the fix reported none.
     */
    data class Weak(
        val distanceMeters: Double,
        val accuracyMeters: Float?,
        val isStale: Boolean,
    ) : DistanceStatus

    data class OutOfRange(val distanceMeters: Double) : DistanceStatus

    data class InRange(val distanceMeters: Double) : DistanceStatus
}

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

    /** A6 or A7's recovery button, while the system still shows the permission dialog. */
    data object AllowLocationClick : AttendanceAction

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

    /** The screen reached `ON_STOP`; location is foreground-only, so updates and attempts stop. */
    data object ScreenStopped : AttendanceAction

    data object MarkAttendanceClick : AttendanceAction
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

    /** The fresh fix taken after the tap was [distanceMeters] away, beyond 50 m. */
    data class MarkOutOfRange(val distanceMeters: Double) : AttendanceEvent

    /** No usable fix arrived to confirm the distance. */
    data object MarkNoFix : AttendanceEvent

    data object MarkSaveFailed : AttendanceEvent
    data object AttendanceLoadFailed : AttendanceEvent
}
