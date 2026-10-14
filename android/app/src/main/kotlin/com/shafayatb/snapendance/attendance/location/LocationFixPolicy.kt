package com.shafayatb.snapendance.attendance.location

sealed interface FixVerdict {
    data object Accepted : FixVerdict

    data class Stale(val ageMillis: Long) : FixVerdict

    data class TooInaccurate(val accuracyMeters: Float?) : FixVerdict
}

object LocationFixPolicy {
    const val MAX_ACCURACY_METERS = 25f
    const val MAX_AGE_MILLIS = 30_000L

    fun evaluate(fix: LocationFix, nowElapsedRealtimeMillis: Long): FixVerdict {
        val ageMillis = nowElapsedRealtimeMillis - fix.elapsedRealtimeMillis
        if (ageMillis > MAX_AGE_MILLIS) return FixVerdict.Stale(ageMillis)

        val accuracy = fix.accuracyMeters
        if (accuracy == null || accuracy > MAX_ACCURACY_METERS) {
            return FixVerdict.TooInaccurate(accuracy)
        }
        return FixVerdict.Accepted
    }
}
