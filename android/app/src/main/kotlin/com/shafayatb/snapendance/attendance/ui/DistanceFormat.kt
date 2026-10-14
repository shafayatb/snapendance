package com.shafayatb.snapendance.attendance.ui

import java.util.Locale
import kotlin.math.ceil
import kotlin.math.roundToInt

fun formatDistance(distanceMeters: Double): String {
    val meters = ceil(distanceMeters).toInt()
    if (meters < 1_000) return "${meters}m"
    val tenthsOfKm = (distanceMeters / 100).roundToInt()
    return if (tenthsOfKm < 1_000) {
        String.format(Locale.ROOT, "%.1fkm", tenthsOfKm / 10.0)
    } else {
        "${(distanceMeters / 1_000).roundToInt()}km"
    }
}
