package com.shafayatb.snapendance.attendance.office

/**
 * The office position the user saved with Set Office Location.
 *
 * [accuracyMeters] is the accuracy of the fix it was saved from. [savedAtEpochMillis] is wall time,
 * because it is shown to the user as a date and time.
 */
data class SavedOffice(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float,
    val savedAtEpochMillis: Long,
)
