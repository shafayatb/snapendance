package com.shafayatb.snapendance.attendance.ui

import com.shafayatb.snapendance.attendance.marking.AttendanceRecord
import com.shafayatb.snapendance.attendance.marking.AttendanceStore
import java.io.IOException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

/** An in-memory [AttendanceStore] that can fail on read or save like the DataStore file. */
class FakeAttendanceStore(initial: AttendanceRecord? = null) : AttendanceStore {
    private val stored = MutableStateFlow(initial)

    /** What is currently saved. */
    val savedRecord: AttendanceRecord? get() = stored.value

    var readFailure: IOException? = null
    var saveFailure: IOException? = null

    override val lastRecord: Flow<AttendanceRecord?> = flow {
        readFailure?.let { throw it }
        emitAll(stored)
    }

    override suspend fun save(record: AttendanceRecord) {
        saveFailure?.let { throw it }
        stored.value = record
    }
}
