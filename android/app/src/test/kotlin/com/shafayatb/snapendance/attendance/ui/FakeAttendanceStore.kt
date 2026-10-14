package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.marking.AttendanceStore
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

class FakeAttendanceStore(initial: AttendanceRecord? = null) : AttendanceStore {
    private val stored = MutableStateFlow(initial)

    val savedRecord: AttendanceRecord? get() = stored.value

    var readFailure: IOException? = null
    var saveFailure: IOException? = null

    var readGate: CompletableDeferred<Unit>? = null

    override val lastRecord: Flow<AttendanceRecord?> = flow {
        readGate?.await()
        readFailure?.let { throw it }
        emitAll(stored)
    }

    override suspend fun save(record: AttendanceRecord) {
        saveFailure?.let { throw it }
        stored.value = record
    }
}
