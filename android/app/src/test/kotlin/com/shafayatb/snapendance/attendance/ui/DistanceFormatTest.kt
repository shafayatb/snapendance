package com.shafayatb.snapendance.attendance.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class DistanceFormatTest {
    @Test
    fun exactly50MetersReads50() {
        assertEquals("50m", formatDistance(50.0))
    }

    @Test
    fun justOver50MetersRoundsUpSoItNeverReadsInRange() {
        // The button is locked above 50.0 m, so the ring must not show "50m".
        assertEquals("51m", formatDistance(50.01))
    }

    @Test
    fun underAMeterReadsOneMeter() {
        assertEquals("1m", formatDistance(0.4))
    }

    @Test
    fun justUnderAKilometerSwitchesToKilometers() {
        assertEquals("1.0km", formatDistance(999.2))
    }

    @Test
    fun kilometersShowOneDecimal() {
        assertEquals("12.3km", formatDistance(12_345.0))
    }

    @Test
    fun hundredsOfKilometersShowWholeKilometers() {
        assertEquals("150km", formatDistance(150_000.0))
    }
}
