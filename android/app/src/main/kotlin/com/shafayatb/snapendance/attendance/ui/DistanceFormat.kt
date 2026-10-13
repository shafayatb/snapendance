package com.shafayatb.snapendance.attendance.ui

import java.util.Locale
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * The ring's distance text (plan D7): "50m", "1.2km", or "150km". Meters are rounded up, so a
 * distance just over 50 m never reads "50m" while Mark Attendance is locked.
 */
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
