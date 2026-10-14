package com.shafayatb.snapendance.attendance.marking

import com.shafayatb.snapendance.attendance.location.DistanceCalculator
import kotlin.math.abs

object FlatDistanceCalculator : DistanceCalculator {
    override fun distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
    ): Double = abs(toLatitude - fromLatitude)
}
