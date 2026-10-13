package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.location.LocationSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

/** A [LocationSource] whose fixes the test sends one at a time. */
class FakeLocationSource : LocationSource {
    private val updates = MutableSharedFlow<LocationFix>()

    /** When set, collecting [fixes] fails with it, as when Play services cannot start updates. */
    var failure: Exception? = null

    /** How many collections of [fixes] are running, that is, open location requests. */
    val activeRequests: Int get() = updates.subscriptionCount.value

    override fun fixes(): Flow<LocationFix> = flow {
        failure?.let { throw it }
        emitAll(updates)
    }

    override fun isLocationEnabled(): Boolean = true

    /** Delivers [fix] to every running collection. */
    suspend fun send(fix: LocationFix) = updates.emit(fix)
}
