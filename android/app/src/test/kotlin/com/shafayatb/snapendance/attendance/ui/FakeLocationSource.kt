package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.location.LocationFix
import com.shafayatb.snapendance.attendance.location.LocationSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

class FakeLocationSource : LocationSource {
    private val updates = MutableSharedFlow<LocationFix>()

    var failure: Exception? = null

    val activeRequests: Int get() = updates.subscriptionCount.value

    override fun fixes(): Flow<LocationFix> = flow {
        failure?.let { throw it }
        emitAll(updates)
    }

    var locationEnabled = true

    override fun isLocationEnabled(): Boolean = locationEnabled

    suspend fun send(fix: LocationFix) = updates.emit(fix)
}
