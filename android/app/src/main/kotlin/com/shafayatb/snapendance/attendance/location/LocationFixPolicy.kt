package com.shafayatb.snapendance.attendance.location

/** Whether a fix is good enough to save as the office or to check attendance against. */
sealed interface FixVerdict {
    data object Accepted : FixVerdict

    /** Older than [LocationFixPolicy.MAX_AGE_MILLIS]. */
    data class Stale(val ageMillis: Long) : FixVerdict

    /** Worse than [LocationFixPolicy.MAX_ACCURACY_METERS], or no accuracy reported (null). */
    data class TooInaccurate(val accuracyMeters: Float?) : FixVerdict
}

/**
 * The approved usable-fix rule (2026-10-12): at most 30 s old and accurate to 25 m or better,
 * both limits inclusive. These are project safeguards, not a guarantee of GPS accuracy.
 */
object LocationFixPolicy {
    const val MAX_ACCURACY_METERS = 25f
    const val MAX_AGE_MILLIS = 30_000L

    fun evaluate(fix: LocationFix, nowElapsedRealtimeMillis: Long): FixVerdict {
        // Age first: an old fix says nothing about the current position, however accurate.
        val ageMillis = nowElapsedRealtimeMillis - fix.elapsedRealtimeMillis
        if (ageMillis > MAX_AGE_MILLIS) return FixVerdict.Stale(ageMillis)

        val accuracy = fix.accuracyMeters
        if (accuracy == null || accuracy > MAX_ACCURACY_METERS) {
            return FixVerdict.TooInaccurate(accuracy)
        }
        return FixVerdict.Accepted
    }
}
