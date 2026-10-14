package com.shafayatb.snapendance.attendance.location

import android.location.Location

fun interface DistanceCalculator {
    fun distanceMeters(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
    ): Double
}

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
