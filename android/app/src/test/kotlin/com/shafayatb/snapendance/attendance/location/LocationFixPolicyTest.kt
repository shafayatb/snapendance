package com.shafayatb.snapendance.attendance.location

import org.junit.Assert.assertEquals
import org.junit.Test

class LocationFixPolicyTest {
    private val now = 100_000L

    private fun fix(accuracyMeters: Float?, ageMillis: Long) = LocationFix(
        latitude = 23.7937,
        longitude = 90.4066,
        accuracyMeters = accuracyMeters,
        elapsedRealtimeMillis = now - ageMillis,
    )

    @Test
    fun fixAtBothLimitsIsAccepted() {
        assertEquals(FixVerdict.Accepted, LocationFixPolicy.evaluate(fix(25f, 30_000L), now))
    }

    @Test
    fun fixJustWorseThan25MetersIsTooInaccurate() {
        assertEquals(
            FixVerdict.TooInaccurate(25.1f),
            LocationFixPolicy.evaluate(fix(25.1f, 0L), now),
        )
    }

    @Test
    fun fixWithoutAccuracyIsTooInaccurate() {
        assertEquals(
            FixVerdict.TooInaccurate(null),
            LocationFixPolicy.evaluate(fix(null, 0L), now),
        )
    }

    @Test
    fun fixJustOlderThan30SecondsIsStale() {
        assertEquals(
            FixVerdict.Stale(30_001L),
            LocationFixPolicy.evaluate(fix(5f, 30_001L), now),
        )
    }

    @Test
    fun staleFixIsReportedAsStaleEvenWhenAlsoInaccurate() {
        assertEquals(
            FixVerdict.Stale(60_000L),
            LocationFixPolicy.evaluate(fix(80f, 60_000L), now),
        )
    }
}
