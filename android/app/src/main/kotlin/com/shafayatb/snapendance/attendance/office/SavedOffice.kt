package com.shafayatb.snapendance.attendance.office

data class SavedOffice(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float,
    val savedAtEpochMillis: Long,
)
