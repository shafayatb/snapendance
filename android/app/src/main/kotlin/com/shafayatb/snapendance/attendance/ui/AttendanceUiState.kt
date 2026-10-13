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
)

/** A running Set Office Location attempt. */
data class FixAttempt(
    /** Accuracy of the latest fix received, or null before the first one. */
    val latestAccuracyMeters: Float? = null,
)

sealed interface AttendanceAction {
    data object SetOfficeClick : AttendanceAction
    data object ReplaceOfficeConfirm : AttendanceAction
    data object ReplaceOfficeDismiss : AttendanceAction

    /** The screen reached `ON_STOP`; location is foreground-only, so a running attempt stops. */
    data object ScreenStopped : AttendanceAction
}

/** One-off feedback, shown as a snackbar. Nothing is saved when any of these is sent. */
sealed interface AttendanceEvent {
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
