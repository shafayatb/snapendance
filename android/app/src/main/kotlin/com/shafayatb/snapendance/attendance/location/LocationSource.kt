package com.shafayatb.snapendance.attendance.location

import kotlinx.coroutines.flow.Flow

/** Where attendance gets the device position. An interface so the ViewModel can use a fake. */
interface LocationSource {
    /**
     * High-accuracy fixes, about one per second, for as long as the flow is collected; updates stop
     * when collection ends. Collect only while precise location permission is granted. The flow
     * fails with the provider's exception if updates cannot start (for example, no Play services).
     */
    fun fixes(): Flow<LocationFix>

    /** Whether the device's location setting is on. */
    fun isLocationEnabled(): Boolean
}
