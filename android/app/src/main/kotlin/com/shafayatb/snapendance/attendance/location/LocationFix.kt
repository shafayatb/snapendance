package com.shafayatb.snapendance.attendance.location

/**
 * One position report from the location provider.
 *
 * [accuracyMeters] is the provider's estimated horizontal accuracy, or null when it reports none.
 * [elapsedRealtimeMillis] is when the fix was taken on the `SystemClock.elapsedRealtime` clock,
 * which, unlike wall time, cannot jump when the user changes the device clock.
 */
data class LocationFix(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float?,
    val elapsedRealtimeMillis: Long,
)
