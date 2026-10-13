package com.shafayatb.snapendance.attendance.location

import android.location.Location

/** Distance between two positions. An interface because JVM tests cannot run the framework's. */
fun interface DistanceCalculator {
    fun distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
    ): Double
}

/** The framework's ellipsoid (WGS84) distance, [Location.distanceBetween]. */
object AndroidDistanceCalculator : DistanceCalculator {
    override fun distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
    ): Double {
        val results = FloatArray(1)
        Location.distanceBetween(fromLatitude, fromLongitude, toLatitude, toLongitude, results)
        return results[0].toDouble()
    }
}
