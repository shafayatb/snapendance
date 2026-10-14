package com.shafayatb.snapendance.attendance.location

import kotlinx.coroutines.flow.Flow

interface LocationSource {
    fun fixes(): Flow<LocationFix>

    fun isLocationEnabled(): Boolean
}
