package com.shafayatb.snapendance.attendance.marking

import com.shafayatb.snapendance.attendance.location.DistanceCalculator
import kotlin.math.abs

/**
 * A [DistanceCalculator] for tests: the distance in meters is the latitude difference, so a fix at
 * office latitude + 50.0 is exactly 50 m away. Longitude is ignored.
 */
object FlatDistanceCalculator : DistanceCalculator {
    override fun distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
    ): Double = abs(toLatitude - fromLatitude)
}
