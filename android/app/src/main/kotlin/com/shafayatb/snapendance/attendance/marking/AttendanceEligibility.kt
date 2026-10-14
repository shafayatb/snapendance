package com.shafayatb.snapendance.attendance.marking

import com.shafayatb.snapendance.attendance.location.DistanceCalculator
import com.shafayatb.snapendance.attendance.location.FixVerdict
import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.location.LocationFixPolicy
import com.shafayatb.snapendance.attendance.office.SavedOffice

sealed interface Eligibility {
    data object NoOffice : Eligibility

    data object LocationBlocked : Eligibility

    data object WaitingForFix : Eligibility

    data class WeakFix(val distanceMeters: Double, val verdict: FixVerdict) : Eligibility

    data class OutOfRange(val distanceMeters: Double) : Eligibility

    data class InRange(val distanceMeters: Double) : Eligibility
}

class AttendanceEligibility(private val distance: DistanceCalculator) {
    fun evaluate(
        office: SavedOffice?,
        fix: LocationFix?,
        hasPrecisePermission: Boolean,
        isLocationEnabled: Boolean,
        nowElapsedRealtimeMillis: Long,
    ): Eligibility {
        if (office == null) return Eligibility.NoOffice
        if (!hasPrecisePermission || !isLocationEnabled) return Eligibility.LocationBlocked
        if (fix == null) return Eligibility.WaitingForFix

        val distanceMeters = distance.distanceMeters(
            office.latitude,
            office.longitude,
            fix.latitude,
            fix.longitude,
        )
        return when (val verdict = LocationFixPolicy.evaluate(fix, nowElapsedRealtimeMillis)) {
            FixVerdict.Accepted -> if (distanceMeters <= MAX_DISTANCE_METERS) {
                Eligibility.InRange(distanceMeters)
            } else {
                Eligibility.OutOfRange(distanceMeters)
            }
            else -> Eligibility.WeakFix(distanceMeters, verdict)
        }
    }

    companion object {
        const val MAX_DISTANCE_METERS = 50.0
    }
}
