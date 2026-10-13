package com.shafayatb.snapendance.attendance.marking

import com.shafayatb.snapendance.attendance.location.FixVerdict
import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.office.SavedOffice
import org.junit.Assert.assertEquals
import org.junit.Test

class AttendanceEligibilityTest {
    private val now = 100_000L
    private val eligibility = AttendanceEligibility(FlatDistanceCalculator)

    private val office = SavedOffice(
        latitude = 0.0,
        longitude = 90.4066,
        accuracyMeters = 6f,
        savedAtEpochMillis = 1_791_800_000_000L,
    )

    /** A fix [distanceMeters] from [office] (see [FlatDistanceCalculator]). */
    private fun fix(distanceMeters: Double, accuracyMeters: Float? = 10f, ageMillis: Long = 0L) =
        LocationFix(
            latitude = office.latitude + distanceMeters,
            longitude = office.longitude,
            accuracyMeters = accuracyMeters,
            elapsedRealtimeMillis = now - ageMillis,
        )

    private fun evaluate(
        fix: LocationFix?,
        office: SavedOffice? = this.office,
        hasPrecisePermission: Boolean = true,
        isLocationEnabled: Boolean = true,
    ) = eligibility.evaluate(
        office = office,
        fix = fix,
        hasPrecisePermission = hasPrecisePermission,
        isLocationEnabled = isLocationEnabled,
        nowElapsedRealtimeMillis = now,
    )

    @Test
    fun usableFixWithin50MetersIsInRange() {
        assertEquals(Eligibility.InRange(49.0), evaluate(fix(49.0)))
    }

    @Test
    fun exactly50MetersIsInRange() {
        assertEquals(Eligibility.InRange(50.0), evaluate(fix(50.0)))
    }

    @Test
    fun justOver50MetersIsOutOfRange() {
        // Unrounded: 50.01 m must not round down into range.
        assertEquals(Eligibility.OutOfRange(50.01), evaluate(fix(50.01)))
    }

    @Test
    fun fiftyOneMetersIsOutOfRange() {
        assertEquals(Eligibility.OutOfRange(51.0), evaluate(fix(51.0)))
    }

    @Test
    fun noOfficeIsNeverInRange() {
        assertEquals(Eligibility.NoOffice, evaluate(fix(0.0), office = null))
    }

    @Test
    fun approximatePermissionIsNeverInRange() {
        assertEquals(Eligibility.LocationBlocked, evaluate(fix(0.0), hasPrecisePermission = false))
    }

    @Test
    fun locationServicesOffIsNeverInRange() {
        assertEquals(Eligibility.LocationBlocked, evaluate(fix(0.0), isLocationEnabled = false))
    }

    @Test
    fun noFixYetIsWaiting() {
        assertEquals(Eligibility.WaitingForFix, evaluate(fix = null))
    }

    @Test
    fun staleFixAtTheOfficeIsWeak() {
        assertEquals(
            Eligibility.WeakFix(0.0, FixVerdict.Stale(30_001L)),
            evaluate(fix(0.0, ageMillis = 30_001L)),
        )
    }

    @Test
    fun inaccurateFixAtTheOfficeIsWeak() {
        assertEquals(
            Eligibility.WeakFix(0.0, FixVerdict.TooInaccurate(25.1f)),
            evaluate(fix(0.0, accuracyMeters = 25.1f)),
        )
    }

    @Test
    fun fixWithoutAccuracyAtTheOfficeIsWeak() {
        assertEquals(
            Eligibility.WeakFix(0.0, FixVerdict.TooInaccurate(null)),
            evaluate(fix(0.0, accuracyMeters = null)),
        )
    }

    @Test
    fun fixAtBothFixLimitsAndExactly50MetersIsInRange() {
        assertEquals(
            Eligibility.InRange(50.0),
            evaluate(fix(50.0, accuracyMeters = 25f, ageMillis = 30_000L)),
        )
    }
}
