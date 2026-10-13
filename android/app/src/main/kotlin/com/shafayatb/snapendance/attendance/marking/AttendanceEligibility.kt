package com.shafayatb.snapendance.attendance.marking

import com.shafayatb.snapendance.attendance.location.DistanceCalculator
import com.shafayatb.snapendance.attendance.location.FixVerdict
import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.location.LocationFixPolicy
import com.shafayatb.snapendance.attendance.office.SavedOffice

/** Whether attendance can be marked now, and what the distance ring shows. */
sealed interface Eligibility {
    data object NoOffice : Eligibility

    /** Precise permission is missing or the location setting is off. */
    data object LocationBlocked : Eligibility

    data object WaitingForFix : Eligibility

    /** [verdict] is why the fix is not usable: `Stale` or `TooInaccurate`. */
    data class WeakFix(val distanceMeters: Double, val verdict: FixVerdict) : Eligibility

    data class OutOfRange(val distanceMeters: Double) : Eligibility

    data class InRange(val distanceMeters: Double) : Eligibility
}

/**
 * The attendance rule (approved 2026-10-12): an office is saved, precise permission is held,
 * location is on, the fix passes [LocationFixPolicy], and the unrounded distance is at most
 * [MAX_DISTANCE_METERS]. Strict: no hysteresis band, so 50.0 m is in range and 50.01 m is not.
 * Pure apart from [distance], so it is tested on the JVM.
 */
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
            // Still measured, so the ring can show an approximate ("~") distance.
            else -> Eligibility.WeakFix(distanceMeters, verdict)
        }
    }

    companion object {
        const val MAX_DISTANCE_METERS = 50.0
    }
}
