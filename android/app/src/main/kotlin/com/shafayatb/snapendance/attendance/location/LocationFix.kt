package com.shafayatb.snapendance.attendance.location

data class LocationFix(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float?,
    val elapsedRealtimeMillis: Long,
)
