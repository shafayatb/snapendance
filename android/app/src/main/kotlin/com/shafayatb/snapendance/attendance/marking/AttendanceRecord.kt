package com.shafayatb.snapendance.attendance.marking

/**
 * The last time attendance was marked. [markedAtEpochMillis] is wall time, shown to the user;
 * [distanceMeters] is the distance to the office measured when it was marked.
 */
data class AttendanceRecord(
    val markedAtEpochMillis: Long,
    val distanceMeters: Float,
)
